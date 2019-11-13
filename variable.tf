variable "prefix" {
  default = "ari"
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
  default = "japaneast"
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

variable "access_source_address" {
  default = "*"
}

variable "dsvm_version" {
  default = "19.08.23"
}
