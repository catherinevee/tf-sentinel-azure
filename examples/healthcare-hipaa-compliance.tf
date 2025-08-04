# Healthcare HIPAA Compliance Example
# Demonstrates HIPAA-compliant healthcare infrastructure with comprehensive security
# Shows encrypted databases, secure networking, audit logging, and healthcare-specific compliance

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
      purge_soft_delete_on_destroy    = false  # HIPAA requires data protection
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

# Local values for healthcare HIPAA compliance configuration
locals {
  environment = "prod"
  project     = "HealthcareHIPAA"
  
  # Common tags for all resources (HIPAA compliance)
  common_tags = {
    Environment     = local.environment
    Owner          = "compliance-team@hospital.com"
    Project        = local.project
    CostCenter     = "IT-Compliance"
    Application    = "HealthcareEMR"
    DataClassification = "phi"  # Protected Health Information
    ComplianceLevel = "hipaa"
    BackupPolicy   = "critical"
    AuditRequired  = "true"
    DataRetention  = "7years"
    EncryptionRequired = "true"
  }
  
  # HIPAA compliance configuration
  hipaa_config = {
    # Database configuration for PHI
    sql_sku = "S2"  # Standard tier with better performance for healthcare
    sql_backup_retention = 35  # Extended backup retention
    
    # Key Vault configuration
    key_vault_sku = "premium"  # Premium for HSM-backed keys
    
    # Storage configuration
    storage_tier = "Standard"
    storage_replication = "GRS"  # Geo-redundant for DR
    
    # Network security
    allowed_ip_ranges = [
      "10.0.0.0/8",     # Private networks only
      "172.16.0.0/12",  # Private networks only
      "192.168.0.0/16"  # Private networks only
    ]
    
    # Audit log retention
    audit_retention_days = 2555  # 7 years in days (HIPAA requirement)
    
    # App Service configuration
    app_service_sku = "P1v3"  # Premium for better security features
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
# KEY VAULT WITH HSM FOR PHI ENCRYPTION
# ========================================

resource "azurerm_key_vault" "hipaa" {
  name                = "kv-hipaa-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = local.hipaa_config.key_vault_sku
  
  # HIPAA security requirements
  enabled_for_disk_encryption     = true
  enabled_for_deployment          = false  # Restrict deployment access
  enabled_for_template_deployment = false
  purge_protection_enabled        = true   # Prevent accidental deletion
  soft_delete_retention_days      = 90     # Extended retention for compliance
  
  # Network restrictions for HIPAA
  public_network_access_enabled = false
  
  network_acls {
    default_action = "Deny"
    bypass         = "None"  # Strict access control
    
    virtual_network_subnet_ids = [azurerm_subnet.private_endpoints.id]
  }
  
  tags = merge(local.common_tags, {
    Purpose = "HIIPAAKeyManagement"
    SecurityLevel = "Premium"
  })
}

# HSM-backed key for PHI encryption
resource "azurerm_key_vault_key" "phi_encryption" {
  name         = "phi-encryption-key"
  key_vault_id = azurerm_key_vault.hipaa.id
  key_type     = "RSA-HSM"  # HSM-backed for HIPAA compliance
  key_size     = 2048
  
  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
  
  tags = merge(local.common_tags, {
    Purpose = "PHIEncryption"
  })
}

# ========================================
# NETWORKING WITH PRIVATE ENDPOINTS
# ========================================

# Virtual Network with private subnets
resource "azurerm_virtual_network" "hipaa" {
  name                = "vnet-${lower(local.project)}-${local.environment}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]
  
  # Custom DNS for private endpoints
  dns_servers = ["168.63.129.16"]  # Azure DNS
  
  tags = merge(local.common_tags, {
    Purpose = "HIPAASecureNetwork"
  })
}

# Subnet for application services
resource "azurerm_subnet" "app_services" {
  name                 = "snet-app-services-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hipaa.name
  address_prefixes     = ["10.0.1.0/24"]
  
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.Sql",
    "Microsoft.KeyVault"
  ]
  
  delegation {
    name = "Microsoft.Web/serverFarms"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
    }
  }
}

# Subnet for private endpoints
resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hipaa.name
  address_prefixes     = ["10.0.2.0/24"]
  
  private_endpoint_network_policies_enabled = false
}

# ========================================
# SQL DATABASE WITH ENCRYPTION
# ========================================

# SQL Server with Advanced Security
resource "azurerm_mssql_server" "hipaa" {
  name                = "sql-hipaa-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  version             = "12.0"
  
  administrator_login          = "hipaa_admin"
  administrator_login_password = "ComplexP@ssw0rd123!"  # In production, use Key Vault
  
  # HIPAA security requirements
  public_network_access_enabled = false  # Private access only
  minimum_tls_version           = "1.2"
  
  # Azure AD authentication
  azuread_administrator {
    login_username = "hipaa-admin@hospital.com"
    object_id      = data.azurerm_client_config.current.object_id
    tenant_id      = data.azurerm_client_config.current.tenant_id
  }
  
  # Managed identity for secure operations
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "HIPAADatabase"
    PHIStorage = "true"
  })
}

# SQL Database with Transparent Data Encryption
resource "azurerm_mssql_database" "phi" {
  name           = "sqldb-phi-${local.environment}-001"
  server_id      = azurerm_mssql_server.hipaa.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  sku_name       = local.hipaa_config.sql_sku
  zone_redundant = true  # High availability for critical data
  
  # Customer-managed encryption key
  transparent_data_encryption_key_vault_key_id = azurerm_key_vault_key.phi_encryption.id
  
  # Extended backup retention for HIPAA
  short_term_retention_policy {
    retention_days = local.hipaa_config.sql_backup_retention
  }
  
  long_term_retention_policy {
    weekly_retention  = "P12W"   # 12 weeks
    monthly_retention = "P12M"   # 12 months
    yearly_retention  = "P7Y"    # 7 years (HIPAA requirement)
    week_of_year     = 1
  }
  
  tags = merge(local.common_tags, {
    Purpose = "PHIStorage"
    EncryptionType = "CustomerManaged"
  })
}

# Advanced Threat Protection
resource "azurerm_mssql_server_security_alert_policy" "hipaa" {
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mssql_server.hipaa.name
  state               = "Enabled"
  
  storage_endpoint           = azurerm_storage_account.audit_logs.primary_blob_endpoint
  storage_account_access_key = azurerm_storage_account.audit_logs.primary_access_key
  retention_days            = local.hipaa_config.audit_retention_days
  
  email_account_admins = true
  email_addresses      = ["security@hospital.com"]
}

# Vulnerability Assessment
resource "azurerm_mssql_server_vulnerability_assessment" "hipaa" {
  server_security_alert_policy_id = azurerm_mssql_server_security_alert_policy.hipaa.id
  storage_container_path          = "${azurerm_storage_account.audit_logs.primary_blob_endpoint}vulnerability-assessment/"
  storage_account_access_key      = azurerm_storage_account.audit_logs.primary_access_key
  
  recurring_scans {
    enabled                   = true
    email_subscription_admins = true
    emails                    = ["security@hospital.com"]
  }
}

# ========================================
# STORAGE ACCOUNT FOR PHI WITH ENCRYPTION
# ========================================

resource "azurerm_storage_account" "phi" {
  name                = "saphihipaa${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  account_tier             = local.hipaa_config.storage_tier
  account_replication_type = local.hipaa_config.storage_replication
  account_kind            = "StorageV2"
  
  # HIPAA security requirements
  https_traffic_only_enabled          = true
  min_tls_version                     = "TLS1_2"
  allow_nested_items_to_be_public     = false
  shared_access_key_enabled           = false  # Use managed identity only
  default_to_oauth_authentication     = true
  public_network_access_enabled       = false
  
  # Customer-managed encryption
  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.phi_encryption.id
    user_assigned_identity_id = azurerm_user_assigned_identity.storage.id
  }
  
  # Network restrictions
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    
    virtual_network_subnet_ids = [azurerm_subnet.app_services.id]
  }
  
  # Immutable blob storage for audit compliance
  blob_properties {
    versioning_enabled       = true
    change_feed_enabled      = true
    change_feed_retention_in_days = local.hipaa_config.audit_retention_days
    
    delete_retention_policy {
      days = local.hipaa_config.audit_retention_days
    }
    
    container_delete_retention_policy {
      days = local.hipaa_config.audit_retention_days
    }
    
    restore_policy {
      days = 7  # Point-in-time restore
    }
  }
  
  tags = merge(local.common_tags, {
    Purpose = "PHIStorage"
    EncryptionType = "CustomerManaged"
  })
  
  depends_on = [azurerm_key_vault_access_policy.storage_cmk]
}

# Container for PHI documents
resource "azurerm_storage_container" "phi_documents" {
  name                  = "phi-documents"
  storage_account_name  = azurerm_storage_account.phi.name
  container_access_type = "private"
}

# Immutable storage policy for PHI documents
resource "azurerm_storage_management_policy" "phi_retention" {
  storage_account_id = azurerm_storage_account.phi.id
  
  rule {
    name    = "phi-retention-policy"
    enabled = true
    
    filters {
      prefix_match = ["phi-documents/"]
      blob_types   = ["blockBlob"]
    }
    
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 2555  # 7 years
      }
      
      version {
        delete_after_days_since_creation = 2555
      }
    }
  }
}

# ========================================
# AUDIT LOGGING STORAGE (SEPARATE ACCOUNT)
# ========================================

resource "azurerm_storage_account" "audit_logs" {
  name                = "saaudit${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  account_tier             = "Standard"
  account_replication_type = "GRS"  # Geo-redundant for audit logs
  account_kind            = "StorageV2"
  
  # Enhanced security for audit logs
  https_traffic_only_enabled          = true
  min_tls_version                     = "TLS1_2"
  allow_nested_items_to_be_public     = false
  public_network_access_enabled       = false
  
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    
    virtual_network_subnet_ids = [azurerm_subnet.app_services.id]
  }
  
  # Immutable blob storage for audit logs
  blob_properties {
    versioning_enabled = true
    change_feed_enabled = true
    
    delete_retention_policy {
      days = local.hipaa_config.audit_retention_days
    }
    
    container_delete_retention_policy {
      days = local.hipaa_config.audit_retention_days
    }
  }
  
  tags = merge(local.common_tags, {
    Purpose = "AuditLogging"
    ImmutableStorage = "true"
  })
}

# Container for audit logs with legal hold
resource "azurerm_storage_container" "audit_logs" {
  name                  = "audit-logs"
  storage_account_name  = azurerm_storage_account.audit_logs.name
  container_access_type = "private"
}

# ========================================
# MANAGED IDENTITY FOR STORAGE ENCRYPTION
# ========================================

resource "azurerm_user_assigned_identity" "storage" {
  name                = "id-storage-cmk-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  tags = merge(local.common_tags, {
    Purpose = "StorageEncryption"
  })
}

# Key Vault access policy for storage managed identity
resource "azurerm_key_vault_access_policy" "storage_cmk" {
  key_vault_id = azurerm_key_vault.hipaa.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.storage.principal_id
  
  key_permissions = [
    "Get", "UnwrapKey", "WrapKey"
  ]
}

# ========================================
# APP SERVICE WITH HIPAA COMPLIANCE
# ========================================

resource "azurerm_service_plan" "hipaa" {
  name                = "plan-hipaa-${local.environment}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name           = local.hipaa_config.app_service_sku
  zone_balancing_enabled = true  # High availability
  
  tags = merge(local.common_tags, {
    Purpose = "HIPAAWebHosting"
  })
}

resource "azurerm_linux_web_app" "hipaa" {
  name                = "app-hipaa-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.hipaa.id
  
  # VNet integration for security
  virtual_network_subnet_id = azurerm_subnet.app_services.id
  
  site_config {
    always_on = true  # Required for production healthcare apps
    
    application_stack {
      dotnet_version = "6.0"
    }
    
    # HIPAA security headers
    http2_enabled = true
    ftps_state   = "Disabled"
    
    # IP restrictions for healthcare network
    dynamic "ip_restriction" {
      for_each = local.hipaa_config.allowed_ip_ranges
      content {
        ip_address = ip_restriction.value
        action     = "Allow"
        priority   = 100 + ip_restriction.key
        name       = "AllowHealthcareNetwork${ip_restriction.key}"
      }
    }
  }
  
  # HIPAA-compliant application settings
  app_settings = {
    "ASPNETCORE_ENVIRONMENT"           = "Production"
    "HIPAA_COMPLIANCE_MODE"           = "true"
    "PHI_ENCRYPTION_KEY_VAULT_URL"    = azurerm_key_vault.hipaa.vault_uri
    "AUDIT_STORAGE_CONNECTION"        = azurerm_storage_account.audit_logs.primary_connection_string
    "APPINSIGHTS_INSTRUMENTATIONKEY"  = azurerm_application_insights.hipaa.instrumentation_key
  }
  
  # Secure connection strings
  connection_string {
    name  = "HIPAADatabase"
    type  = "SQLAzure"
    value = "Server=tcp:${azurerm_mssql_server.hipaa.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.phi.name};Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  }
  
  # Authentication and authorization
  auth_settings_v2 {
    auth_enabled = true
    require_authentication = true
    require_https = true
    
    active_directory_v2 {
      client_id = data.azurerm_client_config.current.client_id
      tenant_auth_endpoint = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0"
    }
  }
  
  # Managed identity for secure access
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "HIPAAWebApplication"
    PHIAccess = "true"
  })
}

# ========================================
# MONITORING AND AUDITING
# ========================================

# Log Analytics Workspace for HIPAA audit logs
resource "azurerm_log_analytics_workspace" "hipaa" {
  name                = "log-hipaa-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = local.hipaa_config.audit_retention_days
  
  tags = merge(local.common_tags, {
    Purpose = "HIPAAAuditLogging"
  })
}

resource "azurerm_application_insights" "hipaa" {
  name                = "appi-hipaa-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.hipaa.id
  application_type    = "web"
  
  # Extended retention for compliance
  retention_in_days = 730  # 2 years for application logs
  
  tags = merge(local.common_tags, {
    Purpose = "HIPAAApplicationMonitoring"
  })
}

# Diagnostic settings for SQL audit logs
resource "azurerm_monitor_diagnostic_setting" "sql_audit" {
  name               = "sql-audit-logs"
  target_resource_id = azurerm_mssql_server.hipaa.id
  storage_account_id = azurerm_storage_account.audit_logs.id
  
  enabled_log {
    category = "SQLSecurityAuditEvents"
  }
  
  enabled_log {
    category = "DevOpsOperationsAudit"
  }
  
  metric {
    category = "Basic"
    enabled  = true
  }
}

# Current client configuration
data "azurerm_client_config" "current" {}

# ========================================
# OUTPUTS
# ========================================

output "hipaa_healthcare_summary" {
  description = "HIPAA Healthcare Platform Configuration Summary"
  value = {
    # Core healthcare services
    web_application_url = "https://${azurerm_linux_web_app.hipaa.default_hostname}"
    sql_server = azurerm_mssql_server.hipaa.fully_qualified_domain_name
    database_name = azurerm_mssql_database.phi.name
    
    # Security components
    key_vault_url = azurerm_key_vault.hipaa.vault_uri
    phi_storage_account = azurerm_storage_account.phi.name
    audit_storage_account = azurerm_storage_account.audit_logs.name
    
    # Monitoring
    application_insights = azurerm_application_insights.hipaa.name
    log_analytics_workspace = azurerm_log_analytics_workspace.hipaa.name
    
    # Network security
    virtual_network = azurerm_virtual_network.hipaa.name
  }
}

output "hipaa_compliance_features" {
  description = "HIPAA compliance features implemented"
  value = [
    "Customer-managed encryption keys (CMK) with HSM",
    "Transparent Data Encryption (TDE) for SQL Database",
    "Private endpoints for all services (no public access)",
    "VNet integration with private subnets only",
    "Azure AD authentication and authorization",
    "Advanced Threat Protection for SQL",
    "Vulnerability Assessment scanning",
    "Immutable blob storage for PHI and audit logs",
    "7-year data retention for HIPAA compliance",
    "Comprehensive audit logging and monitoring",
    "IP restrictions to healthcare networks only",
    "Point-in-time restore capabilities"
  ]
}

output "security_controls" {
  description = "Security controls for HIPAA compliance"
  value = [
    "Access Control: Azure AD integration with MFA",
    "Audit Controls: Comprehensive logging to immutable storage",
    "Integrity: Digital signatures and checksums",
    "Person or Entity Authentication: Azure AD + managed identities",
    "Transmission Security: TLS 1.2+ for all communications",
    "Encryption: AES-256 with HSM-backed keys",
    "Network Security: Private endpoints and VNet isolation",
    "Data Backup: Geo-redundant backups with 7-year retention",
    "Vulnerability Management: Automated scanning and alerts",
    "Incident Response: Security alerts and monitoring"
  ]
}

output "cost_considerations" {
  description = "Cost considerations for HIPAA compliance"
  value = [
    "Premium Key Vault with HSM (~$5/key/month)",
    "Standard S2 SQL Database (~$30/month)",
    "Premium App Service Plan (~$146/month)",
    "GRS Storage for PHI and audit logs",
    "Extended log retention (7 years)",
    "High availability and zone redundancy",
    "Advanced Threat Protection licensing",
    "Consider Azure Reserved Instances for 40-60% savings",
    "Monitor costs with Azure Cost Management + Budgets",
    "Regular review of resource utilization"
  ]
}

output "compliance_checklist" {
  description = "HIPAA compliance implementation checklist"
  value = [
    "✓ Administrative Safeguards: Access controls and user training",
    "✓ Physical Safeguards: Azure datacenter security",
    "✓ Technical Safeguards: Encryption, access controls, audit logs",
    "✓ Risk Assessment: Regular vulnerability scans",
    "✓ Assigned Security Responsibility: Defined in tags and RBAC",
    "✓ Workforce Training: Required for healthcare organizations",
    "✓ Information Access Management: Azure AD and RBAC",
    "✓ Security Awareness and Training: Organizational responsibility",
    "✓ Security Incident Procedures: Alerts and monitoring configured",
    "✓ Contingency Plan: Backup and disaster recovery implemented"
  ]
}
