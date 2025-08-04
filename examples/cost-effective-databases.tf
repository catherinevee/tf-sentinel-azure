# Cost-Effective Database Solution Example
# Demonstrates cost-optimized database deployments with various Azure database services
# Shows how to balance cost, performance, and compliance requirements

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

# Local values for cost-effective database deployment
locals {
  environment = "dev"
  project     = "DataPlatform"
  
  # Cost-focused tagging strategy
  cost_tags = {
    Environment = local.environment
    Owner      = "data-team@contoso.com"
    Project    = local.project
    CostCenter = "DataEngineering"
    Application = "DatabasePlatform"
    
    # Cost optimization tracking
    CostOptimization = "database-rightsizing"
    BudgetCategory  = "development-data"
    ReviewCycle    = "monthly"
    AutoPause      = "enabled"
  }
}

# Resource Group for database resources
resource "azurerm_resource_group" "database" {
  name     = "rg-database-cost-optimized-dev-001"
  location = "East US"  # Cost-effective region
  
  tags = merge(local.cost_tags, {
    Purpose = "CostOptimizedDatabases"
  })
}

# ========================================
# SQL DATABASE - SERVERLESS MODEL
# ========================================

# SQL Server with cost-optimized configuration
resource "azurerm_mssql_server" "cost_optimized" {
  name                = "sql-cost-optimized-dev-001"
  resource_group_name = azurerm_resource_group.database.name
  location            = azurerm_resource_group.database.location
  version             = "12.0"
  
  # Authentication
  administrator_login          = "sqladmin"
  administrator_login_password = random_password.sql_admin.result
  
  # Security settings (required by policies)
  public_network_access_enabled = false  # Force private connectivity
  
  tags = merge(local.cost_tags, {
    DatabaseType = "SQLServer"
    Tier        = "Serverless"
  })
}

# Cost-optimized SQL Database - Serverless model
resource "azurerm_mssql_database" "serverless" {
  name      = "sqldb-serverless-cost-dev-001"
  server_id = azurerm_mssql_server.cost_optimized.id
  
  # Serverless compute tier for maximum cost efficiency
  sku_name = "GP_S_Gen5_1"  # General Purpose Serverless, 1 vCore
  
  # Auto-pause configuration for cost savings
  auto_pause_delay_in_minutes = 60  # Pause after 1 hour of inactivity
  min_capacity               = 0.5  # Minimum vCores when active
  
  # Storage optimization
  max_size_gb = 32  # Small database size for development
  
  # Cost-effective backup settings
  short_term_retention_policy {
    retention_days = 7  # Minimum retention for development
  }
  
  long_term_retention_policy {
    weekly_retention  = "PT0S"  # Disabled for cost savings
    monthly_retention = "PT0S"  # Disabled for cost savings
    yearly_retention  = "PT0S"  # Disabled for cost savings
    week_of_year     = 1
  }
  
  tags = merge(local.cost_tags, {
    ComputeModel = "Serverless"
    AutoPause   = "60minutes"
  })
}

# ========================================
# MYSQL FLEXIBLE SERVER - BURSTABLE TIER
# ========================================

# MySQL Flexible Server - Burstable tier for cost optimization
resource "azurerm_mysql_flexible_server" "cost_optimized" {
  name                = "mysql-cost-optimized-dev-001"
  resource_group_name = azurerm_resource_group.database.name
  location            = azurerm_resource_group.database.location
  
  # Cost-optimized tier and size
  sku_name = "B_Standard_B1s"  # Burstable tier, lowest cost option
  version  = "8.0.21"
  
  # Storage configuration for cost efficiency
  storage {
    size_gb = 20  # Minimum storage size
    iops   = 360  # Baseline IOPS for burstable
  }
  
  # Authentication
  administrator_login    = "mysqladmin"
  administrator_password = random_password.mysql_admin.result
  
  # Backup settings optimized for cost
  backup_retention_days        = 7   # Minimum retention
  geo_redundant_backup_enabled = false  # Disable geo-redundancy for cost savings
  
  # High availability disabled for development cost savings
  high_availability {
    mode = "Disabled"
  }
  
  tags = merge(local.cost_tags, {
    DatabaseType = "MySQL"
    Tier        = "Burstable"
  })
}

# ========================================
# POSTGRESQL FLEXIBLE SERVER - COST OPTIMIZED
# ========================================

# PostgreSQL Flexible Server with cost optimizations
resource "azurerm_postgresql_flexible_server" "cost_optimized" {
  name                = "psql-cost-optimized-dev-001"
  resource_group_name = azurerm_resource_group.database.name
  location            = azurerm_resource_group.database.location
  
  # Burstable tier for cost optimization
  sku_name = "B_Standard_B1ms"  # Burstable, minimal cost
  version  = "14"
  
  # Storage settings
  storage_mb = 32768  # 32 GB minimum
  
  # Authentication
  administrator_login    = "psqladmin"
  administrator_password = random_password.postgresql_admin.result
  
  # Backup optimization
  backup_retention_days        = 7      # Minimum retention
  geo_redundant_backup_enabled = false  # Cost savings
  
  tags = merge(local.cost_tags, {
    DatabaseType = "PostgreSQL"
    Tier        = "Burstable"
  })
}

# ========================================
# COSMOS DB - SERVERLESS MODE
# ========================================

# Cosmos DB Account - Serverless for cost optimization
resource "azurerm_cosmosdb_account" "cost_optimized" {
  name                = "cosmos-cost-optimized-dev-001"
  location            = azurerm_resource_group.database.location
  resource_group_name = azurerm_resource_group.database.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  
  # Cost optimization settings
  
  # Single region for cost control
  geo_location {
    location          = azurerm_resource_group.database.location
    failover_priority = 0
  }
  
  # Consistency level optimization
  consistency_policy {
    consistency_level = "Session"  # Good balance of performance and cost
  }
  
  # Capabilities for cost optimization
  capabilities {
    name = "EnableServerless"  # Serverless mode for pay-per-use
  }
  
  tags = merge(local.cost_tags, {
    DatabaseType = "CosmosDB"
    Mode        = "Serverless"
  })
}

# Cosmos DB SQL Database
resource "azurerm_cosmosdb_sql_database" "cost_optimized" {
  name                = "cosmosdb-dev-database"
  resource_group_name = azurerm_cosmosdb_account.cost_optimized.resource_group_name
  account_name        = azurerm_cosmosdb_account.cost_optimized.name
  
  # Serverless - no throughput provisioning needed
}

# Cosmos DB Container with cost-effective settings
resource "azurerm_cosmosdb_sql_container" "cost_optimized" {
  name                = "cost-optimized-container"
  resource_group_name = azurerm_cosmosdb_account.cost_optimized.resource_group_name
  account_name        = azurerm_cosmosdb_account.cost_optimized.name
  database_name       = azurerm_cosmosdb_sql_database.cost_optimized.name
  partition_key_paths = ["/userId"]
  
  # Default TTL for automatic cleanup (cost savings)
  default_ttl = 86400  # 24 hours - automatic document cleanup
  
  # Indexing policy optimization for cost
  indexing_policy {
    indexing_mode = "Consistent"
    
    # Minimal indexing for cost optimization
    included_path {
      path = "/*"
    }
    
    excluded_path {
      path = "/\"_etag\"/?"
    }
  }
}

# ========================================
# REDIS CACHE - BASIC TIER
# ========================================

# Redis Cache - Basic tier for cost optimization
resource "azurerm_redis_cache" "cost_optimized" {
  name                = "redis-cost-optimized-dev-001"
  location            = azurerm_resource_group.database.location
  resource_group_name = azurerm_resource_group.database.name
  capacity            = 0    # C0 - smallest size
  family              = "C"  # Basic family
  sku_name           = "Basic"
  
  # Basic tier settings (no SLA, but lowest cost)
  non_ssl_port_enabled = false  # Security requirement
  minimum_tls_version = "1.2"  # Security requirement
  
  # Disable Redis data persistence to save costs
  redis_configuration {
    maxclients = 256  # Lower connection limit for cost control
  }
  
  tags = merge(local.cost_tags, {
    CacheType = "Redis"
    Tier     = "Basic"
    Size     = "C0"
  })
}

# ========================================
# COST MONITORING AND AUTOMATION
# ========================================

# Budget for database resources
resource "azurerm_consumption_budget_resource_group" "database" {
  name              = "budget-database-dev-monthly"
  resource_group_id = azurerm_resource_group.database.id
  
  amount     = 200  # $200 monthly budget for database resources
  time_grain = "Monthly"
  
  time_period {
    start_date = "2025-08-01T00:00:00Z"
    end_date   = "2026-07-31T23:59:59Z"
  }
  
  # Cost alerts
  notification {
    enabled   = true
    threshold = 75.0
    operator  = "GreaterThan"
    
    contact_emails = [
      "data-team@contoso.com",
      "finance@contoso.com"
    ]
  }
  
  notification {
    enabled   = true
    threshold = 90.0
    operator  = "GreaterThan"
    
    contact_emails = [
      "data-team@contoso.com",
      "finance@contoso.com",
      "management@contoso.com"
    ]
  }
}

# Automation Account for database maintenance
resource "azurerm_automation_account" "database_automation" {
  name                = "aa-database-cost-control-dev-001"
  location            = azurerm_resource_group.database.location
  resource_group_name = azurerm_resource_group.database.name
  sku_name           = "Basic"
  
  tags = merge(local.cost_tags, {
    Purpose = "DatabaseCostControl"
  })
}

# ========================================
# NETWORKING (COST-OPTIMIZED)
# ========================================

# Virtual Network for database connectivity
resource "azurerm_virtual_network" "database" {
  name                = "vnet-database-cost-dev-001"
  location            = azurerm_resource_group.database.location
  resource_group_name = azurerm_resource_group.database.name
  address_space       = ["10.2.0.0/16"]
  
  tags = merge(local.cost_tags, {
    Purpose = "DatabaseConnectivity"
  })
}

# Subnet for database services
resource "azurerm_subnet" "database" {
  name                 = "snet-database-dev-001"
  resource_group_name  = azurerm_resource_group.database.name
  virtual_network_name = azurerm_virtual_network.database.name
  address_prefixes     = ["10.2.1.0/24"]
  
  # Service endpoints for cost-effective private connectivity
  service_endpoints = [
    "Microsoft.Sql",
    "Microsoft.Storage"
  ]
  
  delegation {
    name = "mysql-delegation"
    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

# Private DNS Zone for MySQL (cost-effective private connectivity)
resource "azurerm_private_dns_zone" "mysql" {
  name                = "privatelink.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.database.name
  
  tags = local.cost_tags
}

# Link DNS zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = "mysql-vnet-link"
  resource_group_name   = azurerm_resource_group.database.name
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
  virtual_network_id    = azurerm_virtual_network.database.id
  
  tags = local.cost_tags
}

# ========================================
# SECURITY AND PASSWORDS
# ========================================

# Random passwords for database administrators
resource "random_password" "sql_admin" {
  length  = 16
  special = true
}

resource "random_password" "mysql_admin" {
  length  = 16
  special = true
}

resource "random_password" "postgresql_admin" {
  length  = 16
  special = true
}

# Key Vault to store database credentials
resource "azurerm_key_vault" "database" {
  name                = "kv-database-cost-dev-001"
  location            = azurerm_resource_group.database.location
  resource_group_name = azurerm_resource_group.database.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  
  sku_name = "standard"  # Standard tier for cost optimization
  
  # Cost-conscious retention settings
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  
  tags = merge(local.cost_tags, {
    Purpose = "DatabaseCredentials"
  })
}

# Store database passwords in Key Vault
resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = random_password.sql_admin.result
  key_vault_id = azurerm_key_vault.database.id
  
  tags = local.cost_tags
}

resource "azurerm_key_vault_secret" "mysql_admin_password" {
  name         = "mysql-admin-password"
  value        = random_password.mysql_admin.result
  key_vault_id = azurerm_key_vault.database.id
  
  tags = local.cost_tags
}

resource "azurerm_key_vault_secret" "postgresql_admin_password" {
  name         = "postgresql-admin-password"
  value        = random_password.postgresql_admin.result
  key_vault_id = azurerm_key_vault.database.id
  
  tags = local.cost_tags
}

# Data sources
data "azurerm_client_config" "current" {}

# ========================================
# OUTPUTS - COST ANALYSIS
# ========================================

output "cost_breakdown_estimate" {
  description = "Estimated monthly costs for database resources"
  value = {
    sql_serverless     = "~$5-20/month (based on usage, auto-pause)"
    mysql_flexible     = "~$12/month (B1s Burstable tier)"
    postgresql_flexible = "~$10/month (B1ms Burstable tier)"
    cosmosdb_serverless = "~$0.25/GB + $0.25/million RUs consumed"
    redis_basic        = "~$16/month (C0 Basic tier)"
    storage_costs      = "~$2-5/month (databases + backups)"
    networking         = "~$5/month (VNet, private endpoints)"
    total_estimated    = "~$50-75/month (highly usage-dependent)"
  }
}

output "cost_optimization_features" {
  description = "Cost optimization features implemented"
  value = {
    "sql_serverless_autopause"    = "Pauses after 60 minutes inactivity"
    "mysql_burstable_tier"       = "Pay only for compute used"
    "postgresql_burstable_tier"  = "Lowest cost compute tier"
    "cosmosdb_serverless"        = "Pay per request unit consumed"
    "redis_basic_tier"           = "No SLA but lowest cost"
    "minimal_storage"            = "Minimum storage allocations"
    "short_backup_retention"     = "7-day retention saves storage costs"
    "single_region_deployment"   = "No geo-redundancy costs"
    "service_endpoints"          = "Cost-effective private connectivity"
    "automated_cost_monitoring"  = "Budget alerts at 75% and 90%"
  }
}

output "database_connection_strings" {
  description = "Database connection information"
  value = {
    sql_server = {
      server   = azurerm_mssql_server.cost_optimized.fully_qualified_domain_name
      database = azurerm_mssql_database.serverless.name
      tier     = "Serverless with auto-pause"
    }
    mysql_server = {
      server = azurerm_mysql_flexible_server.cost_optimized.fqdn
      tier   = "Burstable B1s"
    }
    postgresql_server = {
      server = azurerm_postgresql_flexible_server.cost_optimized.fqdn
      tier   = "Burstable B1ms"
    }
    cosmosdb = {
      endpoint = azurerm_cosmosdb_account.cost_optimized.endpoint
      mode     = "Serverless"
    }
    redis = {
      hostname = azurerm_redis_cache.cost_optimized.hostname
      tier     = "Basic C0"
    }
  }
  sensitive = false
}

output "cost_controls" {
  description = "Implemented cost controls"
  value = {
    monthly_budget     = "$200"
    alert_thresholds   = ["75%", "90%"]
    auto_pause_enabled = "SQL Database, 60 minutes"
    min_storage_sizes  = "All databases using minimum storage"
    single_region      = "East US only"
    basic_tiers        = "Redis Basic, Burstable DB tiers"
  }
}
