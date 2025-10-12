variable "resource_group_name" {
  type        = string
  description = "Nome do resource group principal"
  default     = "rg-tchungry-prod"
}

variable "location" {
  type        = string
  description = "Região do Azure"
  default     = "Brazil South"
}

variable "vnet_name" {
  type        = string
  description = "Nome da VNET"
  default     = "vnet-tchungry-prod"
}

variable "apim_subnet_name" {
  type        = string
  description = "Nome da subnet do APIM"
  default     = "snet-apim"
}

variable "apim_name" {
  type        = string
  description = "Nome do API Management"
  default     = "apim-tchungry-gateway-latest"
}

variable "app_gateway_name" {
  type        = string
  description = "Nome do Application Gateway criado pelo AGIC"
  default     = "agw-ingress-tchungry"
}

variable "internal_dns_zone_name" {
  type        = string
  description = "Nome da zona DNS privada"
  default     = "api.internal.techchallenge"
}

variable "publisher_name" {
  type        = string
  description = "Nome do publisher do APIM"
  default     = "TechChallenge_RM364893"
}

variable "publisher_email" {
  type        = string
  description = "Email do publisher do APIM"
  default     = "ale.alencarr@outlook.com.br"
}
