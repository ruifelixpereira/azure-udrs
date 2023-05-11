variable "firewall_ip" {
  description = "Firewall IP address to use in UDR routing rules"
  default = "10.10.10.10"
}

variable "list_vnets_json_file" {
  description = "JSON file with VNETS to consider for UDR creation"
  default = "../../tmp_association_subnets.json"
}

variable "subscriptions" {
    description = "Map of subscriptions and alias"
    default = {
        "alias1" = "sub1"
        "alias2" = "sub2"
    }
}

variable "tags" {
    description = "Tags to apply to every new resource created"
    default     = {
        "app"             = ""
        "environment"     = "PRD"
    }
}
