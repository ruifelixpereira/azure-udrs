#
# Providers Configuration
#

terraform {
  required_version = "~> 1.4.4"
  required_providers {
    azurerm = "~> 2.91.0"
  }
}

# Configure the Azure Provider with an alias

provider "azurerm" {
  alias = "sub1"
  subscription_id = "05e06692-cc6a-4772-81a3-89cd2b429bbe"
  tenant_id = var.tenant_id
  client_id = var.client_id
  client_secret = var.client_secret
  skip_provider_registration = true
  features {}
}
provider "azurerm" {
  alias = "sub2"
  subscription_id = "05e06692-cc6a-4772-81a3-89cd2b429bbe"
  tenant_id = var.tenant_id
  client_id = var.client_id
  client_secret = var.client_secret
  skip_provider_registration = true
  features {}
}
provider "azurerm" {
  alias = "sub3"
  subscription_id = "05e06692-cc6a-4772-81a3-89cd2b429bbe"
  tenant_id = var.tenant_id
  client_id = var.client_id
  client_secret = var.client_secret
  skip_provider_registration = true
  features {}
}
