# Serverless Application Platform Example
# Demonstrates cost-effective serverless architecture with comprehensive governance
# Shows Azure Functions, Logic Apps, Cosmos DB serverless, API Management, and event-driven patterns

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

# Local values for serverless platform configuration
locals {
  environment = "prod"
  project     = "ServerlessPlatform"
  
  # Common tags for all resources
  common_tags = {
    Environment     = local.environment
    Owner          = "serverless-team@contoso.com"
    Project        = local.project
    CostCenter     = "Engineering"
    Application    = "ServerlessAPI"
    Architecture   = "event-driven"
    BackupPolicy   = "minimal"
    ComplianceLevel = "standard"
    DataClassification = "internal"
  }
  
  # Serverless configuration optimized for cost
  serverless_config = {
    # Functions configuration
    functions_plan = "Y1"  # Consumption plan for maximum cost efficiency
    functions_runtime = "dotnet-isolated"
    functions_version = "~4"
    
    # Cosmos DB serverless configuration
    cosmosdb_consistency = "Session"  # Cost-effective consistency level
    cosmosdb_max_throughput = 4000    # Max RU/s for serverless
    
    # API Management consumption tier
    apim_sku = "Consumption"  # Pay-per-use pricing
    
    # Event-driven configuration
    event_retention_hours = 24  # Minimal retention for cost optimization
  }
}

# ========================================
# RESOURCE GROUP
# ========================================

resource "azurerm_resource_group" "main" {
  name     = "rg-${lower(local.project)}-${local.environment}-001"
  location = "East US"
  
  tags = local.common_tags
}

# ========================================
# STORAGE ACCOUNT FOR FUNCTIONS
# ========================================

resource "azurerm_storage_account" "functions" {
  name                = "safunc${lower(replace(local.project, "-", ""))}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  account_tier             = "Standard"
  account_replication_type = "LRS"  # Cost-effective for functions
  account_kind            = "StorageV2"
  
  # Security configurations
  https_traffic_only_enabled      = true
  min_tls_version                = "TLS1_2"
  allow_nested_items_to_be_public = false
  
  # Lifecycle management for cost optimization
  blob_properties {
    delete_retention_policy {
      days = 7  # Minimal retention for functions
    }
    
    versioning_enabled = false  # Not needed for functions storage
  }
  
  tags = merge(local.common_tags, {
    Purpose = "FunctionsStorage"
  })
}

# ========================================
# APPLICATION INSIGHTS
# ========================================

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${lower(local.project)}-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30  # Cost-optimized retention
  
  tags = merge(local.common_tags, {
    Purpose = "ServerlessMonitoring"
  })
}

resource "azurerm_application_insights" "main" {
  name                = "appi-${lower(local.project)}-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  
  # Cost optimization settings
  retention_in_days = 30
  sampling_percentage = 100
  
  tags = merge(local.common_tags, {
    Purpose = "ApplicationMonitoring"
  })
}

# ========================================
# AZURE FUNCTIONS (CONSUMPTION PLAN)
# ========================================

# Consumption plan for maximum cost efficiency
resource "azurerm_service_plan" "consumption" {
  name                = "plan-${lower(local.project)}-consumption-${local.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name           = local.serverless_config.functions_plan
  
  tags = merge(local.common_tags, {
    Purpose = "ServerlessCompute"
    PricingModel = "PayPerExecution"
  })
}

# Function App for API endpoints
resource "azurerm_linux_function_app" "api" {
  name                = "func-${lower(local.project)}-api-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  storage_account_name       = azurerm_storage_account.functions.name
  storage_account_access_key = azurerm_storage_account.functions.primary_access_key
  service_plan_id           = azurerm_service_plan.consumption.id
  
  # Runtime configuration
  site_config {
    application_stack {
      dotnet_version              = "8.0"
      use_dotnet_isolated_runtime = true
    }
    
    # CORS configuration for web applications
    cors {
      allowed_origins = ["https://contoso.com", "https://www.contoso.com"]
    }
    
    # Security headers
    http2_enabled = true
    ftps_state   = "Disabled"
    
    # Performance optimization
    pre_warmed_instance_count = 1
    elastic_instance_minimum  = 0
    
    application_insights_key               = azurerm_application_insights.main.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.main.connection_string
  }
  
  # App settings for configuration
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"     = local.serverless_config.functions_runtime
    "FUNCTIONS_EXTENSION_VERSION"  = local.serverless_config.functions_version
    "WEBSITE_RUN_FROM_PACKAGE"    = "1"
    "CosmosDB_ConnectionString"   = azurerm_cosmosdb_account.main.connection_strings[0]
    "EventHub_ConnectionString"   = azurerm_eventhub_authorization_rule.functions.primary_connection_string
  }
  
  # Managed identity for secure access
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "ServerlessAPI"
    Runtime = "DotNet8"
  })
}

# Function App for background processing
resource "azurerm_linux_function_app" "processor" {
  name                = "func-${lower(local.project)}-proc-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  storage_account_name       = azurerm_storage_account.functions.name
  storage_account_access_key = azurerm_storage_account.functions.primary_access_key
  service_plan_id           = azurerm_service_plan.consumption.id
  
  site_config {
    application_stack {
      dotnet_version              = "8.0"
      use_dotnet_isolated_runtime = true
    }
    
    # Background processing optimizations
    always_on = false  # Not available in consumption plan
    elastic_instance_minimum = 0
    
    application_insights_key               = azurerm_application_insights.main.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.main.connection_string
  }
  
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"     = local.serverless_config.functions_runtime
    "FUNCTIONS_EXTENSION_VERSION"  = local.serverless_config.functions_version
    "CosmosDB_ConnectionString"   = azurerm_cosmosdb_account.main.connection_strings[0]
    "ServiceBus_ConnectionString" = azurerm_servicebus_namespace.main.default_primary_connection_string
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "BackgroundProcessing"
    Runtime = "DotNet8"
  })
}

# ========================================
# COSMOS DB SERVERLESS
# ========================================

resource "azurerm_cosmosdb_account" "main" {
  name                = "cosmos-${lower(local.project)}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  
  # Serverless capacity mode for cost optimization
  capabilities {
    name = "EnableServerless"
  }
  
  consistency_policy {
    consistency_level = local.serverless_config.cosmosdb_consistency
  }
  
  geo_location {
    location          = azurerm_resource_group.main.location
    failover_priority = 0
  }
  
  # Security configurations
  public_network_access_enabled = false
  is_virtual_network_filter_enabled = true
  
  virtual_network_rule {
    id                                   = azurerm_subnet.functions.id
    ignore_missing_vnet_service_endpoint = false
  }
  
  # Backup policy for serverless
  backup {
    type                = "Periodic"
    interval_in_minutes = 240  # 4 hours
    retention_in_hours  = 720  # 30 days (cost-optimized)
    storage_redundancy  = "Local"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "ServerlessDatabase"
    CapacityMode = "Serverless"
  })
}

# Cosmos DB SQL Database
resource "azurerm_cosmosdb_sql_database" "main" {
  name                = "ServerlessAppDB"
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
  
  # Serverless - no throughput configuration needed
}

# Cosmos DB Container for application data
resource "azurerm_cosmosdb_sql_container" "app_data" {
  name                  = "AppData"
  resource_group_name   = azurerm_resource_group.main.name
  account_name          = azurerm_cosmosdb_account.main.name
  database_name         = azurerm_cosmosdb_sql_database.main.name
  partition_key_path    = "/tenantId"
  partition_key_version = 1
  
  # Indexing policy for performance
  indexing_policy {
    indexing_mode = "consistent"
    
    included_path {
      path = "/*"
    }
    
    excluded_path {
      path = "/\"_etag\"/?"
    }
  }
  
  # Unique key for data integrity
  unique_key {
    paths = ["/email"]
  }
}

# ========================================
# NETWORKING FOR SERVERLESS
# ========================================

# Virtual Network for private endpoints
resource "azurerm_virtual_network" "serverless" {
  name                = "vnet-${lower(local.project)}-${local.environment}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]
  
  tags = local.common_tags
}

# Subnet for Functions VNet integration
resource "azurerm_subnet" "functions" {
  name                 = "snet-functions-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.serverless.name
  address_prefixes     = ["10.0.1.0/24"]
  
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.AzureCosmosDB",
    "Microsoft.ServiceBus",
    "Microsoft.EventHub"
  ]
  
  delegation {
    name = "serverlessFunction"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
    }
  }
}

# VNet integration for Functions
resource "azurerm_app_service_virtual_network_swift_connection" "api" {
  app_service_id = azurerm_linux_function_app.api.id
  subnet_id      = azurerm_subnet.functions.id
}

resource "azurerm_app_service_virtual_network_swift_connection" "processor" {
  app_service_id = azurerm_linux_function_app.processor.id
  subnet_id      = azurerm_subnet.functions.id
}

# ========================================
# EVENT HUB FOR EVENT-DRIVEN ARCHITECTURE
# ========================================

resource "azurerm_eventhub_namespace" "main" {
  name                = "evhns-${lower(local.project)}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Basic"  # Cost-effective for serverless
  capacity            = 1
  
  # Network isolation
  public_network_access_enabled = false
  
  network_rulesets {
    default_action = "Deny"
    
    virtual_network_rule {
      subnet_id = azurerm_subnet.functions.id
    }
  }
  
  tags = merge(local.common_tags, {
    Purpose = "EventStreaming"
  })
}

# Event Hub for application events
resource "azurerm_eventhub" "app_events" {
  name                = "app-events"
  namespace_name      = azurerm_eventhub_namespace.main.name
  resource_group_name = azurerm_resource_group.main.name
  partition_count     = 2  # Cost-optimized partition count
  message_retention   = 1  # Minimum retention for cost savings
}

# Authorization rule for Functions
resource "azurerm_eventhub_authorization_rule" "functions" {
  name                = "functions-access"
  namespace_name      = azurerm_eventhub_namespace.main.name
  eventhub_name       = azurerm_eventhub.app_events.name
  resource_group_name = azurerm_resource_group.main.name
  
  listen = true
  send   = true
  manage = false
}

# ========================================
# SERVICE BUS FOR RELIABLE MESSAGING
# ========================================

resource "azurerm_servicebus_namespace" "main" {
  name                = "sb-${lower(local.project)}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Basic"  # Cost-effective for simple messaging
  
  # Network isolation
  public_network_access_enabled = false
  
  network_rule_set {
    default_action = "Deny"
    
    network_rules {
      subnet_id = azurerm_subnet.functions.id
    }
  }
  
  tags = merge(local.common_tags, {
    Purpose = "ReliableMessaging"
  })
}

# Service Bus Queue for order processing
resource "azurerm_servicebus_queue" "orders" {
  name         = "orders"
  namespace_id = azurerm_servicebus_namespace.main.id
  
  # Cost-optimized settings
  enable_partitioning = false
  max_size_in_megabytes = 1024  # 1GB - smallest size
  
  # Message settings
  default_message_ttl = "P1D"  # 1 day TTL
  max_delivery_count = 10
  
  # Duplicate detection
  requires_duplicate_detection = true
  duplicate_detection_history_time_window = "PT10M"
}

# ========================================
# LOGIC APPS FOR WORKFLOW AUTOMATION
# ========================================

resource "azurerm_logic_app_workflow" "order_processor" {
  name                = "logic-order-processor-${local.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  # Workflow definition (simplified for example)
  workflow_parameters = {
    "$connections" = {
      defaultValue = {}
      type        = "Object"  
    }
  }
  
  tags = merge(local.common_tags, {
    Purpose = "OrderProcessingWorkflow"
  })
}

# ========================================
# API MANAGEMENT (CONSUMPTION TIER)
# ========================================

resource "azurerm_api_management" "main" {
  name                = "apim-${lower(local.project)}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  publisher_name      = "Contoso"
  publisher_email     = "admin@contoso.com"
  
  # Consumption tier for pay-per-use pricing
  sku_name = local.serverless_config.apim_sku
  
  # Identity for managed access
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "APIGateway"
    PricingModel = "PayPerCall"
  })
}

# API for Functions
resource "azurerm_api_management_api" "functions_api" {
  name                = "functions-api"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  revision            = "1"
  display_name        = "Serverless Functions API"
  path                = "api"
  protocols           = ["https"]
  service_url         = "https://${azurerm_linux_function_app.api.default_hostname}/api"
  
  import {
    content_format = "openapi+json"
    content_value  = jsonencode({
      openapi = "3.0.0"
      info = {
        title   = "Serverless API"
        version = "1.0.0"
      }
      paths = {
        "/health" = {
          get = {
            summary = "Health check endpoint"
            responses = {
              "200" = {
                description = "Healthy"
              }
            }
          }
        }
      }
    })
  }
}

# ========================================
# RBAC AND PERMISSIONS
# ========================================

# Cosmos DB access for API Functions
resource "azurerm_cosmosdb_sql_role_assignment" "api_functions" {
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
  role_definition_id  = "${azurerm_cosmosdb_account.main.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"  # Cosmos DB Built-in Data Contributor
  principal_id        = azurerm_linux_function_app.api.identity[0].principal_id
  scope              = azurerm_cosmosdb_account.main.id
}

# Cosmos DB access for Processor Functions
resource "azurerm_cosmosdb_sql_role_assignment" "processor_functions" {
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
  role_definition_id  = "${azurerm_cosmosdb_account.main.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azurerm_linux_function_app.processor.identity[0].principal_id
  scope              = azurerm_cosmosdb_account.main.id
}

# ========================================
# OUTPUTS
# ========================================

output "serverless_platform_summary" {
  description = "Serverless Platform Configuration Summary"
  value = {
    # Core serverless services
    api_function_app = azurerm_linux_function_app.api.name
    processor_function_app = azurerm_linux_function_app.processor.name
    api_management = azurerm_api_management.main.name
    
    # Data and messaging
    cosmosdb_account = azurerm_cosmosdb_account.main.name
    event_hub_namespace = azurerm_eventhub_namespace.main.name
    service_bus_namespace = azurerm_servicebus_namespace.main.name
    
    # Workflow automation
    logic_app = azurerm_logic_app_workflow.order_processor.name
    
    # Monitoring
    application_insights = azurerm_application_insights.main.name
    log_analytics_workspace = azurerm_log_analytics_workspace.main.name
    
    # API endpoints
    api_gateway_url = "https://${azurerm_api_management.main.gateway_url}"
    function_api_url = "https://${azurerm_linux_function_app.api.default_hostname}"
  }
}

output "cost_optimization_features" {
  description = "Serverless cost optimization features enabled"
  value = [
    "Consumption plan for Functions (pay-per-execution)",
    "Cosmos DB serverless (pay-per-RU consumed)",
    "API Management consumption tier (pay-per-call)",
    "Basic Event Hub tier for cost efficiency",
    "Basic Service Bus tier for simple messaging",
    "LRS storage replication (cost-effective)",
    "30-day log retention vs 365-day default",
    "Minimal backup retention (30 days)",
    "1-day Event Hub message retention",
    "Auto-scaling with zero minimum instances"
  ]
}

output "serverless_architecture_benefits" {
  description = "Serverless architecture benefits"
  value = [
    "Zero infrastructure management overhead",
    "Automatic scaling from zero to peak demand",
    "Pay-only-for-what-you-use pricing model",
    "Built-in high availability and disaster recovery",
    "Event-driven architecture for loose coupling",
    "Managed identity for secure service access",
    "Native integration with Azure services",
    "Comprehensive monitoring and observability",
    "Network isolation with VNet integration",
    "Enterprise-grade security and compliance"
  ]
}
