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

# --- BLOCO CORRIGIDO E DEFINITIVO ABAIXO ---
resource "azurerm_linux_function_app" "auth_function" {
  name                = "func-tchungry-auth"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  storage_account_name       = azurerm_storage_account.function_storage.name
  storage_account_access_key = azurerm_storage_account.function_storage.primary_access_key
  service_plan_id            = azurerm_service_plan.function_plan.id

  # Removemos o site_config completamente para evitar conflitos
  site_config {}

  # ✅ A SOLUÇÃO DEFINITIVA:
  # Definimos a stack de execução diretamente nas configurações da aplicação.
  # Esta é a forma mais direta e contorna a validação confusa do Terraform.
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "dotnet-isolated",
    "linuxFxVersion"           = "DOTNET-ISOLATED|9.0"
  }
}
# --- FIM DO BLOCO CORRIGIDO ---

resource "azurerm_api_management" "apim" {
  name                = "apim-tchungry-gateway"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = "Consumption_0"
}