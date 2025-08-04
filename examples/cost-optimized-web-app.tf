# Cost-Optimized Web Application Example
# This example demonstrates cost-effective Azure App Service deployment
# that complies with cost control policies while maintaining functionality

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
  features {}
}

# Local values for cost optimization
locals {
  environment = "dev"
  project     = "WebApp"
  
  # Cost-optimized tags that satisfy mandatory tagging policy
  cost_tags = {
    Environment  = local.environment
    Owner       = "dev-team@contoso.com"
    Project     = local.project
    CostCenter  = "Development"
    Application = "WebPortal"
    
    # Cost tracking tags
    BudgetCode     = "DEV-2025-001"
    CostOptimized  = "true"
    AutoShutdown   = "enabled"
    ReviewDate     = "2025-09-01"
  }
}

# Resource Group with cost tracking
resource "azurerm_resource_group" "web_app" {
  name     = "rg-webapp-cost-optimized-dev-001"
  location = "East US"  # Cost-effective region
  
  tags = merge(local.cost_tags, {
    Purpose = "CostOptimizedWebApp"
  })
}

# Cost-optimized App Service Plan - Basic tier
resource "azurerm_service_plan" "web_app" {
  name                = "asp-webapp-basic-dev-001"
  resource_group_name = azurerm_resource_group.web_app.name
  location            = azurerm_resource_group.web_app.location
  
  # Basic tier for cost optimization - complies with cost control policy
  os_type  = "Linux"  # Linux is more cost-effective than Windows
  sku_name = "B1"     # Basic tier - lowest cost option
  
  tags = merge(local.cost_tags, {
    Tier    = "Basic"
    Purpose = "CostOptimized"
  })
}

# Web App with cost-conscious configuration
resource "azurerm_linux_web_app" "main" {
  name                = "app-webapp-cost-dev-001"
  resource_group_name = azurerm_resource_group.web_app.name
  location            = azurerm_resource_group.web_app.location
  service_plan_id     = azurerm_service_plan.web_app.id
  
  # Cost optimization settings
  https_only = true  # Security requirement, no cost impact
  
  site_config {
    # Minimal configuration for cost savings
    always_on        = false  # Save costs by allowing app to sleep
    use_32_bit_worker = true  # Use less memory
    
    # Application stack - lightweight option
    application_stack {
      node_version = "18-lts"  # LTS version for stability
    }
    
    # Health check path
    health_check_path = "/health"
  }
  
  # App settings optimized for cost
  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
    "NODE_ENV"                 = "development"
    
    # Performance settings for cost optimization
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
    "WEBSITE_TIME_ZONE"           = "Eastern Standard Time"
    
    # Disable expensive features in development
    "APPINSIGHTS_INSTRUMENTATIONKEY" = ""  # Disable in dev to save costs
  }
  
  # Identity for Key Vault access (no additional cost)
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.cost_tags, {
    AppType = "WebApplication"
  })
}

# Cost-effective Storage Account - Standard LRS
resource "azurerm_storage_account" "web_app_storage" {
  name                = "stwebappcostdev001"
  resource_group_name = azurerm_resource_group.web_app.name
  location            = azurerm_resource_group.web_app.location
  
  # Cost-optimized settings
  account_tier             = "Standard"  # Standard vs Premium
  account_replication_type = "LRS"       # Locally redundant (cheapest)
  account_kind            = "StorageV2"
  
  # Security settings (required by encryption policy)
  https_traffic_only_enabled = true
  min_tls_version            = "TLS1_2"
  
  # Cost optimization settings
  access_tier = "Cool"  # Cool tier for infrequent access
  
  # Blob properties for cost control
  blob_properties {
    versioning_enabled = false  # Disable versioning to save storage costs
    
    # Lifecycle management for cost control
    delete_retention_policy {
      days = 7  # Short retention for development
    }
  }
  
  tags = merge(local.cost_tags, {
    StorageType = "Development"
    AccessTier  = "Cool"
  })
}

# Cost-effective Key Vault - Standard tier
resource "azurerm_key_vault" "web_app" {
  name                = "kv-webapp-cost-dev-001"
  location            = azurerm_resource_group.web_app.location
  resource_group_name = azurerm_resource_group.web_app.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  
  # Standard tier for cost optimization (vs Premium with HSM)
  sku_name = "standard"
  
  # Cost-conscious settings
  soft_delete_retention_days = 7   # Minimum retention period
  purge_protection_enabled   = false  # Disable for dev to avoid storage costs
  
  # Access policy for the web app
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_linux_web_app.main.identity[0].principal_id
    
    secret_permissions = [
      "Get",
      "List"
    ]
  }
  
  tags = merge(local.cost_tags, {
    Tier    = "Standard"
    Purpose = "ApplicationSecrets"
  })
}

# Application Insights - Basic tier for cost control
resource "azurerm_application_insights" "web_app" {
  name                = "appi-webapp-cost-dev-001"
  location            = azurerm_resource_group.web_app.location
  resource_group_name = azurerm_resource_group.web_app.name
  workspace_id        = azurerm_log_analytics_workspace.web_app.id
  application_type    = "Node.JS"
  
  # Cost control settings
  retention_in_days = 30  # Minimum retention to control costs
  
  tags = merge(local.cost_tags, {
    MonitoringType = "Basic"
  })
}

# Log Analytics Workspace - Pay-per-GB model
resource "azurerm_log_analytics_workspace" "web_app" {
  name                = "law-webapp-cost-dev-001"
  location            = azurerm_resource_group.web_app.location
  resource_group_name = azurerm_resource_group.web_app.name
  
  # Cost-effective settings
  sku               = "PerGB2018"  # Pay per GB ingested
  retention_in_days = 30           # Minimum retention
  
  tags = merge(local.cost_tags, {
    LoggingTier = "Basic"
  })
}

# Cost monitoring with budgets
resource "azurerm_consumption_budget_resource_group" "web_app" {
  name              = "budget-webapp-dev-monthly"
  resource_group_id = azurerm_resource_group.web_app.id
  
  amount     = 100  # $100 monthly budget for dev environment
  time_grain = "Monthly"
  
  time_period {
    start_date = "2025-08-01T00:00:00Z"
    end_date   = "2026-07-31T23:59:59Z"
  }
  
  # Alert at 80% and 90% of budget
  notification {
    enabled   = true
    threshold = 80.0
    operator  = "GreaterThan"
    
    contact_emails = [
      "dev-team@contoso.com",
      "finance@contoso.com"
    ]
  }
  
  notification {
    enabled   = true
    threshold = 90.0
    operator  = "GreaterThan"
    
    contact_emails = [
      "dev-team@contoso.com",
      "finance@contoso.com",
      "management@contoso.com"
    ]
  }
}

# Auto-shutdown schedule for cost savings (requires Automation Account)
resource "azurerm_automation_account" "cost_control" {
  name                = "aa-cost-control-dev-001"
  location            = azurerm_resource_group.web_app.location
  resource_group_name = azurerm_resource_group.web_app.name
  sku_name           = "Basic"  # Basic tier for cost optimization
  
  tags = merge(local.cost_tags, {
    Purpose = "CostAutomation"
  })
}

# Runbook for auto-shutdown
resource "azurerm_automation_runbook" "shutdown_webapp" {
  name                    = "Shutdown-WebApp-Nightly"
  location                = azurerm_resource_group.web_app.location
  resource_group_name     = azurerm_resource_group.web_app.name
  automation_account_name = azurerm_automation_account.cost_control.name
  log_verbose             = false
  log_progress            = false
  runbook_type            = "PowerShell"
  
  content = <<-EOT
    # Auto-shutdown script for cost savings
    param(
        [string]$ResourceGroupName = "${azurerm_resource_group.web_app.name}",
        [string]$WebAppName = "${azurerm_linux_web_app.main.name}"
    )
    
    # Connect using Managed Identity
    Connect-AzAccount -Identity
    
    # Stop the web app to save costs during non-business hours
    Write-Output "Stopping web app $WebAppName in resource group $ResourceGroupName"
    Stop-AzWebApp -ResourceGroupName $ResourceGroupName -Name $WebAppName
    Write-Output "Web app stopped successfully"
  EOT
  
  tags = local.cost_tags
}

# Schedule for auto-shutdown (9 PM EST)
resource "azurerm_automation_schedule" "nightly_shutdown" {
  name                    = "nightly-shutdown-9pm"
  resource_group_name     = azurerm_resource_group.web_app.name
  automation_account_name = azurerm_automation_account.cost_control.name
  frequency               = "Day"
  interval                = 1
  start_time              = "2025-08-05T21:00:00-05:00"  # 9 PM EST
  description             = "Nightly shutdown for cost savings"
}

# Link schedule to runbook
resource "azurerm_automation_job_schedule" "shutdown_schedule" {
  resource_group_name     = azurerm_resource_group.web_app.name
  automation_account_name = azurerm_automation_account.cost_control.name
  schedule_name           = azurerm_automation_schedule.nightly_shutdown.name
  runbook_name           = azurerm_automation_runbook.shutdown_webapp.name
}

# Data sources
data "azurerm_client_config" "current" {}

# Variables for cost control
variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 100
}

variable "auto_shutdown_enabled" {
  description = "Enable auto-shutdown for cost savings"
  type        = bool
  default     = true
}

# Outputs focused on cost information
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = {
    app_service_plan = "~$13/month (B1 Basic)"
    web_app         = "Included with App Service Plan"
    storage_account = "~$2/month (Standard LRS, Cool)"
    key_vault       = "~$0.03/month (Standard tier)"
    application_insights = "~$2.30/GB (first 5GB free)"
    log_analytics   = "~$2.30/GB ingested"
    automation      = "~$0.002/minute execution"
    total_estimated = "~$20-25/month (excluding data ingress/egress)"
  }
}

output "cost_optimization_features" {
  description = "Enabled cost optimization features"
  value = {
    "basic_app_service_plan"     = "Lowest cost tier selected"
    "linux_os"                  = "More cost-effective than Windows"
    "always_on_disabled"        = "App can sleep to save compute costs"
    "cool_storage_tier"         = "Lower storage costs for infrequent access"
    "short_retention_periods"   = "Reduced storage costs"
    "standard_key_vault"        = "No HSM premium costs"
    "automated_shutdown"        = "Scheduled shutdown during off-hours"
    "budget_alerts"            = "Proactive cost monitoring"
    "pay_per_gb_logging"       = "Only pay for actual log data"
  }
}

output "cost_monitoring" {
  description = "Cost monitoring and budgets"
  value = {
    budget_name      = azurerm_consumption_budget_resource_group.web_app.name
    monthly_limit    = "$${var.monthly_budget_limit}"
    alert_thresholds = "80% and 90%"
    auto_shutdown    = var.auto_shutdown_enabled ? "Enabled at 9 PM EST" : "Disabled"
  }
}
