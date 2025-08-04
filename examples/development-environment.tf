# Development Environment - Compliant but Cost-Optimized
# This example shows a cost-effective development setup that complies with all policies

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
  }
}

# Local values for development environment
locals {
  # Environment configuration
  environment         = "dev"
  environment_abbrev  = "dev"
  organization_prefix = "contoso"
  location           = "East US 2"  # Often cheaper than East US
  location_abbrev    = "eus2"
  
  # Common tags that satisfy mandatory tagging policy
  common_tags = {
    Environment   = local.environment
    Owner        = "dev-team@contoso.com"
    Project      = "ProductDevelopment"
    CostCenter   = "Engineering"
    Application  = "DevWorkloads"
    AutoShutdown = "enabled"  # Cost optimization
  }
  
  # Naming convention for development
  resource_suffix = "${local.organization_prefix}-${local.environment_abbrev}-${local.location_abbrev}-001"
}

# Resource Group - compliant with naming and tagging
resource "azurerm_resource_group" "dev" {
  name     = "rg-${local.resource_suffix}"
  location = local.location
  tags     = local.common_tags
}

# Storage Account - cost-optimized but compliant
resource "azurerm_storage_account" "dev" {
  name                = "st${replace(local.resource_suffix, "-", "")}"
  resource_group_name = azurerm_resource_group.dev.name
  location            = azurerm_resource_group.dev.location
  
  # Cost-effective settings for development
  account_tier             = "Standard"
  account_replication_type = "LRS"  # Local redundancy sufficient for dev
  account_kind            = "StorageV2"
  
  # Security requirements still enforced
  https_traffic_only_enabled = true
  min_tls_version            = "TLS1_2"
  
  # Basic blob properties for development
  blob_properties {
    versioning_enabled = false  # Not required for dev
    
    delete_retention_policy {
      days = 7  # Shorter retention for dev
    }
  }
  
  tags = local.common_tags
}

# Virtual Network - basic setup for development
resource "azurerm_virtual_network" "dev" {
  name                = "vnet-${local.resource_suffix}"
  address_space       = ["10.1.0.0/16"]  # Smaller address space
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  
  # DDoS protection not required for development
  tags = local.common_tags
}

# Development subnet
resource "azurerm_subnet" "dev" {
  name                 = "snet-dev-${local.resource_suffix}"
  resource_group_name  = azurerm_resource_group.dev.name
  virtual_network_name = azurerm_virtual_network.dev.name
  address_prefixes     = ["10.1.1.0/24"]
}

# Network Security Group - secure but development-appropriate
resource "azurerm_network_security_group" "dev" {
  name                = "nsg-dev-${local.resource_suffix}"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  
  # Allow SSH from corporate network only
  security_rule {
    name                       = "AllowSSHFromCorporate"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "203.0.113.0/24"  # Corporate IP range
    destination_address_prefix = "*"
  }
  
  # Allow HTTP for development testing
  security_rule {
    name                       = "AllowHTTPDev"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "203.0.113.0/24"  # Corporate IP range only
    destination_address_prefix = "*"
  }
  
  # Allow development ports
  security_rule {
    name                       = "AllowDevPorts"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["3000", "8080", "9000"]  # Common dev ports
    source_address_prefix      = "203.0.113.0/24"
    destination_address_prefix = "*"
  }
  
  tags = local.common_tags
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "dev" {
  subnet_id                 = azurerm_subnet.dev.id
  network_security_group_id = azurerm_network_security_group.dev.id
}

# Development VM - cost-optimized size
resource "azurerm_linux_virtual_machine" "dev" {
  name                = "lvm-dev-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.dev.name
  location            = azurerm_resource_group.dev.location
  size                = "Standard_B2s"  # Burstable performance, cost-effective
  
  # No availability zone required for development
  admin_username                  = "devuser"
  disable_password_authentication = true
  
  network_interface_ids = [
    azurerm_network_interface.dev.id,
  ]
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_SSD_LRS"  # SSD for better performance, LRS for cost
  }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  
  admin_ssh_key {
    username   = "devuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }
  
  tags = merge(local.common_tags, {
    AutoShutdown = "19:00"  # Auto-shutdown at 7 PM for cost savings
    Criticality  = "Low"
  })
}

# Network Interface for development VM
resource "azurerm_network_interface" "dev" {
  name                = "nic-dev-${local.resource_suffix}"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dev.id
    private_ip_address_allocation = "Dynamic"
  }
  
  tags = local.common_tags
}

# App Service Plan - development tier
resource "azurerm_service_plan" "dev" {
  name                = "asp-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.dev.name
  location            = azurerm_resource_group.dev.location
  
  os_type  = "Linux"
  sku_name = "B1"  # Basic tier for development
  
  tags = local.common_tags
}

# App Service for development
resource "azurerm_linux_web_app" "dev" {
  name                = "app-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.dev.name
  location            = azurerm_service_plan.dev.location
  service_plan_id     = azurerm_service_plan.dev.id
  
  site_config {
    always_on           = false  # Cost optimization for dev
    minimum_tls_version = "1.2"
    
    application_stack {
      node_version = "18-lts"
    }
  }
  
  https_only = true
  
  app_settings = {
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
    "ENVIRONMENT"                  = "development"
  }
  
  tags = local.common_tags
}

# Key Vault for development secrets
resource "azurerm_key_vault" "dev" {
  name                = "kv-${local.resource_suffix}"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  
  sku_name = "standard"  # Standard tier acceptable for development
  
  # Security settings appropriate for development
  enable_rbac_authorization    = true
  purge_protection_enabled     = false  # Allow purge in development
  soft_delete_retention_days   = 7      # Shorter retention for dev
  
  # Restrict network access even in development
  public_network_access_enabled = false
  
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    
    # Allow access from development subnet
    virtual_network_subnet_ids = [azurerm_subnet.dev.id]
  }
  
  tags = local.common_tags
}

# Container Registry for development
resource "azurerm_container_registry" "dev" {
  name                = "acr${replace(local.resource_suffix, "-", "")}"
  resource_group_name = azurerm_resource_group.dev.name
  location            = azurerm_resource_group.dev.location
  sku                 = "Basic"  # Basic tier for development
  
  # Disable admin user for security
  admin_enabled = false
  
  tags = local.common_tags
}

# PostgreSQL Flexible Server for development
resource "azurerm_postgresql_flexible_server" "dev" {
  name                = "psql-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.dev.name
  location            = azurerm_resource_group.dev.location
  
  administrator_login    = "devadmin"
  administrator_password = "DevPassword123!"  # In real scenario, use Key Vault
  
  sku_name = "B_Standard_B1ms"  # Burstable tier for development
  version  = "13"
  
  storage_mb = 32768  # 32GB storage
  
  # Basic backup settings for development
  backup_retention_days = 7
  
  tags = local.common_tags
}

# PostgreSQL Database
resource "azurerm_postgresql_flexible_server_database" "dev" {
  name      = "devdatabase"
  server_id = azurerm_postgresql_flexible_server.dev.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "dev" {
  name                = "law-${local.resource_suffix}"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  sku                 = "PerGB2018"
  retention_in_days   = 30  # Shorter retention for development
  
  tags = local.common_tags
}

# Application Insights
resource "azurerm_application_insights" "dev" {
  name                = "appi-${local.resource_suffix}"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  workspace_id        = azurerm_log_analytics_workspace.dev.id
  application_type    = "web"
  
  tags = local.common_tags
}

# Data source
data "azurerm_client_config" "current" {}

# Outputs
output "resource_group_name" {
  description = "Name of the development resource group"
  value       = azurerm_resource_group.dev.name
}

output "virtual_machine_name" {
  description = "Name of the development VM"
  value       = azurerm_linux_virtual_machine.dev.name
}

output "web_app_url" {
  description = "URL of the development web app"
  value       = "https://${azurerm_linux_web_app.dev.default_hostname}"
}

output "container_registry_login_server" {
  description = "Login server for the container registry"
  value       = azurerm_container_registry.dev.login_server
}

output "postgresql_fqdn" {
  description = "PostgreSQL server FQDN"
  value       = azurerm_postgresql_flexible_server.dev.fqdn
  sensitive   = true
}

output "cost_optimization_features" {
  description = "Cost optimization features enabled"
  value = {
    "vm_auto_shutdown"           = "19:00"
    "app_service_always_on"      = "disabled"
    "storage_replication"        = "LRS"
    "key_vault_purge_protection" = "disabled"
    "backup_retention"           = "7 days"
  }
}
