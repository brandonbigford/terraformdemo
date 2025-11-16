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
  name     = "appservice-sql-rg"
  location = "West US 3"

  tags = {
    Terraform = "true"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-appservice-sql"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    Terraform = "true"
  }
}

# Subnet for Private Endpoint (no tags supported)
resource "azurerm_subnet" "private_subnet" {
  name                 = "private-endpoint-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# App Service Plan (Windows)
resource "azurerm_app_service_plan" "asp" {
  name                = "asp-windows"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "Windows"

  sku {
    tier = "Basic"
    size = "B1"
  }

  tags = {
    Terraform = "true"
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

  tags = {
    Terraform = "true"
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

  tags = {
    Terraform = "true"
  }
}

# SQL Database
resource "azurerm_mssql_database" "sqldb" {
  name           = "sqldbdemo"
  server_id      = azurerm_mssql_server.sqlserver.id
  sku_name       = "Basic"

  tags = {
    Terraform = "true"
  }
}

# Private DNS Zone for SQL Database
resource "azurerm_private_dns_zone" "sql_dns" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    Terraform = "true"
  }
}

# Virtual Network Link to DNS Zone (no tags supported)
resource "azurerm_private_dns_zone_virtual_network_link" "dns_link" {
  name                  = "dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.sql_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# Private Endpoint for SQL Server
resource "azurerm_private_endpoint" "sql_private_endpoint" {
  name                = "sql-private-endpoint"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.private_subnet.id

  private_service_connection {
    name                           = "sql-priv-connection"
    private_connection_resource_id = azurerm_mssql_server.sqlserver.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  tags = {
    Terraform = "true"
  }
}

# DNS A Record for SQL Server Private Endpoint (no tags supported)
resource "azurerm_private_dns_a_record" "sql_dns_record" {
  name                = azurerm_mssql_server.sqlserver.name
  zone_name           = azurerm_private_dns_zone.sql_dns.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.sql_private_endpoint.private_service_connection[0].private_ip_address]
}
