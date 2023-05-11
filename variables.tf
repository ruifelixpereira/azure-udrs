variable "firewall_ip" {
  description = "Firewall IP address to use in UDR routing rules"
  default = "10.10.10.10"
}

variable "tags" {
    description = "Tags to apply to every new resource created"
    default     = {
        "app"             = ""
        "environment"     = "PRD"
    }
}

variable "client_id" {
  description = "The Client ID for the Service Principal to use"
}

variable "client_secret" {
  description = "The Client Secret for the Service Principal to use"
}

variable "tenant_id" {
  description = "The Client Secret for the Service Principal to use"
}
