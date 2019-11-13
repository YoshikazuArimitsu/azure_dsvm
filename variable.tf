variable "prefix" {
  default = "dsvm"
}
variable "azure_subscription_id" {
}
variable "azure_client_id" {
}

variable "azure_client_secret" {
}

variable "azure_tenant_id" {
}

variable "location" {
  default = "eastus"
}

variable "vm_size" {
  default = "Standard_DS1_v2"
}

variable "pubkey_path" {
  default = "~/.ssh/id_rsa.pub"
}

variable "privkey_path" {
  default = "~/.ssh/id_rsa"
}
