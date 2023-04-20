#
# UDR resources
#

# List of subnets to associate the UDRs
locals {
  subnets = jsondecode(file("${path.module}/${var.list_subnets_json_file}"))

  rules = {
    for vn in local.subnets : vn.vnet => vn.subnets
  }
}


# Resource group where we are going to create the new UDR
data "azurerm_resource_group" "udr_resource_group" {
    name = var.udr_resource_group
}


resource "azurerm_route_table" "example" {
  name                = "example-routetable"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet_route_table_association" "example" {
  subnet_id      = azurerm_subnet.example.id
  route_table_id = azurerm_route_table.example.id
}
