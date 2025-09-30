variable "resource_group_name" {
  type        = string
  description = "O nome do grupo de recursos onde os recursos de autenticação serão criados."
  default     = "rg-tchungry-prod"
}

variable "location" {
  type        = string
  description = "A região do Azure onde os recursos serão criados."
  default     = "Brazil South"
}

variable "publisher_email" {
  type        = string
  description = "Email do publicador para o API Management."
  # Coloque seu email aqui
  default     = "ale.alencarr@outlook.com.br" 
}

variable "publisher_name" {
  type        = string
  description = "Nome do publicador para o API Management."
  default     = "TechChallenge_RM364893"
}