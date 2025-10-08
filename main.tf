terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# --- Storage Account para Function ---
resource "azurerm_storage_account" "function_storage" {
  name                     = "stauth${replace(var.resource_group_name, "-", "")}"
  resource_group_name      = data.azurerm_resource_group.rg.name
  location                 = data.azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# --- Service Plan para Function ---
resource "azurerm_service_plan" "function_plan" {
  name                = "plan-auth-serverless"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

# --- Function App ---
resource "azurerm_linux_function_app" "auth_function" {
  name                       = "func-tchungry-auth"
  resource_group_name        = data.azurerm_resource_group.rg.name
  location                   = data.azurerm_resource_group.rg.location
  storage_account_name       = azurerm_storage_account.function_storage.name
  storage_account_access_key = azurerm_storage_account.function_storage.primary_access_key
  service_plan_id            = azurerm_service_plan.function_plan.id
  
  site_config {
    application_stack {
      dotnet_version              = "8.0"
      use_dotnet_isolated_runtime = true
    }
  }
  
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "dotnet-isolated"
  }
}

# --- API Management ---
resource "azurerm_api_management" "apim" {
  name                = "apim-tchungry-gateway"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = "Consumption_0"
}

# --- Backend para AKS ---
resource "azurerm_api_management_backend" "api_aks_backend" {
  name                = "apiaksbackendlatest"
  resource_group_name = data.azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  protocol            = "http"
  url                 = "http://tchungry-api.brazilsouth.cloudapp.azure.com"
  
  depends_on = [azurerm_api_management.apim]
}

# --- Backend para Function ---
resource "azurerm_api_management_backend" "auth_function_backend" {
  name                = "authfunctionbackendlatest"
  resource_group_name = data.azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  protocol            = "http"
  url                 = "https://func-tchungry-auth.azurewebsites.net"
  
  depends_on = [azurerm_api_management.apim]
}

# --- API ---
resource "azurerm_api_management_api" "lanchonete_api" {
  name                = "lanchonete-api"
  resource_group_name = data.azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "API Hungry"
  path                = "api"
  protocols           = ["https"]
  
  depends_on = [azurerm_api_management.apim]
}

# --- Policy da API ---
resource "azurerm_api_management_api_policy" "lanchonete_api_policy" {
  api_name            = azurerm_api_management_api.lanchonete_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = data.azurerm_resource_group.rg.name

  xml_content = <<-EOT
    <policies>
        <inbound>
            <base />
            <rate-limit-by-key calls="100" renewal-period="60" counter-key="@(context.Request.IpAddress)" />
            
            <choose>
                <when condition="@(context.Request.Url.Path.Contains("/register") || context.Request.Url.Path.Contains("/auth"))">
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
  EOT

  depends_on = [
    azurerm_api_management_api.lanchonete_api,
    azurerm_api_management_backend.api_aks_backend,
    azurerm_api_management_backend.auth_function_backend
  ]
}
