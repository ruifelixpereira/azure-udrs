#
# Providers Configuration
#

terraform {
  required_version = "~> 1.3.2"
  required_providers {
    azurerm = "~> 2.91.0"
  }
}

# Configure the Azure Provider with an alias
provider "azurerm" {
  alias = "prod"

  subscription_id            = var.subscription_id
  tenant_id                  = var.tenant_id
  client_id                  = var.client_id
  client_secret              = var.client_secret
  skip_provider_registration = true

  features {}
}
