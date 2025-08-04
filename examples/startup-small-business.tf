# Startup/Small Business Platform Example
# Demonstrates cost-effective cloud infrastructure for startups and small businesses
# Shows App Service, SQL Database, Storage, CDN, and monitoring with minimal costs

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Generate random suffix for globally unique names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Local values for startup/small business configuration
locals {
  environment = "prod"
  project     = "StartupPlatform"
  company     = "ContosoStartup"
  
  # Common tags for all resources
  common_tags = {
    Environment     = local.environment
    Owner          = "founder@contosostartup.com"
    Project        = local.project
    CostCenter     = "Operations"
    Application    = "WebApplication"
    BusinessStage  = "startup"
    BudgetTier     = "minimal"
    ComplianceLevel = "basic"
    DataClassification = "public"
  }
  
  # Startup configuration optimized for minimal cost
  startup_config = {
    # App Service Plan - Free tier to start
    app_service_sku = "F1"  # Free tier (1GB RAM, 60 min/day)
    app_service_capacity = 1
    
    # SQL Database - Basic tier
    sql_sku = "Basic"
    sql_size = "2GB"  # Minimal storage
    
    # Storage account - Standard LRS
    storage_tier = "Standard"
    storage_replication = "LRS"  # Locally redundant (cheapest)
    
    # CDN - Standard Microsoft tier
    cdn_sku = "Standard_Microsoft"
    
    # Application Insights sampling
    sampling_percentage = 50  # Reduce telemetry costs
    
    # Backup retention
    backup_retention_days = 7  # Minimal backup retention
    
    # Monitoring retention
    log_retention_days = 30  # Cost-optimized log retention
  }
}

# ========================================
# RESOURCE GROUP
# ========================================

resource "azurerm_resource_group" "main" {
  name     = "rg-${lower(local.project)}-${local.environment}-001"
  location = "East US"  # Often the most cost-effective region
  
  tags = local.common_tags
}

# ========================================
# STORAGE ACCOUNT (MULTI-PURPOSE)
# ========================================

resource "azurerm_storage_account" "main" {
  name                = "sa${lower(replace(local.project, "-", ""))}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  account_tier             = local.startup_config.storage_tier
  account_replication_type = local.startup_config.storage_replication
  account_kind            = "StorageV2"
  
  # Cost-optimized settings
  access_tier                     = "Hot"  # For frequently accessed data
  https_traffic_only_enabled      = true
  min_tls_version                = "TLS1_2"
  allow_nested_items_to_be_public = true   # Allow public access for website assets
  
  # Lifecycle management for cost optimization
  blob_properties {
    versioning_enabled = false  # Disable versioning to save costs
    change_feed_enabled = false
    
    delete_retention_policy {
      days = local.startup_config.backup_retention_days
    }
    
    container_delete_retention_policy {
      days = local.startup_config.backup_retention_days
    }
  }
  
  # Enable static website hosting
  static_website {
    index_document     = "index.html"
    error_404_document = "404.html"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "MultiPurposeStorage"
    CostOptimized = "true"
  })
}

# Container for website assets
resource "azurerm_storage_container" "website_assets" {
  name                  = "assets"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "blob"  # Public read access for website assets
}

# Container for user uploads
resource "azurerm_storage_container" "uploads" {
  name                  = "uploads"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# Container for backups
resource "azurerm_storage_container" "backups" {
  name                  = "backups"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# ========================================
# SQL DATABASE (BASIC TIER)
# ========================================

# SQL Server
resource "azurerm_mssql_server" "main" {
  name                = "sql-${lower(local.project)}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  version             = "12.0"
  
  administrator_login          = "sqladmin"
  administrator_login_password = "P@ssw0rd123!"  # In production, use Key Vault
  
  # Cost-optimized security settings
  public_network_access_enabled = true  # Startups often need simple connectivity
  minimum_tls_version           = "1.2"
  
  tags = merge(local.common_tags, {
    Purpose = "ApplicationDatabase"
  })
}

# SQL Database - Basic tier for cost optimization
resource "azurerm_mssql_database" "main" {
  name           = "sqldb-${lower(local.project)}-${local.environment}-001"
  server_id      = azurerm_mssql_server.main.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  sku_name       = local.startup_config.sql_sku
  zone_redundant = false  # Not available in Basic tier
  
  short_term_retention_policy {
    retention_days = local.startup_config.backup_retention_days
  }
  
  tags = merge(local.common_tags, {
    Purpose = "ApplicationData"
    Tier = "Basic"
  })
}

# Firewall rule to allow Azure services
resource "azurerm_mssql_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# ========================================
# APP SERVICE PLAN (FREE TIER)
# ========================================

resource "azurerm_service_plan" "main" {
  name                = "plan-${lower(local.project)}-${local.environment}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name           = local.startup_config.app_service_sku
  
  tags = merge(local.common_tags, {
    Purpose = "WebHosting"
    Tier = "Free"
    CostOptimized = "true"
  })
}

# ========================================
# WEB APPLICATION
# ========================================

resource "azurerm_linux_web_app" "main" {
  name                = "app-${lower(local.project)}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id
  
  site_config {
    always_on = false  # Not available in Free tier
    
    application_stack {
      node_version = "18-lts"  # Popular choice for startups
    }
    
    # CORS for frontend applications
    cors {
      allowed_origins = [
        "https://${azurerm_storage_account.main.primary_web_endpoint}",
        "https://localhost:3000"  # For local development
      ]
      support_credentials = true
    }
    
    # Security headers
    http2_enabled = true
    ftps_state   = "Disabled"
  }
  
  # Application settings
  app_settings = {
    "WEBSITE_NODE_DEFAULT_VERSION" = "18-lts"
    "NODE_ENV"                    = "production"
    "DATABASE_URL"                = "Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.main.name};Persist Security Info=False;User ID=${azurerm_mssql_server.main.administrator_login};Password=${azurerm_mssql_server.main.administrator_login_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
    "STORAGE_CONNECTION_STRING"   = azurerm_storage_account.main.primary_connection_string
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.main.instrumentation_key
  }
  
  # Connection strings
  connection_string {
    name  = "DefaultConnection"
    type  = "SQLServer"
    value = "Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.main.name};Persist Security Info=False;User ID=${azurerm_mssql_server.main.administrator_login};Password=${azurerm_mssql_server.main.administrator_login_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  }
  
  # Basic authentication for admin access
  auth_settings {
    enabled = false  # Keep simple for startups initially
  }
  
  tags = merge(local.common_tags, {
    Purpose = "WebApplication"
    Framework = "NodeJS"
  })
}

# ========================================
# APPLICATION INSIGHTS (COST-OPTIMIZED)
# ========================================

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${lower(local.project)}-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = local.startup_config.log_retention_days
  
  tags = merge(local.common_tags, {
    Purpose = "CostOptimizedMonitoring"
  })
}

resource "azurerm_application_insights" "main" {
  name                = "appi-${lower(local.project)}-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  
  # Cost optimization settings
  retention_in_days = local.startup_config.log_retention_days
  sampling_percentage = local.startup_config.sampling_percentage
  
  tags = merge(local.common_tags, {
    Purpose = "ApplicationMonitoring"
    CostOptimized = "true"
  })
}

# ========================================
# CDN FOR GLOBAL PERFORMANCE
# ========================================

# CDN Profile
resource "azurerm_cdn_profile" "main" {
  name                = "cdn-${lower(local.project)}-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = local.startup_config.cdn_sku
  
  tags = merge(local.common_tags, {
    Purpose = "ContentDelivery"
    CostOptimized = "true"
  })
}

# CDN Endpoint for web app
resource "azurerm_cdn_endpoint" "webapp" {
  name                = "cdn-webapp-${random_string.suffix.result}"
  profile_name        = azurerm_cdn_profile.main.name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  origin_host_header = azurerm_linux_web_app.main.default_hostname
  
  origin {
    name      = "webapp"
    host_name = azurerm_linux_web_app.main.default_hostname
  }
  
  # Caching rules for cost optimization
  global_delivery_rule {
    cache_expiration_action {
      behavior = "Override"
      duration = "1.00:00:00"  # 1 day cache for static content
    }
    
    cache_key_query_string_action {
      behavior   = "IncludeAll"
      parameters = "v,version"  # Version-based cache busting
    }
  }
  
  tags = merge(local.common_tags, {
    Purpose = "WebAppCDN"
  })
}

# CDN Endpoint for static assets
resource "azurerm_cdn_endpoint" "assets" {
  name                = "cdn-assets-${random_string.suffix.result}"
  profile_name        = azurerm_cdn_profile.main.name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  origin_host_header = azurerm_storage_account.main.primary_blob_host
  
  origin {
    name      = "storage"
    host_name = azurerm_storage_account.main.primary_blob_host
  }
  
  # Longer caching for static assets
  global_delivery_rule {
    cache_expiration_action {
      behavior = "Override"
      duration = "7.00:00:00"  # 7 days cache for static assets
    }
  }
  
  tags = merge(local.common_tags, {
    Purpose = "StaticAssetsCDN"
  })
}

# ========================================
# BASIC MONITORING AND ALERTING
# ========================================

# Action group for alerts
resource "azurerm_monitor_action_group" "startup_alerts" {
  name                = "ag-startup-alerts-${local.environment}"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "startup"
  
  email_receiver {
    name          = "founder-email"
    email_address = "founder@contosostartup.com"
  }
  
  sms_receiver {
    name         = "founder-sms"
    country_code = "1"
    phone_number = "5551234567"
  }
  
  tags = local.common_tags
}

# Alert for web app downtime
resource "azurerm_monitor_metric_alert" "webapp_availability" {
  name                = "webapp-availability-alert"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_web_app.main.id]
  description         = "Alert when web app is not available"
  
  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5
  }
  
  window_size = "PT5M"
  frequency   = "PT1M"
  
  action {
    action_group_id = azurerm_monitor_action_group.startup_alerts.id
  }
  
  tags = local.common_tags
}

# Alert for database DTU usage (Basic tier specific)
resource "azurerm_monitor_metric_alert" "database_dtu" {
  name                = "database-dtu-alert"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_mssql_database.main.id]
  description         = "Alert when database DTU usage is high"
  
  criteria {
    metric_namespace = "Microsoft.Sql/servers/databases"
    metric_name      = "dtu_consumption_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }
  
  window_size = "PT15M"
  frequency   = "PT5M"
  
  action {
    action_group_id = azurerm_monitor_action_group.startup_alerts.id
  }
  
  tags = local.common_tags
}

# ========================================
# SECURITY BASICS
# ========================================

# Key Vault for storing secrets (Basic tier)
resource "azurerm_key_vault" "main" {
  name                = "kv-${lower(replace(local.project, "-", ""))}${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  
  # Cost-optimized settings
  enabled_for_disk_encryption     = false  # Not needed for startup
  enabled_for_deployment          = false
  enabled_for_template_deployment = false
  purge_protection_enabled        = false  # Allow deletion for cost control
  soft_delete_retention_days      = 7      # Minimum retention
  
  # Basic access policy for application
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    
    key_permissions = ["Get", "List"]
    secret_permissions = ["Get", "List", "Set", "Delete"]
  }
  
  tags = merge(local.common_tags, {
    Purpose = "SecretsManagement"
    Tier = "Basic"
  })
}

# Store database connection string in Key Vault
resource "azurerm_key_vault_secret" "database_connection" {
  name         = "database-connection-string"
  value        = "Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.main.name};Persist Security Info=False;User ID=${azurerm_mssql_server.main.administrator_login};Password=${azurerm_mssql_server.main.administrator_login_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.main.id
  
  tags = local.common_tags
}

# Current client configuration
data "azurerm_client_config" "current" {}

# ========================================
# OUTPUTS
# ========================================

output "startup_platform_summary" {
  description = "Startup Platform Configuration Summary"
  value = {
    # Web application
    web_app_url = "https://${azurerm_linux_web_app.main.default_hostname}"
    cdn_web_url = "https://${azurerm_cdn_endpoint.webapp.fqdn}"
    
    # Static website
    static_website_url = azurerm_storage_account.main.primary_web_endpoint
    cdn_assets_url = "https://${azurerm_cdn_endpoint.assets.fqdn}"
    
    # Database
    sql_server = azurerm_mssql_server.main.fully_qualified_domain_name
    database_name = azurerm_mssql_database.main.name
    
    # Storage
    storage_account = azurerm_storage_account.main.name
    
    # Monitoring
    application_insights = azurerm_application_insights.main.name
    
    # Security
    key_vault = azurerm_key_vault.main.name
  }
}

output "cost_optimization_features" {
  description = "Startup cost optimization features enabled"
  value = [
    "App Service Free tier (F1) - No cost for basic hosting",
    "SQL Database Basic tier - Minimal cost for small databases",
    "Standard LRS storage - Lowest cost storage option",
    "Standard Microsoft CDN - Cost-effective content delivery",
    "50% Application Insights sampling - Reduced telemetry costs",
    "30-day log retention vs 365-day default",
    "7-day backup retention vs 35-day default",
    "Basic Key Vault without HSM",
    "Single region deployment",
    "No redundancy where not critical"
  ]
}

output "startup_recommendations" {
  description = "Recommendations for startups using this infrastructure"
  value = [
    "Monitor costs daily using Azure Cost Management",
    "Set up budget alerts to avoid surprise charges",
    "Use Azure credits and startup programs when available",
    "Scale up services only when user growth demands it",
    "Consider upgrading to Standard App Service when traffic increases",
    "Implement proper monitoring to understand usage patterns",
    "Use staging slots when upgrading from Free to Standard",
    "Regular backups are essential - test restore procedures",
    "Consider Azure Container Instances for microservices later",
    "Leverage free Azure DevOps for CI/CD pipelines"
  ]
}

output "scaling_path" {
  description = "Suggested scaling path as startup grows"
  value = {
    "Phase 1 (MVP)" = "Current setup - Free/Basic tiers"
    "Phase 2 (Growth)" = "Upgrade App Service to Basic B1, add custom domain"
    "Phase 3 (Scale)" = "Standard App Service, General Purpose SQL, add Redis"
    "Phase 4 (Enterprise)" = "Premium services, multiple regions, advanced security"
    
    upgrade_triggers = [
      "App Service: When exceeding 60 min/day or need custom domains",
      "SQL Database: When storage exceeds 2GB or need better performance",
      "Storage: When needing geo-redundancy or advanced features",
      "Monitoring: When needing advanced analytics or longer retention"
    ]
  }
}

output "estimated_monthly_cost" {
  description = "Estimated monthly costs for this configuration (USD, as of 2024)"
  value = {
    "App Service F1" = "Free"
    "SQL Database Basic" = "$4.99/month"
    "Storage Account (100GB)" = "$2.40/month"
    "CDN (1GB transfer)" = "$0.087/month"
    "Application Insights (1GB)" = "$2.30/month"
    "Key Vault" = "$0.03/month (first 10,000 operations free)"
    "Log Analytics (5GB)" = "$11.50/month"
    "Total (approximate)" = "$21.31/month"
    
    note = "Costs vary by region and usage. Monitor actual usage in Azure Cost Management."
  }
}
