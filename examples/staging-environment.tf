# Staging Environment - Production-like but Optimized
# This example shows a staging setup that mirrors production but with cost optimizations

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# Local values for staging environment
locals {
  # Environment configuration
  environment         = "staging"
  environment_abbrev  = "stg"
  organization_prefix = "contoso"
  location           = "East US"
  location_abbrev    = "eus"
  
  # Common tags that satisfy mandatory tagging policy
  common_tags = {
    Environment     = local.environment
    Owner          = "qa-team@contoso.com"
    Project        = "CustomerPortal"
    CostCenter     = "Engineering"
    Application    = "WebApp"
    BackupPolicy   = "Standard"
    ComplianceLevel = "Internal"
    Criticality    = "Medium"
  }
  
  # Naming convention for staging
  resource_suffix = "${local.organization_prefix}-${local.environment_abbrev}-${local.location_abbrev}-001"
}

# Resource Group
resource "azurerm_resource_group" "staging" {
  name     = "rg-${local.resource_suffix}"
  location = local.location
  tags     = local.common_tags
}

# Recovery Services Vault for staging backups
resource "azurerm_recovery_services_vault" "staging" {
  name                = "rsv-${local.resource_suffix}"
  location            = azurerm_resource_group.staging.location
  resource_group_name = azurerm_resource_group.staging.name
  sku                 = "Standard"
  
  # Staging backup configuration
  storage_mode_type = "LocallyRedundant"  # LRS acceptable for staging
  
  tags = local.common_tags
}

# Key Vault for staging secrets
resource "azurerm_key_vault" "staging" {
  name                = "kv-${local.resource_suffix}"
  location            = azurerm_resource_group.staging.location
  resource_group_name = azurerm_resource_group.staging.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  
  sku_name = "standard"  # Standard tier for staging
  
  # Security settings for staging
  enable_rbac_authorization    = true
  purge_protection_enabled     = true
  soft_delete_retention_days   = 30
  
  # Network security
  public_network_access_enabled = false
  
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    
    virtual_network_subnet_ids = [azurerm_subnet.app.id]
  }
  
  tags = local.common_tags
}

# Storage Account - staging configuration
resource "azurerm_storage_account" "staging" {
  name                = "st${replace(local.resource_suffix, "-", "")}"
  resource_group_name = azurerm_resource_group.staging.name
  location            = azurerm_resource_group.staging.location
  
  # Balanced cost and performance for staging
  account_tier             = "Standard"
  account_replication_type = "ZRS"  # Zone redundancy for better testing
  account_kind            = "StorageV2"
  
  # Security requirements
  https_traffic_only_enabled = true
  min_tls_version            = "TLS1_2"
  
  # Blob properties for staging
  blob_properties {
    versioning_enabled       = true
    last_access_time_enabled = true
    
    delete_retention_policy {
      days = 14  # Moderate retention for staging
    }
    
    container_delete_retention_policy {
      days = 14
    }
  }
  
  tags = local.common_tags
}

# Virtual Network with appropriate sizing
resource "azurerm_virtual_network" "staging" {
  name                = "vnet-${local.resource_suffix}"
  address_space       = ["10.2.0.0/16"]
  location            = azurerm_resource_group.staging.location
  resource_group_name = azurerm_resource_group.staging.name
  
  # DDoS protection not required for staging but can be added
  tags = local.common_tags
}

# Application tier subnet
resource "azurerm_subnet" "app" {
  name                 = "snet-app-${local.resource_suffix}"
  resource_group_name  = azurerm_resource_group.staging.name
  virtual_network_name = azurerm_virtual_network.staging.name
  address_prefixes     = ["10.2.1.0/24"]
  
  service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.Sql"]
}

# Database tier subnet
resource "azurerm_subnet" "db" {
  name                 = "snet-db-${local.resource_suffix}"
  resource_group_name  = azurerm_resource_group.staging.name
  virtual_network_name = azurerm_virtual_network.staging.name
  address_prefixes     = ["10.2.2.0/24"]
  
  service_endpoints = ["Microsoft.Sql"]
}

# Application Gateway subnet
resource "azurerm_subnet" "appgw" {
  name                 = "snet-appgw-${local.resource_suffix}"
  resource_group_name  = azurerm_resource_group.staging.name
  virtual_network_name = azurerm_virtual_network.staging.name
  address_prefixes     = ["10.2.3.0/24"]
}

# Network Security Group for application tier
resource "azurerm_network_security_group" "app" {
  name                = "nsg-app-${local.resource_suffix}"
  location            = azurerm_resource_group.staging.location
  resource_group_name = azurerm_resource_group.staging.name
  
  # Allow HTTPS from Application Gateway
  security_rule {
    name                         = "AllowHTTPSFromAppGW"
    priority                     = 1001
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "443"
    source_address_prefix        = "10.2.3.0/24"
    destination_address_prefix   = "*"
  }
  
  # Allow HTTP from Application Gateway
  security_rule {
    name                         = "AllowHTTPFromAppGW"
    priority                     = 1002
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "80"
    source_address_prefix        = "10.2.3.0/24"
    destination_address_prefix   = "*"
  }
  
  # Allow SSH from management subnet
  security_rule {
    name                         = "AllowSSHFromMgmt"
    priority                     = 1003
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "22"
    source_address_prefix        = "203.0.113.0/24"  # Management network
    destination_address_prefix   = "*"
  }
  
  tags = local.common_tags
}

# Associate NSG with application subnet
resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

# Public IP for Application Gateway
resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.staging.name
  location            = azurerm_resource_group.staging.location
  allocation_method   = "Static"
  sku                = "Standard"
  zones              = ["1", "2"]  # Multi-zone for better testing
  
  tags = local.common_tags
}

# Application Gateway - staging configuration
resource "azurerm_application_gateway" "staging" {
  name                = "agw-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.staging.name
  location            = azurerm_resource_group.staging.location
  
  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1  # Minimum capacity for staging
  }
  
  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.appgw.id
  }
  
  frontend_port {
    name = "https"
    port = 443
  }
  
  frontend_port {
    name = "http"
    port = 80
  }
  
  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }
  
  backend_address_pool {
    name = "appgw-backend-pool"
  }
  
  backend_http_settings {
    name                  = "appgw-backend-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }
  
  http_listener {
    name                           = "appgw-http-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }
  
  request_routing_rule {
    name                       = "appgw-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "appgw-http-listener"
    backend_address_pool_name  = "appgw-backend-pool"
    backend_http_settings_name = "appgw-backend-http-settings"
    priority                   = 1
  }
  
  # WAF configuration for staging
  waf_configuration {
    enabled          = true
    firewall_mode    = "Detection"  # Detection mode for staging testing
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }
  
  zones = ["1", "2"]  # Multi-zone deployment
  
  tags = local.common_tags
}

# Virtual Machine Scale Set for application tier
resource "azurerm_linux_virtual_machine_scale_set" "app" {
  name                = "vmss-app-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.staging.name
  location            = azurerm_resource_group.staging.location
  sku                 = "Standard_B2s"  # Cost-effective for staging
  instances           = 2              # Minimum for HA testing
  
  admin_username                  = "staginguser"
  disable_password_authentication = true
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  
  os_disk {
    storage_account_type = "Standard_SSD_LRS"
    caching              = "ReadWrite"
  }
  
  admin_ssh_key {
    username   = "staginguser"
    public_key = file("~/.ssh/id_rsa.pub")
  }
  
  network_interface {
    name    = "nic-app"
    primary = true
    
    ip_configuration {
      name                          = "internal"
      primary                       = true
      subnet_id                     = azurerm_subnet.app.id
      application_gateway_backend_address_pool_ids = [
        "${azurerm_application_gateway.staging.id}/backendAddressPools/appgw-backend-pool"
      ]
    }
  }
  
  tags = merge(local.common_tags, {
    AutoShutdown = "21:00"  # Later shutdown for staging testing
  })
}

# SQL Server for staging
resource "azurerm_mssql_server" "staging" {
  name                         = "sql-${local.resource_suffix}"
  resource_group_name          = azurerm_resource_group.staging.name
  location                     = azurerm_resource_group.staging.location
  version                      = "12.0"
  administrator_login          = "stagingadmin"
  administrator_login_password = var.sql_admin_password
  
  # Network security
  public_network_access_enabled = false
  
  tags = local.common_tags
}

# SQL Database with staging-appropriate settings
resource "azurerm_mssql_database" "staging" {
  name           = "db-staging-${local.resource_suffix}"
  server_id      = azurerm_mssql_server.staging.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  sku_name       = "S2"  # Standard tier for staging
  zone_redundant = false # Single zone acceptable for staging
  
  # Backup configuration for staging
  short_term_retention_policy {
    retention_days = 14
  }
  
  tags = local.common_tags
}

# Container Registry for staging images
resource "azurerm_container_registry" "staging" {
  name                = "acr${replace(local.resource_suffix, "-", "")}"
  resource_group_name = azurerm_resource_group.staging.name
  location            = azurerm_resource_group.staging.location
  sku                 = "Standard"  # Standard tier for staging
  
  admin_enabled = false
  
  # Network security
  public_network_access_enabled = false
  
  network_rule_set {
    default_action = "Deny"
    
    ip_rule {
      action   = "Allow"
      ip_range = "203.0.113.0/24"  # Corporate network
    }
  }
  
  tags = local.common_tags
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "staging" {
  name                = "law-${local.resource_suffix}"
  location            = azurerm_resource_group.staging.location
  resource_group_name = azurerm_resource_group.staging.name
  sku                 = "PerGB2018"
  retention_in_days   = 60  # Longer retention for staging analysis
  
  tags = local.common_tags
}

# Application Insights
resource "azurerm_application_insights" "staging" {
  name                = "appi-${local.resource_suffix}"
  location            = azurerm_resource_group.staging.location
  resource_group_name = azurerm_resource_group.staging.name
  workspace_id        = azurerm_log_analytics_workspace.staging.id
  application_type    = "web"
  
  tags = local.common_tags
}

# Private Endpoint for SQL Server
resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-${local.resource_suffix}"
  location            = azurerm_resource_group.staging.location
  resource_group_name = azurerm_resource_group.staging.name
  subnet_id           = azurerm_subnet.db.id
  
  private_service_connection {
    name                           = "psc-sql"
    private_connection_resource_id = azurerm_mssql_server.staging.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }
  
  tags = local.common_tags
}

# Variables
variable "sql_admin_password" {
  description = "SQL Server administrator password"
  type        = string
  sensitive   = true
}

# Data source
data "azurerm_client_config" "current" {}

# Outputs
output "resource_group_name" {
  description = "Name of the staging resource group"
  value       = azurerm_resource_group.staging.name
}

output "application_gateway_public_ip" {
  description = "Public IP of the Application Gateway"
  value       = azurerm_public_ip.appgw.ip_address
}

output "sql_server_fqdn" {
  description = "SQL Server FQDN"
  value       = azurerm_mssql_server.staging.fully_qualified_domain_name
  sensitive   = true
}

output "container_registry_login_server" {
  description = "Container Registry login server"
  value       = azurerm_container_registry.staging.login_server
}

output "staging_features" {
  description = "Staging environment features"
  value = {
    "multi_zone_deployment"     = "enabled"
    "waf_mode"                 = "detection"
    "private_endpoints"        = "enabled"
    "container_registry"       = "standard_tier"
    "sql_backup_retention"     = "14_days"
    "log_retention"            = "60_days"
  }
}
