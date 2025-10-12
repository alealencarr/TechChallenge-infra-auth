terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstatetchungryale"
    container_name       = "tfstate"
    key                  = "infra-gateway.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# --- Data Sources ---

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
}

data "azurerm_subnet" "apim_subnet" {
  name                 = var.apim_subnet_name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.rg.name
}

# Lê o estado remoto do infra-compute
data "terraform_remote_state" "compute" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstatetchungryale"
    container_name       = "tfstate"
    key                  = "infra-compute.tfstate"
  }
}

# Data source para obter o Application Gateway criado pelo AKS/AGIC
data "azurerm_application_gateway" "aks_agic_gateway" {
  name                = var.app_gateway_name
  resource_group_name = data.terraform_remote_state.compute.outputs.aks_resource_group
  depends_on          = [data.terraform_remote_state.compute]
}

# --- 1. API Management (APIM) ---

resource "azurerm_api_management" "apim" {
  name                = var.apim_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = "Developer_1"
  
  virtual_network_type = "External"
  virtual_network_configuration {
    subnet_id = data.azurerm_subnet.apim_subnet.id
  }
}

# --- 2. Private DNS Zone para resolução interna ---

resource "azurerm_private_dns_zone" "internal_api" {
  name                = var.internal_dns_zone_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_link" {
  name                  = "dns-link-to-vnet"
  resource_group_name   = data.azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.internal_api.name
  virtual_network_id    = data.azurerm_virtual_network.vnet.id
}

# --- 3. DNS A Record - Aponta pro IP público do Application Gateway ---

resource "azurerm_private_dns_a_record" "ingress_dns_record" {
  name                = "@"
  zone_name           = azurerm_private_dns_zone.internal_api.name
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 300
  
  # CRÍTICO: Pega o IP PÚBLICO do Application Gateway dinamicamente
  # O AGIC cria o Application Gateway com IP público, então pegamos esse IP
  records = [
    for config in data.azurerm_application_gateway.aks_agic_gateway.frontend_ip_configuration :
    data.azurerm_public_ip.app_gateway_pip.ip_address
    if config.public_ip_address_id != null
  ]
  
  depends_on = [data.azurerm_application_gateway.aks_agic_gateway]
}

# Data source para pegar o IP público do Application Gateway
data "azurerm_public_ip" "app_gateway_pip" {
  name                = "agw-ingress-tchungry-appgwpip"
  resource_group_name = data.terraform_remote_state.compute.outputs.aks_resource_group
}

# --- 4. BACKENDS DO APIM ---

# Backend do AKS (via DNS interno)
resource "azurerm_api_management_backend" "api_aks_backend" {
  name                = "apiaksbackend-v1-1"
  resource_group_name = data.azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  protocol            = "http"
  url                 = "http://${var.internal_dns_zone_name}/api"
  depends_on          = [azurerm_api_management.apim, azurerm_private_dns_a_record.ingress_dns_record]
}

# Backend da Function App
resource "azurerm_api_management_backend" "auth_function_backend" {
  name                = "authfunctionbackend-v1-1"
  resource_group_name = data.azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  protocol            = "http"
  url                 = "https://${data.terraform_remote_state.compute.outputs.function_app_default_hostname}/api"
  depends_on          = [azurerm_api_management.apim, data.terraform_remote_state.compute]
}

# --- 5. API DO APIM ---

resource "azurerm_api_management_api" "lanchonete_api" {
  name                  = "lanchonete-api"
  resource_group_name   = data.azurerm_resource_group.rg.name
  api_management_name   = azurerm_api_management.apim.name
  revision              = "1"
  display_name          = "API Hungry"
  path                  = "api"
  protocols             = ["https"]
  subscription_required = false
  depends_on            = [azurerm_api_management.apim]
}

# Operações catch-all para todos os métodos HTTP
locals {
  http_methods = ["GET", "POST", "PUT", "DELETE", "PATCH"]
}

resource "azurerm_api_management_api_operation" "catch_all" {
  for_each = toset(local.http_methods)
  
  operation_id        = "catch-all-${lower(each.value)}"
  api_name            = azurerm_api_management_api.lanchonete_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = data.azurerm_resource_group.rg.name
  display_name        = "Catch-all ${each.value}"
  method              = each.value
  url_template        = "/*"
  
  response {
    status_code = 200
  }
  
  depends_on = [azurerm_api_management_api.lanchonete_api]
}

# --- 6. Política de roteamento ---

resource "azurerm_api_management_api_policy" "lanchonete_api_policy" {
  api_name            = azurerm_api_management_api.lanchonete_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = data.azurerm_resource_group.rg.name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <rate-limit calls="100" renewal-period="60" />
    <choose>
      <when condition="@(context.Request.Url.Path.Contains("auth") || context.Request.Url.Path.Contains("register"))">
        <set-backend-service backend-id="${azurerm_api_management_backend.auth_function_backend.name}" />
      </when>
      <otherwise>
        <set-backend-service backend-id="${azurerm_api_management_backend.api_aks_backend.name}" />
      </otherwise>
    </choose>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML

  depends_on = [
    azurerm_api_management_api_operation.catch_all,
    azurerm_api_management_backend.auth_function_backend,
    azurerm_api_management_backend.api_aks_backend
  ]
}


