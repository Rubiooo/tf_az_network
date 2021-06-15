#--------------------------------------------------------------------
#---------- use locals to break down the variables.vnet -------------
#--------------------------------------------------------------------
locals {

  subnet_names = {
    for map in flatten([
      for vnet_name, vnet_values in var.vnets : [
        for subnet_name, subnet_values in lookup(vnet_values, "subnets", {}) :
        {
          key = join(":", [vnet_name, subnet_name]) #Keys need to be unique
          value = merge(subnet_values, {
            vnet_name     = format("%s-%s", lower(var.project_name), lower(vnet_name)) #replace this with the vnet, for example: azurerm_virtual_network.vnet.name
            subnet_name   = subnet_name
            address_space = [format("%s/%s", lookup(vnet_values, "address_space"), lookup(vnet_values, "network_size"))]
            network_size  = lookup(vnet_values, "network_size")
            address_prefixes = [cidrsubnet(
              element([format("%s/%s", lookup(vnet_values, "address_space"), lookup(vnet_values, "network_size"))], 0),
              lookup(subnet_values, "bitmask") - lookup(vnet_values, "network_size"),
              lookup(subnet_values, "netnum"),
            )]
            resource_group_name = data.azurerm_resource_group.network_group.name #ideally link this to the terraform resource, like the vnet
          })
        }
      ]
    ]) : map.key => map.value
  }

  vnet_names = keys(var.vnets)

  vnet_peerings = var.peerings

  vnet_creates = {
    for map in flatten([
      for vnet_name, vnet_values in var.vnets : {
        key = vnet_name #Keys need to be unique
        value = merge({}, {
          vnet_name     = format("%s-%s", lower(var.project_name), lower(vnet_name))
          address_space = lookup(vnet_values, "address_space")
          network_size  = lookup(vnet_values, "network_size")
        })
      }
    ]) : map.key => map.value
  }

  nsg_creates = {
    for map in flatten([
      for vnet_name, vnet_values in var.vnets : [
        for subnet_name, subnet_values in lookup(vnet_values, "subnets", {}) :
        {
          key = join(":", [vnet_name, subnet_name]) #Keys need to be unique
          value = merge({}, {
            subnet_name   = subnet_name
            network_security_group = lookup(subnet_values,"network_security_group")
            security_group_rules = lookup(subnet_values,"security_group_rules")
            resource_group_name = data.azurerm_resource_group.network_group.name #ideally link this to the terraform resource, like the vnet
          })
        }
      ]
    ]) : map.key => map.value
  }
} # ------------------------ END OF LOCALS ---------------------------


#--------------------------------------------------------------------
#-------------------- vnets creation --------------------------------
#--------------------------------------------------------------------
resource "azurerm_virtual_network" "vnets" {
  for_each = {
    for map in flatten([
      for vnet_name, vnet_values in var.vnets : {
        key = vnet_name #Keys need to be unique
        value = merge(vnet_values, {
          vnet_name     = format("%s-%s", lower(var.project_name), lower(vnet_name))
          address_space = lookup(vnet_values, "address_space")
          network_size  = lookup(vnet_values, "network_size")
        })
      }
    ]) : map.key => map.value
  }
  name                = lookup(each.value, "vnet_name")
  resource_group_name = data.azurerm_resource_group.network_group.name
  location            = data.azurerm_resource_group.network_group.location
  address_space       = [format("%s/%s", lookup(each.value, "address_space"), lookup(each.value, "network_size"))]

  tags = merge(map("Name", format("%s", var.project_name)), var.vnet_tags, var.tags)

}

#--------------------------------------------------------------------
#-------------------- subnets creation ------------------------------
#--------------------------------------------------------------------
resource "azurerm_subnet" "subnets" {
  depends_on = [azurerm_virtual_network.vnets]
  for_each = {
    for map in flatten([
      for vnet_name, vnet_values in var.vnets : [
        for subnet_name, subnet_values in lookup(vnet_values, "subnets", {}) :
        {
          key = join(":", [vnet_name, subnet_name]) #Keys need to be unique
          value = merge(subnet_values, {
            vnet_name           = format("%s-%s", lower(var.project_name), lower(vnet_name)) #replace this with the vnet, for example: azurerm_virtual_network.vnet.name
            subnet_name         = subnet_name
            address_space       = [format("%s/%s", lookup(vnet_values, "address_space"), lookup(vnet_values, "network_size"))]
            network_size        = lookup(vnet_values, "network_size")
            resource_group_name = data.azurerm_resource_group.network_group.name #ideally link this to the terraform resource, like the vnet
          })
        }
      ]
    ]) : map.key => map.value
  }


  #---------- configure bitmask/netnum in variables.vnets -------------
  address_prefixes = [cidrsubnet(
    element(lookup(each.value, "address_space"), 0),
    lookup(each.value, "bitmask") - lookup(each.value, "network_size"),
    lookup(each.value, "netnum"),
  )]
  name                 = lookup(each.value, "subnet_name")
  resource_group_name  = lookup(each.value, "resource_group_name")
  virtual_network_name = lookup(each.value, "vnet_name")
}

#--------------------------------------------------------------------
#-------------------- route tables ----------------------------------
#--------------------------------------------------------------------

resource "azurerm_route_table" "azurerm_route_table" {
  count               = length(var.route_tables)
  name                = lookup(var.route_tables[count.index], "name")
  location            = data.azurerm_resource_group.network_group.location
  resource_group_name = data.azurerm_resource_group.network_group.name

  dynamic "route" {
    for_each = lookup(var.route_tables.*.routes[count.index], "static_routes")

    content {
      name                   = route.value["name"]
      address_prefix         = route.value["address_prefix"]
      next_hop_type          = route.value["next_hop_type"]
      next_hop_in_ip_address = route.value["next_hop_in_ip_address"]
    }
  }
}

data "azurerm_subnet" "route_subnets" {
  depends_on = [azurerm_subnet.subnets]
  for_each = {
    for map in flatten([
      for vnet_name, vnet_values in var.route_subnets : [
        for subnet_name, subnet_values in lookup(vnet_values, "subnets", {}) :
        {
          key = join(":", [vnet_name, subnet_name]) #Keys need to be unique
          value = merge(subnet_values, {
            vnet_name           = format("%s-%s", lower(var.project_name), lower(vnet_name)) #replace this with the vnet, for example: azurerm_virtual_network.vnet.name
            subnet_name         = subnet_name
            routing_table_name  = lookup(subnet_values, "routing_table_name")
            resource_group_name = data.azurerm_resource_group.network_group.name #ideally link this to the terraform resource, like the vnet
          })
        }
      ]
    ]) : map.key => map.value
  }
  name                 = lookup(each.value, "subnet_name")
  virtual_network_name = lookup(each.value, "vnet_name")
  resource_group_name  = lookup(each.value, "resource_group_name")
}

data "azurerm_route_table" "associated_route_tables" {
  depends_on = [azurerm_route_table.azurerm_route_table]
  for_each = {
    for map in flatten([
      for vnet_name, vnet_values in var.route_subnets : [
        for subnet_name, subnet_values in lookup(vnet_values, "subnets", {}) :
        {
          key = join(":", [vnet_name, subnet_name]) #Keys need to be unique
          value = merge(subnet_values, {
            vnet_name           = format("%s-%s", lower(var.project_name), lower(vnet_name)) #replace this with the vnet, for example: azurerm_virtual_network.vnet.name
            subnet_name         = subnet_name
            routing_table_name  = lookup(subnet_values, "routing_table_name")
            resource_group_name = data.azurerm_resource_group.network_group.name #ideally link this to the terraform resource, like the vnet
          })
        }
      ]
    ]) : map.key => map.value
  }
  name                 = lookup(each.value, "routing_table_name")
  resource_group_name  = lookup(each.value, "resource_group_name")
}

resource "azurerm_subnet_route_table_association" "route_table_association" {
  for_each = {
    for map in flatten([
      for vnet_name, vnet_values in var.route_subnets : [
        for subnet_name, subnet_values in lookup(vnet_values, "subnets", {}) :
        {
          key = join(":", [vnet_name, subnet_name]) #Keys need to be unique
          value = merge(subnet_values, {
            vnet_name           = format("%s-%s", lower(var.project_name), lower(vnet_name)) #replace this with the vnet, for example: azurerm_virtual_network.vnet.name
            subnet_name         = subnet_name
            routing_table_name  = lookup(subnet_values, "routing_table_name")
            resource_group_name = data.azurerm_resource_group.network_group.name #ideally link this to the terraform resource, like the vnet
          })
        }
      ]
    ]) : map.key => map.value
  }

  route_table_id            = data.azurerm_route_table.associated_route_tables[each.key].id
  subnet_id                 = data.azurerm_subnet.route_subnets[each.key].id
    
}

#--------------------------------------------------------------------
#-------------------- network security groups -----------------------
#--------------------------------------------------------------------
resource "azurerm_network_security_group" "network_security_group" {
  for_each = {
    for map in flatten([
      for vnet_name, vnet_values in var.vnets : [
        for subnet_name, subnet_values in lookup(vnet_values, "subnets", {}) :
        {
          key = join(":", [vnet_name, subnet_name]) #Keys need to be unique
          value = merge({}, {
            subnet_name   = subnet_name
            network_security_group = lookup(subnet_values,"network_security_group")
            security_group_rules = lookup(subnet_values,"security_group_rules")
            resource_group_name = data.azurerm_resource_group.network_group.name #ideally link this to the terraform resource, like the vnet
          })
        }
      ]
    ]) : map.key => map.value
  }
  name                = lookup(each.value, "network_security_group")
  location            = data.azurerm_resource_group.network_group.location
  resource_group_name = data.azurerm_resource_group.network_group.name

  dynamic "security_rule" {
    for_each = lookup(each.value, "security_group_rules")

    content {
      name                       = security_rule.value["name"]
      priority                   = security_rule.value["priority"]
      direction                  = security_rule.value["direction"]
      access                     = security_rule.value["access"]
      protocol                   = security_rule.value["protocol"]
      source_port_range          = security_rule.value["source_port_range"]
      destination_port_range     = security_rule.value["destination_port_range"]
      source_address_prefix      = security_rule.value["source_address_prefix"]
      destination_address_prefix = security_rule.value["destination_address_prefix"]
      description                = ""
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_association" {
for_each = {
    for map in flatten([
      for vnet_name, vnet_values in var.vnets : [
        for subnet_name, subnet_values in lookup(vnet_values, "subnets", {}) :
        {
          key = join(":", [vnet_name, subnet_name]) #Keys need to be unique
          value = merge({}, {
            subnet_name   = subnet_name
            network_security_group = lookup(subnet_values,"network_security_group")
            security_group_rules = lookup(subnet_values,"security_group_rules")
            resource_group_name = data.azurerm_resource_group.network_group.name #ideally link this to the terraform resource, like the vnet
          })
        }
      ]
    ]) : map.key => map.value
  }
  depends_on                = [azurerm_network_security_group.network_security_group]
  subnet_id                 = azurerm_subnet.subnets[each.key].id 
  network_security_group_id = azurerm_network_security_group.network_security_group[each.key].id
}

