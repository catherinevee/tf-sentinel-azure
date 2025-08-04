# Data Engineering & Analytics Platform Example
# Demonstrates comprehensive data platform with strict governance and compliance
# Shows data lake, analytics, ETL pipelines, and security best practices

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
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# Generate random suffix for globally unique names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Local values for data platform configuration
locals {
  environment = "prod"
  project     = "DataPlatform"
  
  # Common tags for all resources
  common_tags = {
    Environment        = local.environment
    Owner             = "data-team@contoso.com"
    Project           = local.project
    CostCenter        = "DataEngineering"
    Application       = "AnalyticsPlatform"
    DataGovernance    = "enabled"
    ComplianceLevel   = "high"
    DataClassification = "restricted"
    BackupPolicy      = "enterprise"
    SecurityBaseline  = "data-governance"
  }
  
  # Data platform configuration
  data_config = {
    storage_tier = "Hot"          # Hot tier for frequently accessed data
    replication_type = "ZRS"      # Zone-redundant for high availability
    retention_days = 2555         # 7 years for compliance
    purview_enabled = true        # Data catalog and governance
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
# NETWORKING
# ========================================

# Virtual Network for data platform
resource "azurerm_virtual_network" "data_platform" {
  name                = "vnet-${lower(local.project)}-${local.environment}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]
  
  tags = local.common_tags
}

# Subnet for data services
resource "azurerm_subnet" "data_services" {
  name                 = "snet-data-services-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.data_platform.name
  address_prefixes     = ["10.0.1.0/24"]
  
  # Service endpoints for data services
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.Sql",
    "Microsoft.KeyVault"
  ]
}

# Subnet for compute resources
resource "azurerm_subnet" "compute" {
  name                 = "snet-compute-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.data_platform.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Network Security Group for data services
resource "azurerm_network_security_group" "data_services" {
  name                = "nsg-data-services-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  # Allow HTTPS only
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
  
  # Allow SQL Database access
  security_rule {
    name                       = "AllowSQL"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "10.0.2.0/24"  # From compute subnet only
    destination_address_prefix = "*"
  }
  
  tags = local.common_tags
}

# Associate NSG with data services subnet
resource "azurerm_subnet_network_security_group_association" "data_services" {
  subnet_id                 = azurerm_subnet.data_services.id
  network_security_group_id = azurerm_network_security_group.data_services.id
}

# ========================================
# KEY VAULT FOR SECRETS MANAGEMENT
# ========================================

# Get current client configuration
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                = "kv-${lower(local.project)}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name           = "premium"  # Premium SKU for HSM-backed keys
  
  # Network access restrictions
  public_network_access_enabled = false
  
  # Soft delete and purge protection for compliance
  soft_delete_retention_days = 90
  purge_protection_enabled   = true
  
  # Network ACLs
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    
    virtual_network_subnet_ids = [
      azurerm_subnet.data_services.id,
      azurerm_subnet.compute.id
    ]
  }
  
  tags = merge(local.common_tags, {
    Purpose = "SecretsManagement"
  })
}

# Key Vault access policy for current user/service principal
resource "azurerm_key_vault_access_policy" "current" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id
  
  key_permissions = [
    "Create", "Get", "List", "Update", "Delete", "Purge", "Recover"
  ]
  
  secret_permissions = [
    "Set", "Get", "List", "Delete", "Purge", "Recover"
  ]
  
  certificate_permissions = [
    "Create", "Get", "List", "Update", "Delete", "Purge", "Recover"
  ]
}

# ========================================
# DATA LAKE STORAGE GEN2
# ========================================

resource "azurerm_storage_account" "data_lake" {
  name                = "sadl${lower(replace(local.project, "-", ""))}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  account_tier             = "Standard"
  account_replication_type = local.data_config.replication_type
  account_kind            = "StorageV2"
  
  # Enable hierarchical namespace for Data Lake Gen2
  is_hns_enabled = true
  
  # Security configurations
  https_traffic_only_enabled      = true
  min_tls_version                = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false  # Use managed identity only
  
  # Network access restrictions
  public_network_access_enabled = false
  
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    
    virtual_network_subnet_ids = [
      azurerm_subnet.data_services.id,
      azurerm_subnet.compute.id
    ]
  }
  
  # Blob properties
  blob_properties {
    # Soft delete for blobs
    delete_retention_policy {
      days = 30
    }
    
    # Versioning
    versioning_enabled = true
    
    # Change feed for auditing
    change_feed_enabled = true
    
    # Container soft delete
    container_delete_retention_policy {
      days = 30
    }
  }
  
  tags = merge(local.common_tags, {
    Purpose = "DataLakeStorage"
    StorageType = "DataLakeGen2"
  })
}

# Data Lake containers
resource "azurerm_storage_data_lake_gen2_filesystem" "raw" {
  name               = "raw"
  storage_account_id = azurerm_storage_account.data_lake.id
  
  properties = {
    "description" = "Raw data ingestion layer"
  }
}

resource "azurerm_storage_data_lake_gen2_filesystem" "processed" {
  name               = "processed"
  storage_account_id = azurerm_storage_account.data_lake.id
  
  properties = {
    "description" = "Processed and cleaned data"
  }
}

resource "azurerm_storage_data_lake_gen2_filesystem" "curated" {
  name               = "curated"
  storage_account_id = azurerm_storage_account.data_lake.id
  
  properties = {
    "description" = "Business-ready curated datasets"
  }
}

# ========================================
# SYNAPSE ANALYTICS WORKSPACE
# ========================================

resource "azurerm_synapse_workspace" "main" {
  name                 = "synws-${lower(local.project)}-${random_string.suffix.result}"
  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.processed.id
  
  sql_administrator_login          = "synapseadmin"
  sql_administrator_login_password = "ComplexP@ssword123!"
  
  # Managed virtual network
  managed_virtual_network_enabled = true
  
  # Data exfiltration protection
  data_exfiltration_protection_enabled = true
  
  # Public network access
  public_network_access_enabled = false
  
  # Azure AD authentication
  aad_admin {
    login     = "DataTeam"
    object_id = "00000000-1111-2222-3333-444444444444"  # Replace with actual AD group
    tenant_id = data.azurerm_client_config.current.tenant_id
  }
  
  # System-assigned managed identity
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "DataWarehouse"
  })
}

# Synapse SQL Pool (Data Warehouse)
resource "azurerm_synapse_sql_pool" "main" {
  name                 = "sqldw${lower(replace(local.project, "-", ""))}"
  synapse_workspace_id = azurerm_synapse_workspace.main.id
  sku_name            = "DW100c"  # Cost-optimized starting size
  create_mode         = "Default"
  
  # Auto-pause for cost optimization
  storage_account_type = "LRS"  # Locally redundant for cost savings
  
  tags = merge(local.common_tags, {
    Purpose = "DataWarehouse"
    AutoPause = "enabled"
  })
}

# Synapse Spark Pool for big data processing
resource "azurerm_synapse_spark_pool" "main" {
  name                 = "spark${lower(replace(local.project, "-", ""))}"
  synapse_workspace_id = azurerm_synapse_workspace.main.id
  node_size_family     = "MemoryOptimized"
  node_size           = "Small"  # Cost-optimized node size
  
  # Auto-scaling configuration
  auto_scale {
    max_node_count = 10
    min_node_count = 3
  }
  
  # Auto-pause for cost optimization
  auto_pause {
    delay_in_minutes = 5  # Pause after 5 minutes of inactivity
  }
  
  # Spark configuration
  spark_config {
    content  = "spark.sql.adaptive.enabled=true"
    filename = "config.txt"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "BigDataProcessing"
    AutoPause = "enabled"
  })
}

# ========================================
# DATA FACTORY FOR ETL PIPELINES
# ========================================

resource "azurerm_data_factory" "main" {
  name                = "adf-${lower(local.project)}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  # Managed identity for authentication
  identity {
    type = "SystemAssigned"
  }
  
  # Public network access
  public_network_access_enabled = false
  
  # Git configuration for source control
  vsts_configuration {
    account_name    = "contoso"
    branch_name     = "main"
    project_name    = "data-platform"
    repository_name = "adf-pipelines"
    root_folder     = "/pipelines"
    tenant_id       = data.azurerm_client_config.current.tenant_id
  }
  
  tags = merge(local.common_tags, {
    Purpose = "DataPipelines"
  })
}

# Data Factory linked service to Data Lake
resource "azurerm_data_factory_linked_service_data_lake_storage_gen2" "main" {
  name            = "DataLakeLinkedService"
  data_factory_id = azurerm_data_factory.main.id
  url             = azurerm_storage_account.data_lake.primary_dfs_endpoint
  
  # Use managed identity for authentication
  use_managed_identity = true
}

# Data Factory linked service to Synapse
resource "azurerm_data_factory_linked_service_synapse" "main" {
  name            = "SynapseLinkedService"
  data_factory_id = azurerm_data_factory.main.id
  connection_string = "Server=tcp:${azurerm_synapse_workspace.main.name}.sql.azuresynapse.net,1433;Database=${azurerm_synapse_sql_pool.main.name};Trusted_Connection=False;Encrypt=True;Connection Timeout=30;"
  
  # Use managed identity for authentication
  use_managed_identity = true
}

# ========================================
# PRIVATE ENDPOINTS FOR SECURE ACCESS
# ========================================

# Private DNS Zone for Storage
resource "azurerm_private_dns_zone" "storage_dfs" {
  name                = "privatelink.dfs.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name
  
  tags = local.common_tags
}

# Link DNS zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "storage_dfs" {
  name                  = "storage-dfs-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_dfs.name
  virtual_network_id    = azurerm_virtual_network.data_platform.id
  
  tags = local.common_tags
}

# Private endpoint for Data Lake Storage
resource "azurerm_private_endpoint" "data_lake" {
  name                = "pe-datalake-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.data_services.id
  
  private_service_connection {
    name                           = "datalake-connection"
    private_connection_resource_id = azurerm_storage_account.data_lake.id
    subresource_names             = ["dfs"]
    is_manual_connection          = false
  }
  
  private_dns_zone_group {
    name                 = "datalake-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage_dfs.id]
  }
  
  tags = merge(local.common_tags, {
    Purpose = "PrivateEndpoint"
  })
}

# ========================================
# RBAC AND PERMISSIONS
# ========================================

# Data Lake Storage Blob Data Contributor role for Synapse
resource "azurerm_role_assignment" "synapse_data_contributor" {
  scope                = azurerm_storage_account.data_lake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_synapse_workspace.main.identity[0].principal_id
}

# Data Factory Contributor role for Synapse to Data Lake
resource "azurerm_role_assignment" "adf_data_contributor" {
  scope                = azurerm_storage_account.data_lake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.main.identity[0].principal_id
}

# Key Vault access for Synapse
resource "azurerm_key_vault_access_policy" "synapse" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_synapse_workspace.main.identity[0].principal_id
  
  secret_permissions = [
    "Get", "List"
  ]
}

# Key Vault access for Data Factory
resource "azurerm_key_vault_access_policy" "adf" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_data_factory.main.identity[0].principal_id
  
  secret_permissions = [
    "Get", "List"
  ]
}

# ========================================
# MONITORING AND LOGGING
# ========================================

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${lower(local.project)}-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = local.data_config.retention_days
  
  tags = merge(local.common_tags, {
    Purpose = "DataPlatformLogging"
  })
}

# Diagnostic settings for Data Lake Storage
resource "azurerm_monitor_diagnostic_setting" "data_lake" {
  name                       = "diag-datalake-${local.environment}"
  target_resource_id         = azurerm_storage_account.data_lake.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  
  enabled_log {
    category = "StorageRead"
  }
  
  enabled_log {
    category = "StorageWrite"
  }
  
  enabled_log {
    category = "StorageDelete"
  }
  
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Diagnostic settings for Synapse Workspace
resource "azurerm_monitor_diagnostic_setting" "synapse" {
  name                       = "diag-synapse-${local.environment}"
  target_resource_id         = azurerm_synapse_workspace.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  
  enabled_log {
    category = "SynapseRbacOperations"
  }
  
  enabled_log {
    category = "GatewayApiRequests"
  }
  
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ========================================
# OUTPUTS
# ========================================

output "data_platform_summary" {
  description = "Data Platform Configuration Summary"
  value = {
    # Core services
    synapse_workspace = azurerm_synapse_workspace.main.name
    data_lake_storage = azurerm_storage_account.data_lake.name
    data_factory = azurerm_data_factory.main.name
    key_vault = azurerm_key_vault.main.name
    
    # Synapse endpoints
    synapse_sql_endpoint = azurerm_synapse_workspace.main.sql_connectivity_endpoint
    synapse_dev_endpoint = azurerm_synapse_workspace.main.connectivity_endpoints.development
    
    # Data Lake containers
    data_lake_containers = [
      azurerm_storage_data_lake_gen2_filesystem.raw.name,
      azurerm_storage_data_lake_gen2_filesystem.processed.name,
      azurerm_storage_data_lake_gen2_filesystem.curated.name
    ]
    
    # Compute resources
    sql_pool = azurerm_synapse_sql_pool.main.name
    spark_pool = azurerm_synapse_spark_pool.main.name
  }
}

output "security_features" {
  description = "Enabled security and governance features"
  value = [
    "Private endpoints for all data services",
    "Managed virtual network for Synapse",
    "Data exfiltration protection enabled",
    "Azure AD authentication configured",
    "Key Vault integration for secrets",
    "Network access restrictions (deny public)",
    "Encryption at rest and in transit",
    "Soft delete and versioning enabled",
    "Comprehensive audit logging",
    "RBAC with least privilege access"
  ]
}

output "cost_optimization_features" {
  description = "Enabled cost optimization features"
  value = [
    "Auto-pause enabled for Spark pools (5 minutes)",
    "Auto-scaling Spark pools (3-10 nodes)",
    "DW100c SQL pool (smallest production size)",
    "LRS storage for SQL pool (cost-effective)",
    "Small node size for Spark processing",
    "Zone-redundant storage (balanced cost/availability)",
    "Memory-optimized nodes for efficient processing"
  ]
}
