variable "firewall_ip" {
  description = "Firewall IP address to use in UDR routing rules"
  default = "10.10.10.10"
}

variable "list_vnets_json_file" {
  description = "JSON file with VNETS to consider for UDR creation"
  default = "../../tmp_creation_vnets.json"
}

variable "tags" {
    description = "Tags to apply to every new resource created"
    default     = {
        "app"             = ""
        "environment"     = "PRD"
    }
}
