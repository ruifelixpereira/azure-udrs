#
# UDR resources
#


# List of VNETS to consider
locals {
  # can validate with: jq . final_vnets.json
  vnets = jsondecode(file("${path.module}/${var.list_vnets_json_file}"))

  rules = {
    for vn in local.vnets : vn.vnet => vn.rules
  }
}


# Resource group where we are going to create the new UDR

data "azurerm_resource_group" "udr_resource_group" {
    name = var.udr_resource_group
}


# New UDR
resource "azurerm_route_table" "new-udr" {
    for_each = local.rules
    #count                         = var.just_associate ? 0 : 1

    name                          = "udr-${each.key}"
    location                      = data.azurerm_resource_group.udr_resource_group.location
    resource_group_name           = var.udr_resource_group
    disable_bgp_route_propagation = false

    dynamic "route" {
        for_each = each.value
        content {
            name                   = "route-${route.key}"
            address_prefix         = route.value
            next_hop_type          = "VirtualAppliance"
            next_hop_in_ip_address = var.firewall_ip
        }
    }

    tags = var.tags
}

