module "udr_creation_module_sub1" {
  source = "./modules/udr_creation"
  providers = {
    azurerm = azurerm.sub1
  }
  vnets = var.vnets
  firewall_ip = var.firewall_ip
  subscription_alias = ["sub1"]
  tags = var.tags
}
module "udr_creation_module_sub2" {
  source = "./modules/udr_creation"
  providers = {
    azurerm = azurerm.sub2
  }
  vnets = var.vnets
  firewall_ip = var.firewall_ip
  subscription_alias = ["sub2"]
  tags = var.tags
}
module "udr_creation_module_sub3" {
  source = "./modules/udr_creation"
  providers = {
    azurerm = azurerm.sub3
  }
  vnets = var.vnets
  firewall_ip = var.firewall_ip
  subscription_alias = ["sub3"]
  tags = var.tags
}
