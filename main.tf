data "azurerm_resource_group" "network_group" {
  name = var.resource_group_name
}

data "azurerm_subscription" "current" {}

