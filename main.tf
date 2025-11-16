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

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-appservice-sql"
  location = "East US"
}

# App Service Plan (Windows)
resource "azurerm_app_service_plan" "asp" {
  name                = "asp-windows"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "Windows"

  sku {
    tier = "Standard"
    size = "S1"
  }
}

# App Service (Web App with IIS)
resource "azurerm_windows_web_app" "webapp" {
  name                = "iis-webapp-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_app_service_plan.asp.id

  site_config {
    always_on = true
    ftps_state = "Disabled"
  }

  app_settings = {
    "WEBSITE_NODE_DEFAULT_VERSION" = "~14"
  }
}

# SQL Server
resource "azurerm_mssql_server" "sqlserver" {
  name                         = "sqlserverdemo123"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "sqladminuser"
  administrator_login_password = "P@ssword1234!"
}

# SQL Database
resource "azurerm_mssql_database" "sqldb" {
  name           = "sqldbdemo"
  server_id      = azurerm_mssql_server.sqlserver.id
  sku_name       = "S0"
}
