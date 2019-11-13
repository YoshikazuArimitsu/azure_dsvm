# Configure the Microsoft Azure Provider
provider "azurerm" {
  subscription_id = "${var.azure_subscription_id}"
  client_id       = "${var.azure_client_id}"
  client_secret   = "${var.azure_client_secret}"
  tenant_id       = "${var.azure_tenant_id}"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "myterraformgroup" {
  name     = "${var.prefix}-rg"
  location = "${var.location}"

  tags = {
    environment = "Terraform Demo"
  }
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.myterraformgroup.name}"

  tags = {
    environment = "Terraform Demo"
  }
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = "${azurerm_resource_group.myterraformgroup.name}"
  virtual_network_name = "${azurerm_virtual_network.myterraformnetwork.name}"
  address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
  name                = "${var.prefix}-publicip"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.myterraformgroup.name}"
  allocation_method   = "Dynamic"

  tags = {
    environment = "Terraform Demo"
  }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
  name                = "${var.prefix}-nsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.myterraformgroup.name}"

  tags = {
    environment = "Terraform Demo"
  }
}

resource "azurerm_network_security_rule" "ssh" {
  name                        = "SSH"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.myterraformgroup.name}"
  network_security_group_name = "${azurerm_network_security_group.myterraformnsg.name}"
}

resource "azurerm_network_security_rule" "jupyterhub" {
  name                        = "JupyterHub"
  priority                    = 1002
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.myterraformgroup.name}"
  network_security_group_name = "${azurerm_network_security_group.myterraformnsg.name}"
}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
  name                      = "${var.prefix}-nic"
  location                  = "${var.location}"
  resource_group_name       = "${azurerm_resource_group.myterraformgroup.name}"
  network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

  ip_configuration {
    name                          = "${var.prefix}-nic-configuration"
    subnet_id                     = "${azurerm_subnet.myterraformsubnet.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.myterraformpublicip.id}"
  }

  tags = {
    environment = "Terraform Demo"
  }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${azurerm_resource_group.myterraformgroup.name}"
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = "${azurerm_resource_group.myterraformgroup.name}"
  location                 = "${var.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "Terraform Demo"
  }
}

# Create virtual machine
resource "azurerm_virtual_machine" "myterraformvm" {
  name                  = "${var.prefix}-dsvm"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.myterraformgroup.name}"
  network_interface_ids = ["${azurerm_network_interface.myterraformnic.id}"]
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
    version   = "19.08.23"
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
    storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
  }

  tags = {
    environment = "Terraform Demo"
  }
}

resource "azurerm_virtual_machine_extension" "aadlinux" {
  name                       = "${var.prefix}-aadlinux"
  location                   = "${var.location}"
  resource_group_name        = "${azurerm_resource_group.myterraformgroup.name}"
  virtual_machine_name       = "${azurerm_virtual_machine.myterraformvm.name}"
  publisher                  = "Microsoft.Azure.ActiveDirectory.LinuxSSH"
  type                       = "AADLoginForLinux"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  tags = {
    environment = "Terraform Demo"
  }
}

resource "azurerm_virtual_machine_extension" "provision" {
  name                 = "${var.prefix}-provision"
  location             = "${var.location}"
  resource_group_name  = "${azurerm_resource_group.myterraformgroup.name}"
  virtual_machine_name = "${azurerm_virtual_machine.myterraformvm.name}"
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "script": "${filebase64("setup.sh")}"
    }
SETTINGS

  tags = {
    environment = "Terraform Demo"
  }
}