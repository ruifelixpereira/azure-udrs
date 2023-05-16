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

# New UDR
resource "azurerm_route_table" "new-udr" {
    #for_each = var.vnets
    for_each = {
        for k, v in var.vnets : k => v
        if contains(var.subscription_alias, v.alias)
    }

    name                          = "udr-${each.key}"
    location                      = each.value.location
    resource_group_name           = each.value.rg
    disable_bgp_route_propagation = false

    dynamic "route" {
        for_each = each.value.rules
        content {
            name                   = "route-${route.key}"
            address_prefix         = route.value
            next_hop_type          = "VirtualAppliance"
            next_hop_in_ip_address = var.firewall_ip
        }
    }

    tags = var.tags
}

