#
# UDR creation 
#
module "udr_creation_module" {
  source  = "./modules/udr_creation"

  # arguments
  vnets = var.vnets
  firewall_ip = var.firewall_ip
  location = var.location
  tags = var.tags
}

/*
module "udr_association_module" {
  source  = "./modules/udr_association"

  # arguments
  udr_resource_group = var.udr_resource_group
  firewall_ip = var.firewall_ip
  tags = var.tags
}
*/