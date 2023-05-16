variable "firewall_ip" {
  description = "Firewall IP address to use in UDR routing rules"
  default = "10.10.10.10"
}

variable "vnets" {
    description = "VNETs rules for UDR creation"
    type = map
}

variable "subscription_alias" {
    description = "Subscription alias for which to consider VNETs UDR creation"
    type = set(string)
}

variable "tags" {
    description = "Tags to apply to every new resource created"
    default     = {
        "app"             = ""
        "environment"     = "PRD"
    }
}
