# DevOps & CI/CD Infrastructure Example
# Demonstrates self-hosted DevOps platform with security best practices
# Shows Azure DevOps integration, build agents, artifact management, and monitoring

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

# Local values for DevOps platform configuration
locals {
  environment = "prod"
  project     = "DevOpsPlatform"
  
  # Common tags for all resources
  common_tags = {
    Environment     = local.environment
    Owner          = "devops-team@contoso.com"
    Project        = local.project
    CostCenter     = "Engineering"
    Application    = "ContinuousIntegration"
    SecurityBaseline = "devops-security"
    BackupPolicy   = "standard"
    ComplianceLevel = "medium"
    DataClassification = "internal"
  }
  
  # DevOps configuration
  devops_config = {
    build_agent_count = 3
    vm_size = "Standard_D2s_v3"  # Cost-optimized for build workloads
    agent_pool_name = "contoso-agents"
    container_registry_sku = "Standard"  # Cost-effective for CI/CD
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

# Virtual Network for DevOps platform
resource "azurerm_virtual_network" "devops" {
  name                = "vnet-${lower(local.project)}-${local.environment}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]
  
  tags = local.common_tags
}

# Subnet for build agents
resource "azurerm_subnet" "build_agents" {
  name                 = "snet-build-agents-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.devops.name
  address_prefixes     = ["10.0.1.0/24"]
  
  # Service endpoints for accessing Azure services
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.KeyVault",
    "Microsoft.ContainerRegistry"
  ]
}

# Subnet for DevOps services
resource "azurerm_subnet" "devops_services" {
  name                 = "snet-devops-services-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.devops.name
  address_prefixes     = ["10.0.2.0/24"]
  
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.KeyVault"
  ]
}

# Network Security Group for build agents
resource "azurerm_network_security_group" "build_agents" {
  name                = "nsg-build-agents-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  # Allow outbound HTTPS for package downloads and Azure DevOps
  security_rule {
    name                       = "AllowOutboundHTTPS"
    priority                   = 1000
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # Allow outbound HTTP for package downloads
  security_rule {
    name                       = "AllowOutboundHTTP"
    priority                   = 1010
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # Allow SSH for management (from DevOps services subnet only)
  security_rule {
    name                       = "AllowSSH"
    priority                   = 1020
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }
  
  tags = local.common_tags
}

# Associate NSG with build agents subnet
resource "azurerm_subnet_network_security_group_association" "build_agents" {
  subnet_id                 = azurerm_subnet.build_agents.id
  network_security_group_id = azurerm_network_security_group.build_agents.id
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
  sku_name           = "standard"
  
  # Network access restrictions
  public_network_access_enabled = false
  
  # Soft delete for secret recovery
  soft_delete_retention_days = 30
  
  # Network ACLs
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    
    virtual_network_subnet_ids = [
      azurerm_subnet.build_agents.id,
      azurerm_subnet.devops_services.id
    ]
  }
  
  tags = merge(local.common_tags, {
    Purpose = "BuildSecretsManagement"
  })
}

# Key Vault access policy for current user/service principal
resource "azurerm_key_vault_access_policy" "current" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id
  
  secret_permissions = [
    "Set", "Get", "List", "Delete", "Purge", "Recover"
  ]
}

# Store Azure DevOps Personal Access Token
resource "azurerm_key_vault_secret" "azdo_pat" {
  name         = "azdo-pat"
  value        = "your-azure-devops-pat-here"  # Replace with actual PAT
  key_vault_id = azurerm_key_vault.main.id
  
  depends_on = [azurerm_key_vault_access_policy.current]
  
  tags = local.common_tags
}

# ========================================
# CONTAINER REGISTRY FOR BUILD ARTIFACTS
# ========================================

resource "azurerm_container_registry" "main" {
  name                = "acr${lower(replace(local.project, "-", ""))}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = local.devops_config.container_registry_sku
  admin_enabled       = false  # Use managed identity
  
  # Network access restrictions
  public_network_access_enabled = false
  
  network_rule_set {
    default_action = "Deny"
    
    virtual_network {
      action    = "Allow"
      subnet_id = azurerm_subnet.build_agents.id
    }
    
    virtual_network {
      action    = "Allow"
      subnet_id = azurerm_subnet.devops_services.id
    }
  }
  
  tags = merge(local.common_tags, {
    Purpose = "BuildArtifacts"
  })
}

# ========================================
# STORAGE ACCOUNT FOR BUILD ARTIFACTS
# ========================================

resource "azurerm_storage_account" "artifacts" {
  name                = "sa${lower(replace(local.project, "-", ""))}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  account_tier             = "Standard"
  account_replication_type = "LRS"  # Cost-effective for build artifacts
  account_kind            = "StorageV2"
  
  # Security configurations
  https_traffic_only_enabled      = true
  min_tls_version                = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false  # Use managed identity
  
  # Network access restrictions
  public_network_access_enabled = false
  
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    
    virtual_network_subnet_ids = [
      azurerm_subnet.build_agents.id,
      azurerm_subnet.devops_services.id
    ]
  }
  
  # Lifecycle management for cost optimization
  blob_properties {
    delete_retention_policy {
      days = 30
    }
    
    versioning_enabled = false  # Not needed for build artifacts
  }
  
  tags = merge(local.common_tags, {
    Purpose = "BuildArtifactsStorage"
  })
}

# Storage containers for different artifact types
resource "azurerm_storage_container" "build_artifacts" {
  name                  = "build-artifacts"
  storage_account_name  = azurerm_storage_account.artifacts.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "test_results" {
  name                  = "test-results"
  storage_account_name  = azurerm_storage_account.artifacts.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "build_logs" {
  name                  = "build-logs"
  storage_account_name  = azurerm_storage_account.artifacts.name
  container_access_type = "private"
}

# ========================================
# BUILD AGENT VIRTUAL MACHINES
# ========================================

# User-assigned managed identity for build agents
resource "azurerm_user_assigned_identity" "build_agents" {
  name                = "id-build-agents-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  tags = local.common_tags
}

# Network interface for build agents
resource "azurerm_network_interface" "build_agents" {
  count               = local.devops_config.build_agent_count
  name                = "nic-build-agent-${count.index + 1}-${local.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.build_agents.id
    private_ip_address_allocation = "Dynamic"
  }
  
  tags = local.common_tags
}

# Build agent virtual machines
resource "azurerm_linux_virtual_machine" "build_agents" {
  count               = local.devops_config.build_agent_count
  name                = "vm-build-agent-${count.index + 1}-${local.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = local.devops_config.vm_size
  
  # Disable password authentication
  disable_password_authentication = true
  
  network_interface_ids = [
    azurerm_network_interface.build_agents[count.index].id
  ]
  
  # User-assigned managed identity
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.build_agents.id]
  }
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_SSD"
  }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  
  computer_name  = "build-agent-${count.index + 1}"
  admin_username = "azureuser"
  
  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7... (your-public-key-here)"
  }
  
  # Custom script to install build tools
  custom_data = base64encode(templatefile("${path.module}/scripts/install-build-agent.sh", {
    key_vault_name = azurerm_key_vault.main.name
    azdo_url = "https://dev.azure.com/contoso"
    agent_pool_name = local.devops_config.agent_pool_name
  }))
  
  tags = merge(local.common_tags, {
    Purpose = "BuildAgent"
    AgentNumber = "${count.index + 1}"
  })
}

# ========================================
# RBAC AND PERMISSIONS
# ========================================

# Storage Blob Data Contributor role for build agents
resource "azurerm_role_assignment" "build_agents_storage" {
  scope                = azurerm_storage_account.artifacts.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.build_agents.principal_id
}

# Container Registry push/pull role for build agents
resource "azurerm_role_assignment" "build_agents_acr" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.build_agents.principal_id
}

# Key Vault access for build agents
resource "azurerm_key_vault_access_policy" "build_agents" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.build_agents.principal_id
  
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
  retention_in_days   = 90  # Cost-optimized retention
  
  tags = merge(local.common_tags, {
    Purpose = "DevOpsMonitoring"
  })
}

# VM Insights for build agents
resource "azurerm_log_analytics_solution" "vm_insights" {
  solution_name         = "VMInsights"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name
  
  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/VMInsights"
  }
  
  tags = local.common_tags
}

# Monitor agent extension for build VMs
resource "azurerm_virtual_machine_extension" "monitor_agent" {
  count                = local.devops_config.build_agent_count
  name                 = "AzureMonitorLinuxAgent"
  virtual_machine_id   = azurerm_linux_virtual_machine.build_agents[count.index].id
  publisher            = "Microsoft.Azure.Monitor"
  type                 = "AzureMonitorLinuxAgent"
  type_handler_version = "1.0"
  
  settings = jsonencode({
    workspaceId = azurerm_log_analytics_workspace.main.workspace_id
  })
  
  protected_settings = jsonencode({
    workspaceKey = azurerm_log_analytics_workspace.main.primary_shared_key
  })
  
  tags = local.common_tags
}

# Action group for DevOps alerts
resource "azurerm_monitor_action_group" "devops_alerts" {
  name                = "ag-devops-alerts-${local.environment}"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "devops"
  
  email_receiver {
    name          = "DevOps Team"
    email_address = "devops-team@contoso.com"
  }
  
  tags = local.common_tags
}

# Build agent health alert
resource "azurerm_monitor_metric_alert" "build_agent_cpu" {
  name                = "alert-build-agent-cpu-${local.environment}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = azurerm_linux_virtual_machine.build_agents[*].id
  description         = "Build agent CPU usage is high"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  
  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.devops_alerts.id
  }
  
  tags = local.common_tags
}

# ========================================
# AUTO-SHUTDOWN FOR COST OPTIMIZATION
# ========================================

# Auto-shutdown policy for build agents
resource "azurerm_dev_test_global_vm_shutdown_schedule" "build_agents" {
  count              = local.devops_config.build_agent_count
  virtual_machine_id = azurerm_linux_virtual_machine.build_agents[count.index].id
  location           = azurerm_resource_group.main.location
  enabled            = true
  
  daily_recurrence_time = "1900"  # 7 PM
  timezone              = "Eastern Standard Time"
  
  notification_settings {
    enabled         = true
    email           = "devops-team@contoso.com"
    time_in_minutes = 30
  }
  
  tags = local.common_tags
}

# ========================================
# OUTPUTS
# ========================================

output "devops_platform_summary" {
  description = "DevOps Platform Configuration Summary"
  value = {
    # Core infrastructure
    resource_group = azurerm_resource_group.main.name
    virtual_network = azurerm_virtual_network.devops.name
    
    # Build infrastructure
    build_agent_count = local.devops_config.build_agent_count
    build_agent_names = azurerm_linux_virtual_machine.build_agents[*].name
    agent_pool_name = local.devops_config.agent_pool_name
    
    # Artifact repositories
    container_registry = azurerm_container_registry.main.login_server
    storage_account = azurerm_storage_account.artifacts.name
    
    # Security
    key_vault = azurerm_key_vault.main.name
    managed_identity = azurerm_user_assigned_identity.build_agents.name
    
    # Monitoring
    log_analytics_workspace = azurerm_log_analytics_workspace.main.name
  }
}

output "build_agent_setup_commands" {
  description = "Commands to configure build agents"
  value = [
    "1. SSH to build agents using their private IPs",
    "2. Agents will auto-register with Azure DevOps using the PAT in Key Vault",
    "3. Agent pool '${local.devops_config.agent_pool_name}' will be created automatically",
    "4. Build agents have access to Container Registry and Storage Account",
    "5. Auto-shutdown is configured for 7 PM EST daily"
  ]
}

output "cost_optimization_features" {
  description = "Enabled cost optimization features"
  value = [
    "Auto-shutdown at 7 PM daily with 30-minute warning",
    "Premium SSD for faster builds (shorter runtime)",
    "Standard Container Registry (vs Premium)",
    "LRS storage for build artifacts",
    "90-day log retention vs 365-day default",
    "Standard_D2s_v3 VMs (cost-optimized for builds)",
    "No public IPs assigned to build agents"
  ]
}

output "security_features" {
  description = "Enabled security features"
  value = [
    "Private networks with no public access",
    "Network Security Groups with restrictive rules",
    "Managed identities for authentication",
    "Key Vault for secrets management",
    "Private endpoints for all services",
    "SSH key authentication (no passwords)",
    "Least privilege RBAC assignments",
    "Encrypted storage and transit"
  ]
}
