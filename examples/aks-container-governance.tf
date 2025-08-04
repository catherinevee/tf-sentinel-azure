# Kubernetes & Container Orchestration Example
# Demonstrates enterprise AKS deployment with comprehensive policy compliance
# Shows container governance, cost optimization, and security best practices

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Local values for AKS configuration
locals {
  environment = "prod"
  project     = "ContainerPlatform"
  
  # Common tags for all resources
  common_tags = {
    Environment     = local.environment
    Owner          = "platform-team@contoso.com"
    Project        = local.project
    CostCenter     = "Platform"
    Application    = "KubernetesOrchestration"
    ContainerPlatform = "enabled"
    SecurityBaseline = "cis-kubernetes"
    BackupPolicy   = "standard"
    ComplianceLevel = "high"
    DataClassification = "internal"
  }
  
  # AKS configuration
  aks_config = {
    kubernetes_version = "1.28.5"
    node_count = 2
    min_node_count = 1
    max_node_count = 10
    vm_size = "Standard_D2s_v3"  # Cost-optimized general purpose
    spot_vm_size = "Standard_D2s_v3"
    max_spot_price = 0.05  # 50% of on-demand price
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

# Virtual Network for AKS
resource "azurerm_virtual_network" "aks" {
  name                = "vnet-${lower(local.project)}-${local.environment}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/8"]
  
  tags = local.common_tags
}

# AKS System Subnet
resource "azurerm_subnet" "aks_system" {
  name                 = "snet-aks-system-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = ["10.1.0.0/16"]
}

# AKS User Subnet  
resource "azurerm_subnet" "aks_user" {
  name                 = "snet-aks-user-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = ["10.2.0.0/16"]
}

# Application Gateway Subnet
resource "azurerm_subnet" "app_gateway" {
  name                 = "snet-appgw-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = ["10.3.0.0/24"]
}

# Network Security Group for AKS
resource "azurerm_network_security_group" "aks" {
  name                = "nsg-aks-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  # Allow HTTPS from Application Gateway
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.3.0.0/24"
    destination_address_prefix = "*"
  }
  
  # Allow Kubernetes API
  security_rule {
    name                       = "AllowKubernetesAPI"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
  
  tags = local.common_tags
}

# ========================================
# LOG ANALYTICS FOR CONTAINER INSIGHTS
# ========================================

resource "azurerm_log_analytics_workspace" "aks" {
  name                = "log-${lower(local.project)}-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 90  # Cost-optimized retention
  
  tags = merge(local.common_tags, {
    Purpose = "ContainerInsights"
  })
}

# ========================================
# CONTAINER REGISTRY
# ========================================

resource "azurerm_container_registry" "main" {
  name                = "acr${lower(replace(local.project, "-", ""))}${local.environment}001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Premium"  # Required for geo-replication and advanced features
  admin_enabled       = false      # Use managed identity instead
  
  # Enable vulnerability scanning
  public_network_access_enabled = false
  
  # Network rule to allow AKS access
  network_rule_set {
    default_action = "Deny"
    
    virtual_network {
      action    = "Allow"
      subnet_id = azurerm_subnet.aks_system.id
    }
    
    virtual_network {
      action    = "Allow"
      subnet_id = azurerm_subnet.aks_user.id
    }
  }
  
  # Geo-replication for disaster recovery
  georeplications {
    location                = "West US 2"
    zone_redundancy_enabled = true
    tags                   = local.common_tags
  }
  
  tags = merge(local.common_tags, {
    Purpose = "ContainerImages"
  })
}

# ========================================
# AKS CLUSTER
# ========================================

resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${lower(local.project)}-${local.environment}-001"
  location            = azurerm_resource_group.main.location  
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${lower(local.project)}-${local.environment}"
  
  kubernetes_version = local.aks_config.kubernetes_version
  
  # System node pool (required)
  default_node_pool {
    name                = "system"
    node_count         = local.aks_config.node_count
    vm_size            = local.aks_config.vm_size
    zones              = ["1", "2", "3"]  # Multi-zone for HA
    
    # Enable auto-scaling
    enable_auto_scaling = true
    min_count          = local.aks_config.min_node_count
    max_count          = local.aks_config.max_node_count
    
    # Networking
    vnet_subnet_id = azurerm_subnet.aks_system.id
    
    # Security
    only_critical_addons_enabled = true
    
    # OS disk optimization
    os_disk_type = "Ephemeral"
    os_disk_size_gb = 30
    
    upgrade_settings {
      max_surge = "33%"
    }
    
    tags = merge(local.common_tags, {
      Purpose = "SystemNodePool"
    })
  }
  
  # Managed identity for AKS
  identity {
    type = "SystemAssigned"
  }
  
  # Network profile
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"  # Enable network policies
    dns_service_ip    = "10.254.0.10"
    service_cidr      = "10.254.0.0/16"
    outbound_type     = "loadBalancer"
  }
  
  # Enable monitoring
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
  }
  
  # Enable Azure Policy for AKS
  azure_policy_enabled = true
  
  # Enable local accounts for emergency access
  local_account_disabled = false
  
  # Role-based access control
  role_based_access_control_enabled = true
  
  azure_active_directory_role_based_access_control {
    managed                = true
    tenant_id             = data.azurerm_client_config.current.tenant_id
    admin_group_object_ids = ["00000000-1111-2222-3333-444444444444"]  # Replace with actual AD group
    azure_rbac_enabled    = true
  }
  
  # API server access profile
  api_server_access_profile {
    vnet_integration_enabled = true
    subnet_id               = azurerm_subnet.aks_system.id
  }
  
  # Auto-upgrade channel
  automatic_channel_upgrade = "patch"
  
  tags = local.common_tags
}

# User node pool with spot instances for cost optimization
resource "azurerm_kubernetes_cluster_node_pool" "user_spot" {
  name                  = "spotuser"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size              = local.aks_config.spot_vm_size
  
  # Spot instance configuration
  priority        = "Spot"
  eviction_policy = "Delete"
  spot_max_price  = local.aks_config.max_spot_price
  
  # Auto-scaling
  enable_auto_scaling = true
  min_count          = 0
  max_count          = 5
  
  # Networking
  vnet_subnet_id = azurerm_subnet.aks_user.id
  zones          = ["1", "2", "3"]
  
  # Taints for spot instances
  node_taints = ["kubernetes.azure.com/scalesetpriority=spot:NoSchedule"]
  
  # OS optimization
  os_disk_type = "Ephemeral"
  os_disk_size_gb = 30
  
  upgrade_settings {
    max_surge = "33%"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "UserNodePoolSpot"
    CostOptimized = "true"
  })
}

# ========================================
# RBAC AND PERMISSIONS
# ========================================

# Get current client configuration
data "azurerm_client_config" "current" {}

# Role assignment for AKS to access Container Registry
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

# Role assignment for Container Registry to access AKS subnets
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = azurerm_subnet.aks_system.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "aks_network_contributor_user" {
  scope                = azurerm_subnet.aks_user.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

# ========================================
# APPLICATION GATEWAY (Ingress Controller)
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
    Purpose = "ApplicationGatewayIP"
  })
}

# Application Gateway for AKS Ingress
resource "azurerm_application_gateway" "main" {
  name                = "appgw-${lower(local.project)}-${local.environment}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }
  
  zones = ["1", "2", "3"]
  
  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.app_gateway.id
  }
  
  frontend_port {
    name = "https-port"
    port = 443
  }
  
  frontend_port {
    name = "http-port"  
    port = 80
  }
  
  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.app_gateway.id
  }
  
  backend_address_pool {
    name = "aks-backend-pool"
  }
  
  backend_http_settings {
    name                  = "aks-backend-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }
  
  http_listener {
    name                           = "aks-listener"
    frontend_ip_configuration_name = "frontend-ip-config"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }
  
  request_routing_rule {
    name                       = "aks-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "aks-listener"
    backend_address_pool_name  = "aks-backend-pool"
    backend_http_settings_name = "aks-backend-settings"
    priority                   = 1
  }
  
  # WAF Configuration
  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "IngressController"
  })
}

# ========================================
# MONITORING AND ALERTING
# ========================================

# Action Group for AKS alerts
resource "azurerm_monitor_action_group" "aks_alerts" {
  name                = "ag-aks-alerts-${local.environment}"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "aks-alerts"
  
  email_receiver {
    name          = "Platform Team"
    email_address = "platform-team@contoso.com"
  }
  
  tags = local.common_tags
}

# Node CPU Alert
resource "azurerm_monitor_metric_alert" "node_cpu" {
  name                = "alert-aks-node-cpu-${local.environment}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_kubernetes_cluster.main.id]
  description         = "AKS node CPU usage is high"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  
  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_cpu_usage_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.aks_alerts.id
  }
  
  tags = local.common_tags
}

# Pod Restart Alert
resource "azurerm_monitor_metric_alert" "pod_restarts" {
  name                = "alert-aks-pod-restarts-${local.environment}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_kubernetes_cluster.main.id]
  description         = "High number of pod restarts detected"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT30M"
  
  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "kube_pod_status_ready"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 0.95  # Less than 95% pods ready
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.aks_alerts.id
  }
  
  tags = local.common_tags
}

# ========================================
# OUTPUTS
# ========================================

output "aks_cluster_summary" {
  description = "AKS Cluster Configuration Summary"
  value = {
    cluster_name = azurerm_kubernetes_cluster.main.name
    kubernetes_version = azurerm_kubernetes_cluster.main.kubernetes_version
    fqdn = azurerm_kubernetes_cluster.main.fqdn
    
    # Node pools
    system_node_pool = {
      name = "system"
      vm_size = local.aks_config.vm_size
      min_count = local.aks_config.min_node_count
      max_count = local.aks_config.max_node_count
    }
    
    spot_node_pool = {
      name = "spotuser"
      vm_size = local.aks_config.spot_vm_size
      max_spot_price = local.aks_config.max_spot_price
    }
    
    # Networking
    dns_prefix = "${lower(local.project)}-${local.environment}"
    network_plugin = "azure"
    network_policy = "azure"
    
    # Container Registry
    container_registry = azurerm_container_registry.main.login_server
    
    # Application Gateway
    app_gateway_ip = azurerm_public_ip.app_gateway.ip_address
  }
}

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
}

output "cost_optimization_features" {
  description = "Enabled cost optimization features"
  value = [
    "Spot node pools with eviction handling",
    "Auto-scaling enabled (0-10 nodes)",
    "Ephemeral OS disks for faster provisioning",
    "90-day log retention vs 365-day default",
    "Standard_v2 Application Gateway (cost-effective tier)",
    "Geo-replication only to one additional region"
  ]
}
