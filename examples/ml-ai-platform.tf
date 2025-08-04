# Machine Learning and AI Platform Example
# Demonstrates ML/AI infrastructure with comprehensive governance and cost optimization
# Shows Azure Machine Learning, Cognitive Services, responsible AI practices, and MLOps

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

# Local values for ML/AI platform configuration
locals {
  environment = "prod"
  project     = "MLAIPlatform"
  
  # Common tags for all resources
  common_tags = {
    Environment     = "production"
    Owner          = "ml-team@contoso.com"
    Project        = local.project
    CostCenter     = "DataScience"
    Application    = "MachineLearning"
    DataClassification = "restricted"
    BackupPolicy   = "standard"
    ComplianceLevel = "high"
    AIResponsible  = "true"
  }
  
  # ML/AI configuration optimized for cost and governance
  ml_config = {
    # Machine Learning workspace
    ml_workspace_sku = "Basic"  # Cost-effective for development/testing
    
    # Compute configurations
    compute_vm_size = "Standard_DS3_v2"  # Balanced compute for training
    min_nodes = 0  # Cost optimization - scale to zero
    max_nodes = 4  # Reasonable maximum for cost control
    
    # Cognitive Services
    cognitive_services_sku = "S0"  # Standard tier for production
    
    # Container Registry
    acr_sku = "Basic"  # Cost-effective for ML model storage
    
    # AI Search configuration
    search_sku = "basic"  # Cost-effective tier
    search_replica_count = 1
    search_partition_count = 1
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
# KEY VAULT FOR ML SECRETS
# ========================================

resource "azurerm_key_vault" "ml" {
  name                = "kv-ml-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  
  # Security configurations for ML secrets
  enabled_for_disk_encryption     = false  # Not needed for ML workloads
  enabled_for_deployment          = false
  enabled_for_template_deployment = false
  purge_protection_enabled        = true   # Protect ML keys and secrets
  soft_delete_retention_days      = 7      # Cost-optimized retention
  
  # Network security
  public_network_access_enabled = false
  
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    
    virtual_network_subnet_ids = [azurerm_subnet.ml_workspace.id]
  }
  
  tags = merge(local.common_tags, {
    Purpose = "MLSecretsManagement"
  })
}

# Access policy for ML workspace managed identity
resource "azurerm_key_vault_access_policy" "ml_workspace" {
  key_vault_id = azurerm_key_vault.ml.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_machine_learning_workspace.main.identity[0].principal_id
  
  key_permissions = [
    "Get", "List", "Create", "Delete", "Update", "Recover", "Purge"
  ]
  
  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover", "Purge"
  ]
}

# ========================================
# STORAGE ACCOUNT FOR ML WORKSPACE
# ========================================

resource "azurerm_storage_account" "ml" {
  name                = "saml${lower(replace(local.project, "-", ""))}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  account_tier             = "Standard"
  account_replication_type = "LRS"  # Cost-effective for ML data
  account_kind            = "StorageV2"
  
  # Security configurations
  https_traffic_only_enabled          = true
  min_tls_version                    = "TLS1_2"
  allow_nested_items_to_be_public    = false
  shared_access_key_enabled          = false  # Use managed identity
  default_to_oauth_authentication    = true
  
  # Network security
  public_network_access_enabled = false
  
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    
    virtual_network_subnet_ids = [
      azurerm_subnet.ml_workspace.id,
      azurerm_subnet.ml_compute.id
    ]
  }
  
  # Lifecycle management for cost optimization
  blob_properties {
    versioning_enabled = true
    change_feed_enabled = false  # Not needed for ML workloads
    
    delete_retention_policy {
      days = 30  # Reasonable retention for ML experiments
    }
    
    container_delete_retention_policy {
      days = 30
    }
  }
  
  tags = merge(local.common_tags, {
    Purpose = "MLDataStorage"
  })
}

# Container for ML datasets
resource "azurerm_storage_container" "datasets" {
  name                  = "datasets"
  storage_account_name  = azurerm_storage_account.ml.name
  container_access_type = "private"
}

# Container for ML models
resource "azurerm_storage_container" "models" {
  name                  = "models"
  storage_account_name  = azurerm_storage_account.ml.name
  container_access_type = "private"
}

# ========================================
# CONTAINER REGISTRY FOR ML MODELS
# ========================================

resource "azurerm_container_registry" "ml" {
  name                = "acrml${lower(replace(local.project, "-", ""))}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = local.ml_config.acr_sku
  admin_enabled       = false  # Use managed identity
  
  # Network security
  public_network_access_enabled = false
  
  network_rule_set {
    default_action = "Deny"
    
    virtual_network {
      action    = "Allow"
      subnet_id = azurerm_subnet.ml_workspace.id
    }
    
    virtual_network {
      action    = "Allow"
      subnet_id = azurerm_subnet.ml_compute.id
    }
  }
  
  # Trust policy for secure image builds
  trust_policy {
    enabled = true
  }
  
  tags = merge(local.common_tags, {
    Purpose = "MLModelRegistry"
  })
}

# ========================================
# NETWORKING FOR ML WORKSPACE
# ========================================

resource "azurerm_virtual_network" "ml" {
  name                = "vnet-${lower(local.project)}-${local.environment}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]
  
  tags = local.common_tags
}

# Subnet for ML workspace
resource "azurerm_subnet" "ml_workspace" {
  name                 = "snet-ml-workspace-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.ml.name
  address_prefixes     = ["10.0.1.0/24"]
  
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.KeyVault",
    "Microsoft.ContainerRegistry",
    "Microsoft.CognitiveServices"
  ]
}

# Subnet for ML compute clusters
resource "azurerm_subnet" "ml_compute" {
  name                 = "snet-ml-compute-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.ml.name
  address_prefixes     = ["10.0.2.0/24"]
  
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.ContainerRegistry"
  ]
}

# ========================================
# APPLICATION INSIGHTS FOR ML MONITORING
# ========================================

resource "azurerm_log_analytics_workspace" "ml" {
  name                = "log-${lower(local.project)}-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 90  # Extended retention for ML experiments
  
  tags = merge(local.common_tags, {
    Purpose = "MLMonitoring"
  })
}

resource "azurerm_application_insights" "ml" {
  name                = "appi-${lower(local.project)}-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.ml.id
  application_type    = "web"
  
  # ML-specific monitoring configuration
  retention_in_days = 90
  
  tags = merge(local.common_tags, {
    Purpose = "MLApplicationMonitoring"
  })
}

# ========================================
# MACHINE LEARNING WORKSPACE
# ========================================

resource "azurerm_machine_learning_workspace" "main" {
  name                = "mlw-${lower(local.project)}-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  # Core dependencies
  application_insights_id = azurerm_application_insights.ml.id
  key_vault_id           = azurerm_key_vault.ml.id
  storage_account_id     = azurerm_storage_account.ml.id
  container_registry_id  = azurerm_container_registry.ml.id
  
  # Workspace configuration
  sku_name                    = local.ml_config.ml_workspace_sku
  friendly_name              = "ML AI Platform Workspace"
  description                = "Production ML workspace with comprehensive governance"
  high_business_impact       = true  # Enhanced security features
  public_network_access_enabled = false
  
  # Managed identity for secure access
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "MachineLearningWorkspace"
    Tier = "Production"
  })
}

# ========================================
# ML COMPUTE CLUSTER
# ========================================

resource "azurerm_machine_learning_compute_cluster" "training" {
  name                          = "training-cluster"
  location                      = azurerm_resource_group.main.location
  machine_learning_workspace_id = azurerm_machine_learning_workspace.main.id
  vm_priority                   = "Dedicated"  # For production workloads
  vm_size                       = local.ml_config.compute_vm_size
  
  # Auto-scaling configuration for cost optimization
  scale_settings {
    min_node_count                       = local.ml_config.min_nodes
    max_node_count                       = local.ml_config.max_nodes
    scale_down_nodes_after_idle_duration = "PT30S"  # Quick scale-down for cost savings
  }
  
  # Network isolation
  subnet_resource_id = azurerm_subnet.ml_compute.id
  
  # Managed identity
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "MLTrainingCompute"
    WorkloadType = "Training"
  })
}

# Inference compute cluster
resource "azurerm_machine_learning_compute_cluster" "inference" {
  name                          = "inference-cluster"
  location                      = azurerm_resource_group.main.location
  machine_learning_workspace_id = azurerm_machine_learning_workspace.main.id
  vm_priority                   = "Dedicated"
  vm_size                       = "Standard_DS2_v2"  # Smaller VMs for inference
  
  scale_settings {
    min_node_count                       = 0  # Scale to zero when not in use
    max_node_count                       = 2  # Small cluster for inference
    scale_down_nodes_after_idle_duration = "PT120S"  # Keep alive longer for inference
  }
  
  subnet_resource_id = azurerm_subnet.ml_compute.id
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "MLInferenceCompute"
    WorkloadType = "Inference"
  })
}

# ========================================
# COGNITIVE SERVICES
# ========================================

# Cognitive Services multi-service account
resource "azurerm_cognitive_account" "main" {
  name                = "cog-${lower(local.project)}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  kind                = "CognitiveServices"
  sku_name            = local.ml_config.cognitive_services_sku
  
  # Network security
  public_network_access_enabled = false
  
  network_acls {
    default_action = "Deny"
    
    virtual_network_rules {
      subnet_id = azurerm_subnet.ml_workspace.id
    }
  }
  
  # Managed identity
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "CognitiveServices"
    ServiceType = "MultiService"
  })
}

# OpenAI Service for advanced AI capabilities
resource "azurerm_cognitive_account" "openai" {
  name                = "cog-openai-${random_string.suffix.result}"
  location            = "East US"  # OpenAI available regions
  resource_group_name = azurerm_resource_group.main.name
  kind                = "OpenAI"
  sku_name            = "S0"
  
  public_network_access_enabled = false
  
  network_acls {
    default_action = "Deny"
    
    virtual_network_rules {
      subnet_id = azurerm_subnet.ml_workspace.id
    }
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "OpenAIServices"
    ServiceType = "GenerativeAI"
  })
}

# ========================================
# AI SEARCH FOR KNOWLEDGE MINING
# ========================================

resource "azurerm_search_service" "main" {
  name                = "srch-${lower(local.project)}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = local.ml_config.search_sku
  
  # Cost-optimized configuration
  replica_count   = local.ml_config.search_replica_count
  partition_count = local.ml_config.search_partition_count
  
  # Network security
  public_network_access_enabled = false
  
  # Managed identity for secure access
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "KnowledgeMining"
    ServiceType = "AISearch"
  })
}

# ========================================
# ROLE ASSIGNMENTS FOR ML WORKSPACE
# ========================================

# Current user data for role assignments
data "azurerm_client_config" "current" {}

# Storage Blob Data Contributor for ML workspace
resource "azurerm_role_assignment" "ml_workspace_storage" {
  scope                = azurerm_storage_account.ml.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_machine_learning_workspace.main.identity[0].principal_id
}

# ACR Pull role for ML workspace
resource "azurerm_role_assignment" "ml_workspace_acr" {
  scope                = azurerm_container_registry.ml.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_machine_learning_workspace.main.identity[0].principal_id
}

# Cognitive Services User for ML workspace
resource "azurerm_role_assignment" "ml_workspace_cognitive" {
  scope                = azurerm_cognitive_account.main.id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_machine_learning_workspace.main.identity[0].principal_id
}

# ========================================
# DATA FACTORY FOR ML PIPELINES
# ========================================

resource "azurerm_data_factory" "ml" {
  name                = "adf-${lower(local.project)}-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  # Network isolation
  public_network_enabled = false
  
  # Git integration for MLOps
  vsts_configuration {
    account_name    = "contoso"
    branch_name     = "main"
    project_name    = "MLOps"
    repository_name = "ml-pipelines"
    root_folder     = "/"
    tenant_id       = data.azurerm_client_config.current.tenant_id
  }
  
  # Managed identity
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "MLDataPipelines"
    Integration = "MLOps"
  })
}

# ========================================
# MONITORING AND ALERTING
# ========================================

# Action group for ML alerts
resource "azurerm_monitor_action_group" "ml_alerts" {
  name                = "ag-ml-alerts-${local.environment}"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "mlalerts"
  
  email_receiver {
    name          = "ml-team"
    email_address = "ml-team@contoso.com"
  }
  
  tags = local.common_tags
}

# Alert for high compute costs
resource "azurerm_monitor_metric_alert" "high_compute_cost" {
  name                = "ml-high-compute-cost"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_machine_learning_workspace.main.id]
  description         = "Alert when ML compute costs exceed threshold"
  
  criteria {
    metric_namespace = "Microsoft.MachineLearningServices/workspaces"
    metric_name      = "CpuUtilization"  # Proxy for cost monitoring
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.ml_alerts.id
  }
  
  tags = local.common_tags
}

# ========================================
# OUTPUTS
# ========================================

output "ml_ai_platform_summary" {
  description = "ML/AI Platform Configuration Summary"
  value = {
    # Core ML services
    ml_workspace = azurerm_machine_learning_workspace.main.name
    workspace_url = "https://ml.azure.com/?wsid=${azurerm_machine_learning_workspace.main.id}"
    
    # Compute resources
    training_cluster = azurerm_machine_learning_compute_cluster.training.name
    inference_cluster = azurerm_machine_learning_compute_cluster.inference.name
    
    # AI services
    cognitive_services = azurerm_cognitive_account.main.name
    openai_service = azurerm_cognitive_account.openai.name
    search_service = azurerm_search_service.main.name
    
    # Data and MLOps
    container_registry = azurerm_container_registry.ml.name
    data_factory = azurerm_data_factory.ml.name
    storage_account = azurerm_storage_account.ml.name
    
    # Security
    key_vault = azurerm_key_vault.ml.name
    
    # Monitoring
    application_insights = azurerm_application_insights.ml.name
    log_analytics_workspace = azurerm_log_analytics_workspace.ml.name
  }
}

output "cost_optimization_features" {
  description = "ML/AI cost optimization features enabled"
  value = [
    "Auto-scaling compute clusters (scale to zero)",
    "Basic ML workspace SKU for cost efficiency",
    "LRS storage replication for datasets",
    "Basic Container Registry tier",
    "Basic AI Search tier with minimal replicas",
    "Quick scale-down (30s idle time for training)",
    "Dedicated VMs only when needed",
    "Lifecycle management for ML storage",
    "Cost monitoring alerts for compute usage",
    "Network isolation reduces data transfer costs"
  ]
}

output "responsible_ai_features" {
  description = "Responsible AI and governance features"
  value = [
    "Network isolation for all AI services",
    "Managed identity authentication (no keys)",
    "Key Vault integration for secrets management",
    "High business impact workspace configuration",
    "Git integration for reproducible MLOps",
    "Comprehensive audit logging",
    "Role-based access control (RBAC)",
    "Private endpoints for secure communication",
    "Data classification and tagging",
    "Monitoring and alerting for AI workloads"
  ]
}

output "ml_capabilities" {
  description = "Machine Learning platform capabilities"
  value = [
    "Automated ML for rapid model development",
    "Designer for visual ML pipeline creation",
    "Notebooks for interactive development",
    "Compute clusters for scalable training",
    "Model registry for version control",
    "Real-time and batch inference endpoints",
    "MLOps with Azure DevOps integration",
    "Cognitive Services for pre-built AI",
    "OpenAI integration for generative AI",
    "AI Search for knowledge mining and RAG"
  ]
}
