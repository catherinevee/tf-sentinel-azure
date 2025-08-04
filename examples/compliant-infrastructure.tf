# Example Terraform configuration that complies with all Azure Sentinel policies
# This example demonstrates a production-ready Azure infrastructure setup

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

# Local values for consistent configuration
locals {
  # Environment configuration
  environment         = "prod"
  environment_abbrev  = "prd"
  organization_prefix = "contoso"
  location           = "East US"
  location_abbrev    = "eus"
  
  # Common tags that satisfy mandatory tagging policy
  common_tags = {
    Environment        = local.environment
    Owner             = "devops-team@contoso.com"
    Project           = "CustomerPortal"
    CostCenter        = "Engineering"
    Application       = "WebApp"
    BackupPolicy      = "Standard"
    ComplianceLevel   = "SOC2"
    DataClassification = "Internal"
    Criticality       = "High"
  }
  
  # Naming convention following azure-resource-naming policy
  resource_suffix = "${local.organization_prefix}-${local.environment_abbrev}-${local.location_abbrev}-001"
}

# Resource Group - compliant with naming and tagging policies
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.resource_suffix}"
  location = local.location
  tags     = local.common_tags
}

# Recovery Services Vault - compliant with backup policy
resource "azurerm_recovery_services_vault" "main" {
  name                = "rsv-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  
  # Production requirements for backup compliance
  storage_mode_type         = "GeoRedundant"
  cross_region_restore_enabled = true
  
  tags = local.common_tags
}

# Key Vault for encryption keys - compliant with naming and security policies
resource "azurerm_key_vault" "main" {
  name                = "kv-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  
  sku_name = "premium"  # Premium for HSM support in production
  
  # Security best practices
  enable_rbac_authorization     = true
  purge_protection_enabled     = true
  soft_delete_retention_days   = 90
  
  # Network security
  public_network_access_enabled = false
  
  tags = local.common_tags
}

# Storage Account - compliant with encryption and naming policies
resource "azurerm_storage_account" "main" {
  name                = "st${replace(local.resource_suffix, "-", "")}"  # Remove hyphens for storage account naming
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  # Cost-effective for production but with redundancy
  account_tier             = "Standard"
  account_replication_type = "GRS"  # Geo-redundant for production
  account_kind            = "StorageV2"
  
  # Security requirements
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  infrastructure_encryption_enabled = true
  
  # Blob properties for backup compliance
  blob_properties {
    versioning_enabled       = true
    last_access_time_enabled = true
    
    delete_retention_policy {
      days = 30
    }
    
    container_delete_retention_policy {
      days = 30
    }
  }
  
  tags = local.common_tags
}

# Virtual Network - compliant with network security policy
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.resource_suffix}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  # DDoS protection for production
  ddos_protection_plan {
    id     = azurerm_network_ddos_protection_plan.main.id
    enable = true
  }
  
  tags = local.common_tags
}

# DDoS Protection Plan for production VNet
resource "azurerm_network_ddos_protection_plan" "main" {
  name                = "ddos-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  tags = local.common_tags
}

# Subnet for web tier
resource "azurerm_subnet" "web" {
  name                 = "snet-web-${local.resource_suffix}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
  
  # Service endpoints for security
  service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
}

# Network Security Group - compliant with network security policy
resource "azurerm_network_security_group" "web" {
  name                = "nsg-web-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  # Allow HTTPS traffic from internet (compliant rule)
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # Allow HTTP traffic from internet (compliant rule)
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # Deny all other inbound traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  tags = local.common_tags
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

# Public IP for Application Gateway
resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                = "Standard"
  zones              = ["1", "2", "3"]  # Multi-zone for HA
  
  tags = local.common_tags
}

# Application Gateway - compliant with network security policy
resource "azurerm_application_gateway" "main" {
  name                = "agw-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
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
    name                           = "appgw-https-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "https"
    protocol                       = "Https"
    ssl_certificate_name           = "appgw-ssl-cert"
  }
  
  request_routing_rule {
    name                       = "appgw-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "appgw-https-listener"
    backend_address_pool_name  = "appgw-backend-pool"
    backend_http_settings_name = "appgw-backend-http-settings"
    priority                   = 1
  }
  
  ssl_certificate {
    name     = "appgw-ssl-cert"
    data     = filebase64("certificate.pfx")  # In real scenario, use Key Vault reference
    password = "certificate-password"          # In real scenario, use Key Vault secret
  }
  
  # WAF configuration for security
  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }
  
  zones = ["1", "2", "3"]  # Multi-zone deployment
  
  tags = local.common_tags
}

# Subnet for Application Gateway
resource "azurerm_subnet" "appgw" {
  name                 = "snet-appgw-${local.resource_suffix}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Virtual Machine - compliant with VM instance types and naming policies
resource "azurerm_linux_virtual_machine" "web" {
  name                = "lvm-web-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_D2s_v3"  # Approved size for production
  zone               = "1"                 # Availability zone for HA
  
  # Security configuration
  disable_password_authentication = true
  
  network_interface_ids = [
    azurerm_network_interface.web.id,
  ]
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"  # Premium storage for production
  }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  
  admin_username = "azureuser"
  
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")  # In real scenario, use proper key management
  }
  
  tags = merge(local.common_tags, {
    AutoShutdown = "disabled"  # Production VM should not auto-shutdown
    BackupPolicy = "Daily"     # Backup configuration indicator
  })
}

# Network Interface for VM
resource "azurerm_network_interface" "web" {
  name                = "nic-web-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
  }
  
  tags = local.common_tags
}

# App Service Plan - compliant with VM instance types policy
resource "azurerm_service_plan" "main" {
  name                = "asp-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  os_type  = "Linux"
  sku_name = "P1v3"  # Production-appropriate tier
  
  tags = local.common_tags
}

# App Service - compliant with naming and tagging policies
resource "azurerm_linux_web_app" "main" {
  name                = "app-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id
  
  site_config {
    always_on         = true
    minimum_tls_version = "1.2"
    
    application_stack {
      node_version = "18-lts"
    }
  }
  
  https_only = true  # Security requirement
  
  app_settings = {
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.main.instrumentation_key
  }
  
  tags = local.common_tags
}

# Application Insights for monitoring
resource "azurerm_application_insights" "main" {
  name                = "appi-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
  
  tags = local.common_tags
}

# Data source for current client configuration
data "azurerm_client_config" "current" {}

# Outputs
output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "application_gateway_public_ip" {
  value = azurerm_public_ip.appgw.ip_address
}

output "web_app_url" {
  value = "https://${azurerm_linux_web_app.main.default_hostname}"
}
