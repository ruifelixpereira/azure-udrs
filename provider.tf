#
# Providers Configuration
#

terraform {
  required_version = "~> 1.4.4"
  required_providers {
    azurerm = "~> 2.91.0"
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {}

  subscription_id            = var.subscription_id
  client_id                  = var.client_id
  client_secret              = var.client_secret
  tenant_id                  = var.tenant_id
  skip_provider_registration = true
}