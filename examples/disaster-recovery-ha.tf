# Disaster Recovery & High Availability Example
# Demonstrates Azure-native DR patterns with multi-region deployment
# Shows compliance with backup policies and enterprise HA requirements

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

# Primary region provider
provider "azurerm" {
  alias = "primary"
  features {}
}

# Secondary region provider for DR
provider "azurerm" {
  alias = "secondary"
  features {}
}

# Local values for DR configuration
locals {
  environment = "prod"  # Production environment for comprehensive DR
  project     = "DisasterRecovery"
  
  # Primary and secondary regions
  primary_region = "East US"
  secondary_region = "West US 2"
  
  # Common tags for all resources
  common_tags = {
    Environment     = local.environment
    Owner          = "sre-team@contoso.com"
    Project        = local.project
    CostCenter     = "Infrastructure"
    Application    = "CriticalBusinessApp"
    DisasterRecovery = "enabled"
    Criticality    = "mission-critical"
    BackupPolicy   = "enterprise"
    ComplianceLevel = "high"
    DataClassification = "confidential"
  }
  
  # DR configuration
  dr_config = {
    rto_minutes = 60      # Recovery Time Objective: 1 hour
    rpo_minutes = 15      # Recovery Point Objective: 15 minutes
    backup_retention_days = 365
    geo_backup_enabled = true
  }
}

# ========================================
# PRIMARY REGION RESOURCES
# ========================================

# Primary Resource Group
resource "azurerm_resource_group" "primary" {
  provider = azurerm.primary
  name     = "rg-${lower(local.project)}-primary-${local.environment}-001"
  location = local.primary_region
  
  tags = merge(local.common_tags, {
    Purpose = "PrimaryRegion"
    Region  = local.primary_region
  })
}

# Primary Virtual Network
resource "azurerm_virtual_network" "primary" {
  provider            = azurerm.primary
  name                = "vnet-${lower(local.project)}-primary-${local.environment}-001"
  resource_group_name = azurerm_resource_group.primary.name
  location            = azurerm_resource_group.primary.location
  address_space       = ["10.0.0.0/16"]
  
  tags = local.common_tags
}

# Primary Application Subnet
resource "azurerm_subnet" "primary_app" {
  provider             = azurerm.primary
  name                 = "snet-app-primary-001"
  resource_group_name  = azurerm_resource_group.primary.name
  virtual_network_name = azurerm_virtual_network.primary.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Primary Database Subnet
resource "azurerm_subnet" "primary_db" {
  provider             = azurerm.primary
  name                 = "snet-db-primary-001"
  resource_group_name  = azurerm_resource_group.primary.name
  virtual_network_name = azurerm_virtual_network.primary.name
  address_prefixes     = ["10.0.2.0/24"]
  
  service_endpoints = ["Microsoft.Sql"]
}

# Primary Recovery Services Vault
resource "azurerm_recovery_services_vault" "primary" {
  provider            = azurerm.primary
  name                = "rsv-${lower(local.project)}-primary-${local.environment}-001"
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name
  sku                 = "Standard"
  
  # Cross Region Restore for enhanced DR
  cross_region_restore_enabled = true
  
  # Soft delete for protection against accidental deletion
  soft_delete_enabled = true
  
  tags = merge(local.common_tags, {
    Purpose = "BackupAndRecovery"
  })
}

# Primary SQL Server
resource "azurerm_mssql_server" "primary" {
  provider                     = azurerm.primary
  name                         = "sql-${lower(local.project)}-primary-${local.environment}-001"
  resource_group_name          = azurerm_resource_group.primary.name
  location                     = azurerm_resource_group.primary.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "ComplexP@ssword123!"
  
  # Enable Azure AD authentication
  azuread_administrator {
    login_username = "DBA-Team"
    object_id      = "00000000-1111-2222-3333-444444444444"  # Replace with actual AD group
  }
  
  tags = local.common_tags
}

# Primary Database with Geo-Replication
resource "azurerm_mssql_database" "primary" {
  provider   = azurerm.primary
  name       = "sqldb-${lower(local.project)}-primary-${local.environment}-001"
  server_id  = azurerm_mssql_server.primary.id
  
  # Business Critical tier for high availability
  sku_name                    = "BC_Gen5_2"  # Business Critical, 2 vCores
  zone_redundant             = true          # Zone redundancy in primary region
  geo_backup_enabled         = true          # Enable geo-backup for DR
  
  # Long-term retention for compliance
  long_term_retention_policy {
    weekly_retention  = "P12W"   # 12 weeks
    monthly_retention = "P12M"   # 12 months  
    yearly_retention  = "P7Y"    # 7 years
    week_of_year     = 1
  }
  
  # Short-term backup for quick recovery
  short_term_retention_policy {
    retention_days = 35
  }
  
  tags = merge(local.common_tags, {
    Purpose = "PrimaryDatabase"
    BackupEnabled = "true"
  })
}

# Primary Virtual Machine Scale Set
resource "azurerm_linux_virtual_machine_scale_set" "primary" {
  provider            = azurerm.primary
  name                = "vmss-${lower(local.project)}-primary-${local.environment}-001"
  resource_group_name = azurerm_resource_group.primary.name
  location            = azurerm_resource_group.primary.location
  sku                 = "Standard_D2s_v3"
  instances           = 2
  
  # Zone distribution for high availability
  zones = ["1", "2"]
  
  # Disable password authentication
  disable_password_authentication = true
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  
  os_disk {
    storage_account_type = "Premium_SSD"
    caching              = "ReadWrite"
  }
  
  network_interface {
    name    = "primary-nic"
    primary = true
    
    ip_configuration {
      name      = "primary-ip"
      primary   = true
      subnet_id = azurerm_subnet.primary_app.id
    }
  }
  
  admin_username = "azureuser"
  
  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7... (your-public-key-here)"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "ApplicationTier"
  })
}

# ========================================
# SECONDARY REGION RESOURCES (DR)
# ========================================

# Secondary Resource Group
resource "azurerm_resource_group" "secondary" {
  provider = azurerm.secondary
  name     = "rg-${lower(local.project)}-secondary-${local.environment}-001"
  location = local.secondary_region
  
  tags = merge(local.common_tags, {
    Purpose = "SecondaryRegion"
    Region  = local.secondary_region
  })
}

# Secondary Virtual Network
resource "azurerm_virtual_network" "secondary" {
  provider            = azurerm.secondary
  name                = "vnet-${lower(local.project)}-secondary-${local.environment}-001"
  resource_group_name = azurerm_resource_group.secondary.name
  location            = azurerm_resource_group.secondary.location
  address_space       = ["10.1.0.0/16"]  # Different IP range
  
  tags = local.common_tags
}

# Secondary Application Subnet
resource "azurerm_subnet" "secondary_app" {
  provider             = azurerm.secondary
  name                 = "snet-app-secondary-001"
  resource_group_name  = azurerm_resource_group.secondary.name
  virtual_network_name = azurerm_virtual_network.secondary.name
  address_prefixes     = ["10.1.1.0/24"]
}

# Secondary SQL Server for Geo-Replication
resource "azurerm_mssql_server" "secondary" {
  provider                     = azurerm.secondary
  name                         = "sql-${lower(local.project)}-secondary-${local.environment}-001"
  resource_group_name          = azurerm_resource_group.secondary.name
  location                     = azurerm_resource_group.secondary.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "ComplexP@ssword123!"
  
  tags = local.common_tags
}

# Geo-Replica Database (Read-Only Secondary)
resource "azurerm_mssql_database" "secondary" {
  provider                   = azurerm.secondary
  name                       = "sqldb-${lower(local.project)}-secondary-${local.environment}-001"
  server_id                  = azurerm_mssql_server.secondary.id
  create_mode               = "Secondary"
  creation_source_database_id = azurerm_mssql_database.primary.id
  
  # Match primary database tier for failover
  sku_name = "BC_Gen5_2"
  
  tags = merge(local.common_tags, {
    Purpose = "SecondaryDatabase"
    ReadOnly = "true"
  })
}

# Secondary Recovery Services Vault
resource "azurerm_recovery_services_vault" "secondary" {
  provider            = azurerm.secondary
  name                = "rsv-${lower(local.project)}-secondary-${local.environment}-001"
  location            = azurerm_resource_group.secondary.location
  resource_group_name = azurerm_resource_group.secondary.name
  sku                 = "Standard"
  
  cross_region_restore_enabled = true
  soft_delete_enabled = true
  
  tags = merge(local.common_tags, {
    Purpose = "SecondaryBackupAndRecovery"
  })
}

# ========================================
# TRAFFIC MANAGER FOR FAILOVER
# ========================================

# Traffic Manager Profile for automatic failover
resource "azurerm_traffic_manager_profile" "main" {
  name                = "tm-${lower(local.project)}-${local.environment}-001"
  resource_group_name = azurerm_resource_group.primary.name
  
  traffic_routing_method = "Priority"  # Failover routing
  
  dns_config {
    relative_name = "${lower(local.project)}-${local.environment}"
    ttl          = 30  # Low TTL for fast failover
  }
  
  monitor_config {
    protocol                     = "HTTPS"
    port                        = 443
    path                        = "/health"
    interval_in_seconds         = 30
    timeout_in_seconds          = 10
    tolerated_number_of_failures = 3
  }
  
  tags = merge(local.common_tags, {
    Purpose = "LoadBalancingAndFailover"
  })
}

# ========================================
# MONITORING AND ALERTING
# ========================================

# Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${lower(local.project)}-${local.environment}-001"
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name
  sku                 = "PerGB2018"
  retention_in_days   = 365  # Long retention for audit compliance
  
  tags = merge(local.common_tags, {
    Purpose = "MonitoringAndLogging"
  })
}

# Action Group for DR notifications
resource "azurerm_monitor_action_group" "dr_alerts" {
  name                = "ag-dr-alerts-${local.environment}"
  resource_group_name = azurerm_resource_group.primary.name
  short_name          = "dr-alerts"
  
  email_receiver {
    name          = "SRE Team"
    email_address = "sre-team@contoso.com"
  }
  
  sms_receiver {
    name         = "SRE Oncall"
    country_code = "1"
    phone_number = "5551234567"
  }
  
  tags = local.common_tags
}

# Database Connection Alert
resource "azurerm_monitor_metric_alert" "database_connection" {
  name                = "alert-db-connection-${local.environment}"
  resource_group_name = azurerm_resource_group.primary.name
  scopes              = [azurerm_mssql_database.primary.id]
  description         = "Database connection failures - potential DR event"
  severity            = 0  # Critical
  frequency           = "PT5M"  # Check every 5 minutes
  window_size         = "PT15M" # 15 minute window
  
  criteria {
    metric_namespace = "Microsoft.Sql/servers/databases"
    metric_name      = "connection_failed"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.dr_alerts.id
  }
  
  tags = local.common_tags
}

# ========================================
# OUTPUTS
# ========================================

output "disaster_recovery_summary" {
  description = "Disaster Recovery Configuration Summary"
  value = {
    primary_region = local.primary_region
    secondary_region = local.secondary_region
    rto_minutes = local.dr_config.rto_minutes
    rpo_minutes = local.dr_config.rpo_minutes
    
    # Key resource information
    primary_sql_server = azurerm_mssql_server.primary.fully_qualified_domain_name
    secondary_sql_server = azurerm_mssql_server.secondary.fully_qualified_domain_name
    traffic_manager_fqdn = azurerm_traffic_manager_profile.main.fqdn
    
    # Backup information
    primary_vault = azurerm_recovery_services_vault.primary.name
    secondary_vault = azurerm_recovery_services_vault.secondary.name
    backup_retention_days = local.dr_config.backup_retention_days
  }
}

output "failover_checklist" {
  description = "Manual failover steps (in case of disaster)"
  value = [
    "1. Assess primary region status and impact",
    "2. Initiate database failover to secondary region",
    "3. Update Traffic Manager endpoints if needed",
    "4. Scale up secondary region resources",
    "5. Update DNS records if using custom domains", 
    "6. Verify application functionality in secondary region",
    "7. Communicate status to stakeholders",
    "8. Monitor for resolution in primary region"
  ]
}
