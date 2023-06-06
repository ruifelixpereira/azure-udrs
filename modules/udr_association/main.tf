#
# Required provider
#

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
    }
  }
}

#
# UDR resources
#

# UDR to associate with subnets
data "azurerm_route_table" "myudr" {
  name                = var.udr_name
  resource_group_name = var.udr_resource_group_name
}

# Associate UDR to subnets
resource "azurerm_subnet_route_table_association" "example" {
  for_each = var.subnets

  subnet_id      = each.value
  route_table_id = data.azurerm_route_table.myudr.id
}
