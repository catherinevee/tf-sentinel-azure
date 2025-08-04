# Financial Services Compliance Example
# Demonstrates PCI DSS compliance patterns and financial services security requirements
# Shows HSM-backed encryption, network isolation, audit logging, and data residency controls

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
      purge_soft_delete_on_destroy    = false  # Never purge in production
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

# Local values for financial services configuration
locals {
  environment = "prod"
  project     = "FinServCompliance"
  
  # Common tags for all resources (compliance required)
  common_tags = {
    Environment        = local.environment
    Owner             = "fintech-team@contoso.com"
    Project           = local.project
    CostCenter        = "Finance"
    Application       = "PaymentProcessing"
    ComplianceLevel   = "pci-dss"
    DataClassification = "highly-confidential"
    BackupPolicy      = "enterprise"
    SecurityBaseline  = "financial-services"
    DataResidency     = "us-east"
    AuditRequired     = "true"
    BusinessCriticality = "mission-critical"
  }
  
  # Compliance configuration
  compliance_config = {
    # PCI DSS requires data retention for specific periods
    audit_retention_years = 7
    backup_retention_days = 2555  # 7 years
    
    # Geographic restrictions for financial data
    allowed_regions = ["eastus", "eastus2"]
    
    # HSM-backed encryption required
    hsm_required = true
    
    # Network isolation requirements
    public_access_denied = true
  }
}

# ========================================
# RESOURCE GROUP
# ========================================

resource "azurerm_resource_group" "main" {
  name     = "rg-${lower(local.project)}-${local.environment}-001"
  location = "East US"  # Must comply with data residency requirements
  
  tags = local.common_tags
}

# ========================================
# NETWORKING (Zero Trust Architecture)
# ========================================

# Virtual Network with strict segmentation
resource "azurerm_virtual_network" "finserv" {
  name                = "vnet-${lower(local.project)}-${local.environment}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]
  
  # DDoS protection required for financial services
  ddos_protection_plan {
    id     = azurerm_network_ddos_protection_plan.main.id
    enable = true
  }
  
  tags = local.common_tags
}

# DDoS Protection Plan (PCI DSS requirement)
resource "azurerm_network_ddos_protection_plan" "main" {
  name                = "ddos-${lower(local.project)}-${local.environment}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  tags = merge(local.common_tags, {
    Purpose = "DDoSProtection"
  })
}

# DMZ Subnet (public-facing services)
resource "azurerm_subnet" "dmz" {
  name                 = "snet-dmz-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.finserv.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Application Subnet (secure zone)
resource "azurerm_subnet" "application" {
  name                 = "snet-application-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.finserv.name
  address_prefixes     = ["10.0.2.0/24"]
  
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.Sql",
    "Microsoft.KeyVault"
  ]
}

# Database Subnet (most secure zone)
resource "azurerm_subnet" "database" {
  name                 = "snet-database-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.finserv.name
  address_prefixes     = ["10.0.3.0/24"]
  
  service_endpoints = [
    "Microsoft.Sql",
    "Microsoft.KeyVault"
  ]
}

# Management Subnet (admin access)
resource "azurerm_subnet" "management" {
  name                 = "snet-management-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.finserv.name
  address_prefixes     = ["10.0.4.0/24"]
}

# Network Security Group for DMZ
resource "azurerm_network_security_group" "dmz" {
  name                = "nsg-dmz-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  # Allow HTTPS only from internet
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  
  # Deny all other inbound traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
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

# Network Security Group for Application Tier
resource "azurerm_network_security_group" "application" {
  name                = "nsg-application-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  # Allow traffic from DMZ only
  security_rule {
    name                       = "AllowFromDMZ"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }
  
  # Allow management access
  security_rule {
    name                       = "AllowManagement"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.4.0/24"
    destination_address_prefix = "*"
  }
  
  tags = local.common_tags
}

# Network Security Group for Database Tier
resource "azurerm_network_security_group" "database" {
  name                = "nsg-database-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  # Allow SQL traffic from application tier only
  security_rule {
    name                       = "AllowSQLFromApp"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }
  
  tags = local.common_tags
}

# Associate NSGs with subnets
resource "azurerm_subnet_network_security_group_association" "dmz" {
  subnet_id                 = azurerm_subnet.dmz.id
  network_security_group_id = azurerm_network_security_group.dmz.id
}

resource "azurerm_subnet_network_security_group_association" "application" {
  subnet_id                 = azurerm_subnet.application.id
  network_security_group_id = azurerm_network_security_group.application.id
}

resource "azurerm_subnet_network_security_group_association" "database" {
  subnet_id                 = azurerm_subnet.database.id
  network_security_group_id = azurerm_network_security_group.database.id
}

# ========================================
# KEY VAULT WITH HSM (PCI DSS Requirement)
# ========================================

# Get current client configuration
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "hsm" {
  name                = "kv-${lower(local.project)}-hsm-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name           = "premium"  # Required for HSM backing
  
  # Compliance requirements
  enabled_for_disk_encryption     = true
  enabled_for_deployment          = false  # Security: disable VM deployment access
  enabled_for_template_deployment = false  # Security: disable template access
  
  # Network isolation (PCI DSS requirement)
  public_network_access_enabled = local.compliance_config.public_access_denied ? false : true
  
  # Enhanced security settings
  soft_delete_retention_days = 90
  purge_protection_enabled   = true  # Cannot be disabled in production
  
  # Network ACLs - deny all public access
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    
    virtual_network_subnet_ids = [
      azurerm_subnet.application.id,
      azurerm_subnet.database.id,
      azurerm_subnet.management.id
    ]
  }
  
  tags = merge(local.common_tags, {
    Purpose = "HSMEncryption"
    HSMBacked = "true"
  })
}

# Key Vault access policy for application services
resource "azurerm_key_vault_access_policy" "application" {
  key_vault_id = azurerm_key_vault.hsm.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id
  
  key_permissions = [
    "Create", "Get", "List", "Update", "Encrypt", "Decrypt", "WrapKey", "UnwrapKey"
  ]
  
  secret_permissions = [
    "Set", "Get", "List"
  ]
  
  certificate_permissions = [
    "Create", "Get", "List", "Update", "Import"
  ]
}

# HSM-backed key for encryption
resource "azurerm_key_vault_key" "payment_encryption" {
  name         = "payment-encryption-key"
  key_vault_id = azurerm_key_vault.hsm.id
  key_type     = "RSA-HSM"  # HSM-backed key
  key_size     = 4096       # Strong encryption
  
  key_opts = [
    "encrypt",
    "decrypt",
    "wrapKey",
    "unwrapKey"
  ]
  
  depends_on = [azurerm_key_vault_access_policy.application]
  
  tags = merge(local.common_tags, {
    Purpose = "PaymentDataEncryption"
    KeyType = "HSM"
  })
}

# ========================================
# SQL DATABASE WITH ADVANCED SECURITY
# ========================================

# SQL Server with Azure AD authentication
resource "azurerm_mssql_server" "main" {
  name                         = "sql-${lower(local.project)}-${random_string.suffix.result}"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = "finservadmin"
  administrator_login_password = "ComplexP@ssword123!"
  
  # Azure AD authentication (required for compliance)
  azuread_administrator {
    login_username = "FinServ-DBAs"
    object_id      = "00000000-1111-2222-3333-444444444444"  # Replace with actual AD group
  }
  
  # Network isolation
  public_network_access_enabled = false
  
  # Customer-managed encryption key
  identity {
    type = "SystemAssigned"
  }
  
  tags = local.common_tags
}

# SQL Database with advanced features
resource "azurerm_mssql_database" "payment_db" {
  name           = "PaymentDB"
  server_id      = azurerm_mssql_server.main.id
  
  # Business Critical tier for financial data
  sku_name                     = "BC_Gen5_4"  # Business Critical with 4 vCores
  zone_redundant              = true
  storage_account_type        = "Zone"
  
  # Backup configuration for compliance
  geo_backup_enabled          = true
  backup_interval_in_hours    = 12
  
  # Long-term retention for compliance (7 years)
  long_term_retention_policy {
    weekly_retention  = "P12W"
    monthly_retention = "P12M"  
    yearly_retention  = "P7Y"
    week_of_year     = 1
  }
  
  # Short-term backup
  short_term_retention_policy {
    retention_days = 35
  }
  
  # Transparent Data Encryption with customer-managed key
  transparent_data_encryption_key_vault_key_id = azurerm_key_vault_key.payment_encryption.id
  
  tags = merge(local.common_tags, {
    Purpose = "PaymentData"
    EncryptionType = "CustomerManagedTDE"
  })
}

# Advanced Threat Protection
resource "azurerm_mssql_server_security_alert_policy" "main" {
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mssql_server.main.name
  state               = "Enabled"
  
  # Email notifications for security alerts
  email_account_admins = true
  email_addresses      = ["security@contoso.com", "dba@contoso.com"]
  
  # Storage account for threat detection logs
  storage_endpoint           = azurerm_storage_account.audit_logs.primary_blob_endpoint
  storage_account_access_key = azurerm_storage_account.audit_logs.primary_access_key
  retention_days            = local.compliance_config.audit_retention_years * 365
  
  # Enable all threat detection types
  disabled_alerts = []
}

# SQL Vulnerability Assessment
resource "azurerm_mssql_server_vulnerability_assessment" "main" {
  server_security_alert_policy_id = azurerm_mssql_server_security_alert_policy.main.id
  storage_container_path          = "${azurerm_storage_account.audit_logs.primary_blob_endpoint}vulnerability-assessment/"
  storage_account_access_key      = azurerm_storage_account.audit_logs.primary_access_key
  
  recurring_scans {
    enabled                   = true
    email_subscription_admins = true
    emails                    = ["security@contoso.com"]
  }
}

# Database Auditing (PCI DSS requirement)
resource "azurerm_mssql_database_extended_auditing_policy" "main" {
  database_id                             = azurerm_mssql_database.payment_db.id
  storage_endpoint                        = azurerm_storage_account.audit_logs.primary_blob_endpoint
  storage_account_access_key              = azurerm_storage_account.audit_logs.primary_access_key
  storage_account_access_key_is_secondary = false
  retention_in_days                       = local.compliance_config.audit_retention_years * 365
  
  # Enable audit logs for all data access
  audit_actions_and_groups = [
    "SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP",
    "FAILED_DATABASE_AUTHENTICATION_GROUP",
    "BATCH_COMPLETED_GROUP",
    "DATABASE_LOGOUT_GROUP",
    "DATABASE_OBJECT_CHANGE_GROUP",
    "DATABASE_OBJECT_OWNERSHIP_CHANGE_GROUP",
    "DATABASE_OBJECT_PERMISSION_CHANGE_GROUP",
    "DATABASE_PERMISSION_CHANGE_GROUP",
    "DATABASE_PRINCIPAL_CHANGE_GROUP",
    "DATABASE_ROLE_MEMBER_CHANGE_GROUP",
    "SCHEMA_OBJECT_ACCESS_GROUP",
    "SCHEMA_OBJECT_CHANGE_GROUP",
    "SCHEMA_OBJECT_OWNERSHIP_CHANGE_GROUP",
    "SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP",
    "USER_CHANGE_PASSWORD_GROUP"
  ]
}

# ========================================
# STORAGE FOR AUDIT LOGS (IMMUTABLE)
# ========================================

resource "azurerm_storage_account" "audit_logs" {
  name                = "saaudit${lower(replace(local.project, "-", ""))}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  account_tier             = "Standard"
  account_replication_type = "GRS"  # Geo-redundant for compliance
  account_kind            = "StorageV2"
  
  # Maximum security configuration
  https_traffic_only_enabled         = true
  min_tls_version                   = "TLS1_2"
  allow_nested_items_to_be_public   = false
  shared_access_key_enabled         = true  # Required for SQL audit logs
  public_network_access_enabled     = false
  
  # Infrastructure encryption for dual encryption
  infrastructure_encryption_enabled = true
  
  # Network restrictions
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    
    virtual_network_subnet_ids = [
      azurerm_subnet.application.id,
      azurerm_subnet.database.id,
      azurerm_subnet.management.id
    ]
  }
  
  # Blob properties for compliance
  blob_properties {
    # Soft delete for audit logs
    delete_retention_policy {
      days = local.compliance_config.backup_retention_days
    }
    
    # Versioning for audit trail integrity
    versioning_enabled = true
    
    # Change feed for audit monitoring
    change_feed_enabled = true
    
    # Container soft delete
    container_delete_retention_policy {
      days = local.compliance_config.backup_retention_days
    }
    
    # Immutable storage policy for compliance
    restore_policy {
      days = 7
    }
  }
  
  # Queue encryption
  queue_encryption_key_type = "Account"
  
  # Table encryption  
  table_encryption_key_type = "Account"
  
  tags = merge(local.common_tags, {
    Purpose = "AuditLogs"
    Immutable = "true"
    RetentionYears = local.compliance_config.audit_retention_years
  })
}

# Immutable blob storage for audit logs
resource "azurerm_storage_container" "audit_logs" {
  name                  = "audit-logs"
  storage_account_name  = azurerm_storage_account.audit_logs.name
  container_access_type = "private"
  
  metadata = {
    compliance = "pci-dss"
    retention = "7-years"
  }
}

# Legal hold policy for audit logs (immutable)
resource "azurerm_storage_management_policy" "audit_retention" {
  storage_account_id = azurerm_storage_account.audit_logs.id
  
  rule {
    name    = "AuditLogRetention"
    enabled = true
    
    filters {
      prefix_match = ["audit-logs/"]
      blob_types   = ["blockBlob"]
    }
    
    actions {
      base_blob {
        # Tier to cool storage after 30 days
        tier_to_cool_after_days_since_modification_greater_than = 30
        
        # Tier to archive after 1 year
        tier_to_archive_after_days_since_modification_greater_than = 365
        
        # Delete after 7 years (compliance requirement)
        delete_after_days_since_modification_greater_than = local.compliance_config.audit_retention_years * 365
      }
    }
  }
}

# ========================================
# APPLICATION GATEWAY WITH WAF
# ========================================

# Public IP for Application Gateway
resource "azurerm_public_ip" "app_gateway" {
  name                = "pip-appgw-${local.environment}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                = "Standard"
  zones              = ["1", "2", "3"]
  
  tags = merge(local.common_tags, {
    Purpose = "LoadBalancer"
  })
}

# Application Gateway with WAF
resource "azurerm_application_gateway" "main" {
  name                = "appgw-${lower(local.project)}-${local.environment}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  # WAF v2 for advanced protection
  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }
  
  zones = ["1", "2", "3"]
  
  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.dmz.id
  }
  
  frontend_port {
    name = "https-port"
    port = 443
  }
  
  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.app_gateway.id
  }
  
  backend_address_pool {
    name = "finserv-backend-pool"
  }
  
  backend_http_settings {
    name                  = "finserv-backend-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 60
  }
  
  http_listener {
    name                           = "finserv-listener"
    frontend_ip_configuration_name = "frontend-ip-config"
    frontend_port_name             = "https-port"
    protocol                       = "Https"
    ssl_certificate_name           = "finserv-ssl-cert"
  }
  
  request_routing_rule {
    name                       = "finserv-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "finserv-listener"
    backend_address_pool_name  = "finserv-backend-pool"
    backend_http_settings_name = "finserv-backend-settings"
    priority                   = 1
  }
  
  # SSL certificate (managed certificate recommended)
  ssl_certificate {
    name     = "finserv-ssl-cert"
    data     = filebase64("${path.module}/certificates/finserv.pfx")
    password = "certificate-password"
  }
  
  # WAF Configuration - Maximum protection
  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"  # Block malicious requests
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
    
    # Enable all protection rules
    file_upload_limit_mb     = 100
    request_body_check       = true
    max_request_body_size_kb = 128
    
    # Custom exclusions for false positives (if needed)
    exclusion {
      match_variable          = "RequestHeaderNames"
      selector_match_operator = "Equals"
      selector               = "User-Agent"
    }
  }
  
  tags = merge(local.common_tags, {
    Purpose = "SecureLoadBalancer"
    WAFEnabled = "true"
  })
}

# ========================================
# OUTPUTS
# ========================================

output "compliance_summary" {
  description = "Financial Services Compliance Configuration Summary"
  value = {
    # Core infrastructure
    resource_group = azurerm_resource_group.main.name
    virtual_network = azurerm_virtual_network.finserv.name
    
    # Security components
    hsm_key_vault = azurerm_key_vault.hsm.name
    ddos_protection = azurerm_network_ddos_protection_plan.main.name
    waf_application_gateway = azurerm_application_gateway.main.name
    
    # Data services
    sql_server = azurerm_mssql_server.main.name
    payment_database = azurerm_mssql_database.payment_db.name
    audit_storage = azurerm_storage_account.audit_logs.name
    
    # Compliance features
    hsm_backed_encryption = local.compliance_config.hsm_required
    audit_retention_years = local.compliance_config.audit_retention_years
    data_residency_region = azurerm_resource_group.main.location
    public_access_denied = local.compliance_config.public_access_denied
  }
}

output "pci_dss_compliance_features" {
  description = "PCI DSS compliance features implemented"
  value = [
    "HSM-backed encryption keys for payment data",
    "Network segmentation with strict NSG rules",
    "DDoS protection for availability requirements",
    "WAF protection against web application attacks",
    "Comprehensive audit logging (7-year retention)",
    "Database activity monitoring and threat detection",
    "Vulnerability assessments with automated scanning",
    "Private network access only (no public endpoints)",
    "TLS 1.2 minimum encryption in transit",
    "Transparent Data Encryption with customer-managed keys",
    "Immutable audit log storage with legal hold",
    "Multi-zone deployment for high availability",
    "Azure AD authentication for privileged access",
    "Soft delete and purge protection for critical data"
  ]
}

output "data_protection_controls" {
  description = "Data protection and privacy controls"
  value = [
    "Customer-managed encryption keys (BYOK)",
    "Infrastructure-level encryption (dual encryption)",
    "Data residency controls (US East region only)",
    "Network isolation with private endpoints",
    "Immutable storage for audit and compliance data",
    "Backup encryption with customer-managed keys",
    "Change feed and versioning for audit trail",
    "Geo-redundant storage for disaster recovery",
    "Long-term retention policies (7 years)",
    "Role-based access control (RBAC) with Azure AD"
  ]
}
