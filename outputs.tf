output "api_management_gateway_url" {
  description = "URL pública do APIM - Clientes devem usar essa URL"
  value       = azurerm_api_management.apim.gateway_url
}

output "application_gateway_public_ip" {
  description = "IP público do Application Gateway"
  value       = data.azurerm_public_ip.app_gateway_pip.ip_address
}

output "function_app_url" {
  description = "URL da Function App de autenticação"
  value       = data.terraform_remote_state.compute.outputs.function_app_default_hostname
}

output "internal_dns_zone" {
  description = "Nome da zona DNS privada"
  value       = azurerm_private_dns_zone.internal_api.name
}