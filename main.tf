# Configure the Microsoft Azure Provider
provider "azurerm" {
  subscription_id = "${var.azure_subscription_id}"
  client_id       = "${var.azure_client_id}"
  client_secret   = "${var.azure_client_secret}"
  tenant_id       = "${var.azure_tenant_id}"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "dsvm_group" {
  name     = "${var.prefix}-rg"
  location = "${var.location}"
}

# Create virtual network
resource "azurerm_virtual_network" "dsvm_network" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.dsvm_group.name}"

}

# Create subnet
resource "azurerm_subnet" "dsvm_subnet" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = "${azurerm_resource_group.dsvm_group.name}"
  virtual_network_name = "${azurerm_virtual_network.dsvm_network.name}"
  address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "dsvm_publicip" {
  name                = "${var.prefix}-publicip"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.dsvm_group.name}"
  allocation_method   = "Dynamic"
  domain_name_label   = "${var.prefix}-dsvm"

}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "dsvm_nsg" {
  name                = "${var.prefix}-nsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.dsvm_group.name}"

}

resource "azurerm_network_security_rule" "ssh" {
  name                        = "SSH"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "${var.access_source_address}"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.dsvm_group.name}"
  network_security_group_name = "${azurerm_network_security_group.dsvm_nsg.name}"
}

resource "azurerm_network_security_rule" "jupyterhub" {
  name                        = "JupyterHub"
  priority                    = 1002
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8443"
  source_address_prefix       = "${var.access_source_address}"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.dsvm_group.name}"
  network_security_group_name = "${azurerm_network_security_group.dsvm_nsg.name}"
}

# Create network interface
resource "azurerm_network_interface" "dsvm_nic" {
  name                      = "${var.prefix}-nic"
  location                  = "${var.location}"
  resource_group_name       = "${azurerm_resource_group.dsvm_group.name}"
  network_security_group_id = "${azurerm_network_security_group.dsvm_nsg.id}"

  ip_configuration {
    name                          = "${var.prefix}-nic-configuration"
    subnet_id                     = "${azurerm_subnet.dsvm_subnet.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.dsvm_publicip.id}"
  }

}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${azurerm_resource_group.dsvm_group.name}"
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "dsvm-storage" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = "${azurerm_resource_group.dsvm_group.name}"
  location                 = "${var.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"

}

# Create virtual machine
resource "azurerm_virtual_machine" "dsvm_vm" {
  name                  = "${var.prefix}-dsvm"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.dsvm_group.name}"
  network_interface_ids = ["${azurerm_network_interface.dsvm_nic.id}"]
  vm_size               = "${var.vm_size}"

  storage_os_disk {
    name              = "${var.prefix}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "microsoft-dsvm"
    offer     = "linux-data-science-vm-ubuntu"
    sku       = "linuxdsvmubuntu"
    version   = "${var.dsvm_version}"
  }

  os_profile {
    computer_name  = "${var.prefix}-dsvm"
    admin_username = "azureuser"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = "${file(var.pubkey_path)}"
    }
  }

  boot_diagnostics {
    enabled     = "true"
    storage_uri = "${azurerm_storage_account.dsvm-storage.primary_blob_endpoint}"
  }

}

resource "azurerm_virtual_machine_extension" "aadlinux" {
  name                       = "${var.prefix}-aadlinux"
  location                   = "${var.location}"
  resource_group_name        = "${azurerm_resource_group.dsvm_group.name}"
  virtual_machine_name       = "${azurerm_virtual_machine.dsvm_vm.name}"
  publisher                  = "Microsoft.Azure.ActiveDirectory.LinuxSSH"
  type                       = "AADLoginForLinux"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

}

resource "azuread_application" "oauthapp" {
  name                       = "${var.prefix}-jupyterhub-oauth"
  identifier_uris            = ["https://uri"]
  reply_urls                 = ["https://${azurerm_public_ip.dsvm_publicip.fqdn}:8443/hub/oauth_callback"]
  available_to_other_tenants = false
  type                       = "webapp/api"

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph API

    # Necessary permissions
    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # Sign in and read user profile
      type = "Scope"
    }
  }
}

resource "random_id" "oauthapp-secret" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${azurerm_resource_group.dsvm_group.name}"
  }

  byte_length = 8
}

resource "azuread_application_password" "oauthapp-pass" {
  application_id    = "${azuread_application.oauthapp.id}"
  value             = "${random_id.oauthapp-secret.hex}"
  end_date_relative = "8760h"
}

resource "null_resource" "provision" {
  depends_on = ["azurerm_virtual_machine.dsvm_vm",
    "azurerm_public_ip.dsvm_publicip",
  "azurerm_virtual_machine_extension.aadlinux"]

  connection {
    host        = "${azurerm_public_ip.dsvm_publicip.fqdn}"
    user        = "azureuser"
    private_key = "${file("${var.privkey_path}")}"
  }

  # 1. リソース情報をenvに保存、リモートに送る
  provisioner "local-exec" {
    command = "echo 'export VM_FQDN=${azurerm_public_ip.dsvm_publicip.fqdn}' > env"
  }

  provisioner "local-exec" {
    command = "echo 'export OAUTHAPP_APPLICATION_ID=${azuread_application.oauthapp.application_id}' >> env"
  }

  provisioner "local-exec" {
    command = "echo 'export AAD_TENANT_ID=${var.azure_tenant_id}' >> env"
  }

  provisioner "local-exec" {
    command = "echo 'export OAUTHAPP_CLIENT_SECRET=${random_id.oauthapp-secret.hex}' >> env"
  }

  provisioner "file" {
    source      = "env"
    destination = "~/.terraform_env"
  }

  # 2. セットアップスクリプトをリモートに送り、実行する
  provisioner "file" {
    source      = "setup.sh"
    destination = "/tmp/setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup.sh",
      "/tmp/setup.sh"
    ]
  }
}

output "dsvm-url" {
  value = "https://${azurerm_public_ip.dsvm_publicip.fqdn}:8443/"
}

output "dsvm-host" {
  value = "${azurerm_public_ip.dsvm_publicip.fqdn}"
}