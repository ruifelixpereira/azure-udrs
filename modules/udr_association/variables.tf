variable "udr_name" {
    description = "Name of the UDR to associate with subnets"
}

variable "udr_resource_group_name" {
  description = "Resource group of the UDR to associate with subnets"
}

variable "subnets" {
  description = "List of subnets to associate with UDR"
  type = set(string)
}
