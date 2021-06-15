variable "subscription_id" {
  default = ""
}

variable "tenant_id" {
  default = ""
}

variable "location" {
  default = ""
}

variable "project_name" {
  default = ""
}

variable "main_name" {
  default = ""
}

variable "address_space" {
  default = "10.251.0.0"
}

variable "vnets" {
  default = []
}

variable "network_size" {
  default = 16
}

variable "resource_group_name" {
  default = ""
}

variable "thelist" {
  default = []
}

variable "service_endpoints" {
  default = [
    "Microsoft.Sql",
    "Microsoft.Storage",
    "Microsoft.KeyVault",
  ]
}

variable "vnet_tags" {
  description = "Additional tags for the vnet"
  default     = {}
}

variable "tags" {
  description = "A map of tags to add to all resources"
  default = {
    environment = "Test"
    managed_by  = "Terraform"
  }
}

variable "subnets" {
  default = []
}

variable "peerings" {
  default = []
}

variable "route_tables" {
  default = []
}

variable "resource_group_tags" {
  description = "Additional tags for the vnet"
  default     = {}
}

variable "route_subnets" {
  description = "subnets in each vnet that associate with route tables"
  default = {}
}