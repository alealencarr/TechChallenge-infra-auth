output "api_management_gateway_url" {
  description = "A URL base do API Gateway. Todos os clientes devem chamar esta URL."
  value       = azurerm_api_management.apim.gateway_url
}