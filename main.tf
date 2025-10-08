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

# --- Recursos da Function (sem alteração) ---
resource "azurerm_storage_account" "function_storage" {
  name                     = "stauth${replace(var.resource_group_name, "-", "")}"
  resource_group_name      = data.azurerm_resource_group.rg.name
  location                 = data.azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "function_plan" {
  name                = "plan-auth-serverless"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "auth_function" {
  name                = "func-tchungry-auth"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  storage_account_name       = azurerm_storage_account.function_storage.name
  storage_account_access_key = azurerm_storage_account.function_storage.primary_access_key
  service_plan_id            = azurerm_service_plan.function_plan.id
  site_config {}
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "dotnet-isolated",
    "linuxFxVersion"           = "DOTNET-ISOLATED|8.0"
  }
}

# --- Recurso do APIM (sem alteração) ---
resource "azurerm_api_management" "apim" {
  name                = "apim-tchungry-gateway"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = "Consumption_0"
}

# --- Configuração do APIM (COM A CORREÇÃO FINAL) ---

resource "azurerm_api_management_backend" "api_aks_backend" {
  name                = "api-aks-backend"
  resource_group_name = data.azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  protocol            = "http"
  url                 = "http://tchungry-api.brazilsouth.cloudapp.azure.com"
  depends_on          = [azurerm_api_management.apim]
}

resource "azurerm_api_management_backend" "auth_function_backend" {
  name                = "auth-function-backend"
  resource_group_name = data.azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  protocol            = "http"
  url                 = "https://func-tchungry-auth.azurewebsites.net"
  depends_on          = [azurerm_api_management.apim]
}

resource "azurerm_api_management_api" "lanchonete_api" {
  name                = "lanchonete-api"
  resource_group_name = data.azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "API Hungry"
  path                = "api"
  protocols           = ["https"]
  depends_on          = [azurerm_api_management.apim]
}

resource "azurerm_api_management_api_policy" "lanchonete_api_policy" {
  api_name            = azurerm_api_management_api.lanchonete_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = data.azurerm_resource_group.rg.name

  xml_content = <<-EOT
    <policies>
        <inbound>
            <base />
            <rate-limit-by-key calls="100" renewal-period="60" counter-key="@(context.Request.IpAddress)" />
            
            <!-- ✅ BLOCO LÓGICO CORRIGIDO PARA AS SUAS ROTAS REAIS -->
            <choose>
                <!-- Se o caminho da URL for exatamente /api/register ou /api/auth... -->
                <when condition="@(context.Request.Url.Path.Equals("/api/register") || context.Request.Url.Path.Equals("/api/auth"))">
                    <!-- ...então envie a requisição para o backend da Azure Function -->
                    <set-backend-service backend-id="${azurerm_api_management_backend.auth_function_backend.name}" />
                </when>
                
                <otherwise>
                    <!-- Para tudo o resto, envie a requisição para o backend da API no AKS -->
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
