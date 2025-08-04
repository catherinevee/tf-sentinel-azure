# Microservices Platform Example
# Demonstrates cloud-native microservices architecture with comprehensive governance
# Shows Container Apps, Service Mesh, API Gateway, Service Bus, monitoring, and DevOps integration

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

# Local values for microservices platform configuration
locals {
  environment = "prod"
  project     = "MicroservicesPlatform"
  
  # Common tags for all resources
  common_tags = {
    Environment     = local.environment
    Owner          = "platform-team@contoso.com"
    Project        = local.project
    CostCenter     = "Engineering"
    Application    = "MicroservicesAPI"
    Architecture   = "cloud-native"
    BackupPolicy   = "minimal"
    ComplianceLevel = "standard"
    DataClassification = "internal"
  }
  
  # Microservices platform configuration optimized for cost and scalability
  platform_config = {
    # Container Apps configuration
    container_apps_sku = "Consumption"  # Pay-per-use pricing
    
    # CPU and memory allocations (cost-optimized)
    api_gateway_cpu = 0.25
    api_gateway_memory = "0.5Gi"
    user_service_cpu = 0.25
    user_service_memory = "0.5Gi"
    order_service_cpu = 0.5
    order_service_memory = "1.0Gi"
    notification_service_cpu = 0.25
    notification_service_memory = "0.5Gi"
    
    # Scaling configuration
    min_replicas = 0  # Scale to zero for cost optimization
    max_replicas = 10
    
    # Service Bus configuration
    service_bus_sku = "Standard"  # Cost-effective for microservices messaging
    
    # Redis configuration  
    redis_sku = "Basic"
    redis_size = "C0"  # Smallest cache size
    
    # Container Registry
    acr_sku = "Basic"  # Cost-effective for microservices images
  }
  
  # Microservices definition
  microservices = [
    {
      name = "api-gateway"
      port = 8080
      image = "nginx:alpine"  # Placeholder image
      cpu = local.platform_config.api_gateway_cpu
      memory = local.platform_config.api_gateway_memory
      replicas_min = 1  # API Gateway should always be available
      replicas_max = 5
    },
    {
      name = "user-service"
      port = 8081
      image = "mcr.microsoft.com/dotnet/samples:aspnetapp"
      cpu = local.platform_config.user_service_cpu
      memory = local.platform_config.user_service_memory
      replicas_min = local.platform_config.min_replicas
      replicas_max = local.platform_config.max_replicas
    },
    {
      name = "order-service"
      port = 8082
      image = "mcr.microsoft.com/dotnet/samples:aspnetapp"
      cpu = local.platform_config.order_service_cpu
      memory = local.platform_config.order_service_memory
      replicas_min = local.platform_config.min_replicas
      replicas_max = local.platform_config.max_replicas
    },
    {
      name = "notification-service"
      port = 8083
      image = "mcr.microsoft.com/dotnet/samples:aspnetapp"
      cpu = local.platform_config.notification_service_cpu
      memory = local.platform_config.notification_service_memory
      replicas_min = local.platform_config.min_replicas
      replicas_max = local.platform_config.max_replicas
    }
  ]
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
# CONTAINER APPS ENVIRONMENT
# ========================================

# Log Analytics Workspace for Container Apps
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${lower(local.project)}-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30  # Cost-optimized retention
  
  tags = merge(local.common_tags, {
    Purpose = "MicroservicesMonitoring"
  })
}

# Container Apps Environment
resource "azurerm_container_app_environment" "main" {
  name                = "cae-${lower(local.project)}-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  
  tags = merge(local.common_tags, {
    Purpose = "MicroservicesRuntime"
  })
}

# ========================================
# CONTAINER REGISTRY
# ========================================

resource "azurerm_container_registry" "main" {
  name                = "acr${lower(replace(local.project, "-", ""))}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = local.platform_config.acr_sku
  admin_enabled       = false  # Use managed identity authentication
  
  # Security configurations
  public_network_access_enabled = false
  
  network_rule_set {
    default_action = "Deny"
    
    # Allow access from Container Apps subnet
    virtual_network {
      action    = "Allow"
      subnet_id = azurerm_subnet.container_apps.id
    }
  }
  
  tags = merge(local.common_tags, {
    Purpose = "MicroservicesImages"
  })
}

# ========================================
# NETWORKING FOR MICROSERVICES
# ========================================

# Virtual Network for microservices
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${lower(local.project)}-${local.environment}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]
  
  tags = local.common_tags
}

# Subnet for Container Apps
resource "azurerm_subnet" "container_apps" {
  name                 = "snet-container-apps-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/23"]  # /23 for Container Apps requirement
  
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.ServiceBus",
    "Microsoft.ContainerRegistry"
  ]
  
  delegation {
    name = "Microsoft.App/environments"
    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

# Subnet for supporting services
resource "azurerm_subnet" "services" {
  name                 = "snet-services-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/24"]
  
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.ServiceBus",
    "Microsoft.Cache"
  ]
}

# Update Container Apps Environment with VNet integration
resource "azurerm_container_app_environment" "main_with_vnet" {
  name                = "cae-${lower(local.project)}-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  infrastructure_subnet_id   = azurerm_subnet.container_apps.id
  internal_load_balancer_enabled = false  # External load balancer for API Gateway
  
  tags = merge(local.common_tags, {
    Purpose = "MicroservicesRuntime"
    NetworkIsolation = "VNet"
  })
  
  depends_on = [azurerm_subnet.container_apps]
}

# ========================================
# SERVICE BUS FOR MICROSERVICES MESSAGING
# ========================================

resource "azurerm_servicebus_namespace" "main" {
  name                = "sb-${lower(local.project)}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = local.platform_config.service_bus_sku
  capacity            = 0  # Auto-scaling
  
  # Network isolation
  public_network_access_enabled = false
  
  network_rule_set {
    default_action = "Deny"
    
    network_rules {
      subnet_id = azurerm_subnet.container_apps.id
    }
  }
  
  tags = merge(local.common_tags, {
    Purpose = "MicroservicesMessaging"
  })
}

# Topics for event-driven communication
resource "azurerm_servicebus_topic" "user_events" {
  name         = "user-events"
  namespace_id = azurerm_servicebus_namespace.main.id
  
  enable_partitioning = true  # Better performance for microservices
  max_size_in_megabytes = 1024
}

resource "azurerm_servicebus_topic" "order_events" {
  name         = "order-events"
  namespace_id = azurerm_servicebus_namespace.main.id
  
  enable_partitioning = true
  max_size_in_megabytes = 1024
}

# Subscriptions for microservices
resource "azurerm_servicebus_subscription" "notification_user_events" {
  name     = "notification-service"
  topic_id = azurerm_servicebus_topic.user_events.id
  
  max_delivery_count = 10
  auto_delete_on_idle = "P1D"  # Clean up unused subscriptions
}

resource "azurerm_servicebus_subscription" "notification_order_events" {
  name     = "notification-service"
  topic_id = azurerm_servicebus_topic.order_events.id
  
  max_delivery_count = 10
  auto_delete_on_idle = "P1D"
}

# ========================================
# REDIS CACHE FOR MICROSERVICES STATE
# ========================================

resource "azurerm_redis_cache" "main" {
  name                = "redis-${lower(local.project)}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  capacity            = 0  # C0 - 250MB
  family              = "C"
  sku_name            = local.platform_config.redis_sku
  
  # Security configurations
  public_network_access_enabled = false
  
  # Network restrictions
  subnet_id = azurerm_subnet.services.id
  
  # Redis configuration for microservices
  redis_configuration {
    enable_non_ssl_port = false
    maxmemory_policy   = "allkeys-lru"  # Eviction policy for caching
  }
  
  tags = merge(local.common_tags, {
    Purpose = "MicroservicesCache"
  })
}

# ========================================
# CONTAINER APPS FOR MICROSERVICES
# ========================================

# API Gateway Container App
resource "azurerm_container_app" "api_gateway" {
  name                         = "ca-api-gateway-${local.environment}"
  container_app_environment_id = azurerm_container_app_environment.main_with_vnet.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode               = "Single"
  
  template {
    min_replicas = 1  # API Gateway should always be available
    max_replicas = 5
    
    container {
      name   = "api-gateway"
      image  = "nginx:alpine"
      cpu    = local.platform_config.api_gateway_cpu
      memory = local.platform_config.api_gateway_memory
      
      env {
        name  = "USER_SERVICE_URL"
        value = "http://ca-user-service-${local.environment}:8081"
      }
      
      env {
        name  = "ORDER_SERVICE_URL"
        value = "http://ca-order-service-${local.environment}:8082"
      }
    }
    
    # HTTP scaling rule
    http_scale_rule {
      name                = "http-requests"
      concurrent_requests = "10"
    }
  }
  
  ingress {
    allow_insecure_connections = false
    external_enabled          = true
    target_port              = 80
    
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "APIGateway"
    ServiceType = "Gateway"
  })
}

# User Service Container App
resource "azurerm_container_app" "user_service" {
  name                         = "ca-user-service-${local.environment}"
  container_app_environment_id = azurerm_container_app_environment.main_with_vnet.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode               = "Single"
  
  template {
    min_replicas = 0  # Scale to zero for cost optimization
    max_replicas = 10
    
    container {
      name   = "user-service"
      image  = "mcr.microsoft.com/dotnet/samples:aspnetapp"
      cpu    = local.platform_config.user_service_cpu
      memory = local.platform_config.user_service_memory
      
      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = "Production"
      }
      
      env {
        name        = "ServiceBus__ConnectionString"
        secret_name = "servicebus-connection"
      }
      
      env {
        name        = "Redis__ConnectionString"
        secret_name = "redis-connection"
      }
    }
    
    # CPU scaling rule
    cpu_scale_rule {
      name                    = "cpu-utilization"
      cpu_utilization_percentage = 70
    }
  }
  
  ingress {
    allow_insecure_connections = false
    external_enabled          = false  # Internal service
    target_port              = 8080
    
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
  
  # Secrets for Service Bus and Redis
  secret {
    name  = "servicebus-connection"
    value = azurerm_servicebus_namespace.main.default_primary_connection_string
  }
  
  secret {
    name  = "redis-connection"
    value = azurerm_redis_cache.main.primary_connection_string
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "UserManagement"
    ServiceType = "BusinessLogic"
  })
}

# Order Service Container App
resource "azurerm_container_app" "order_service" {
  name                         = "ca-order-service-${local.environment}"
  container_app_environment_id = azurerm_container_app_environment.main_with_vnet.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode               = "Single"
  
  template {
    min_replicas = 0
    max_replicas = 10
    
    container {
      name   = "order-service"
      image  = "mcr.microsoft.com/dotnet/samples:aspnetapp"
      cpu    = local.platform_config.order_service_cpu
      memory = local.platform_config.order_service_memory
      
      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = "Production"
      }
      
      env {
        name        = "ServiceBus__ConnectionString"
        secret_name = "servicebus-connection"
      }
    }
    
    # Memory scaling rule
    memory_scale_rule {
      name                     = "memory-utilization"
      memory_utilization_percentage = 80
    }
  }
  
  ingress {
    allow_insecure_connections = false
    external_enabled          = false
    target_port              = 8080
    
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
  
  secret {
    name  = "servicebus-connection"
    value = azurerm_servicebus_namespace.main.default_primary_connection_string
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "OrderProcessing"
    ServiceType = "BusinessLogic"
  })
}

# Notification Service Container App
resource "azurerm_container_app" "notification_service" {
  name                         = "ca-notification-service-${local.environment}"
  container_app_environment_id = azurerm_container_app_environment.main_with_vnet.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode               = "Single"
  
  template {
    min_replicas = 0
    max_replicas = 5
    
    container {
      name   = "notification-service"
      image  = "mcr.microsoft.com/dotnet/samples:aspnetapp"
      cpu    = local.platform_config.notification_service_cpu
      memory = local.platform_config.notification_service_memory
      
      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = "Production"
      }
      
      env {
        name        = "ServiceBus__ConnectionString"
        secret_name = "servicebus-connection"
      }
    }
    
    # Service Bus scaling rule
    azure_queue_scale_rule {
      name         = "servicebus-messages"
      queue_name   = azurerm_servicebus_topic.user_events.name
      queue_length = 5
      
      authentication {
        secret_name       = "servicebus-connection"
        trigger_parameter = "connection"
      }
    }
  }
  
  # No ingress - this is a background service
  
  secret {
    name  = "servicebus-connection"
    value = azurerm_servicebus_namespace.main.default_primary_connection_string
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "NotificationProcessing"
    ServiceType = "BackgroundService"
  })
}

# ========================================
# APPLICATION INSIGHTS FOR MONITORING
# ========================================

resource "azurerm_application_insights" "main" {
  name                = "appi-${lower(local.project)}-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  
  tags = merge(local.common_tags, {
    Purpose = "MicroservicesMonitoring"
  })
}

# ========================================
# ROLE ASSIGNMENTS
# ========================================

# ACR Pull permissions for Container Apps
resource "azurerm_role_assignment" "acr_pull" {
  for_each = toset([
    azurerm_container_app.api_gateway.identity[0].principal_id,
    azurerm_container_app.user_service.identity[0].principal_id,
    azurerm_container_app.order_service.identity[0].principal_id,
    azurerm_container_app.notification_service.identity[0].principal_id
  ])
  
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = each.value
}

# Service Bus Data Owner for microservices
resource "azurerm_role_assignment" "servicebus_owner" {
  for_each = toset([
    azurerm_container_app.user_service.identity[0].principal_id,
    azurerm_container_app.order_service.identity[0].principal_id,
    azurerm_container_app.notification_service.identity[0].principal_id
  ])
  
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = each.value
}

# ========================================
# OUTPUTS
# ========================================

output "microservices_platform_summary" {
  description = "Microservices Platform Configuration Summary"
  value = {
    # Container Apps Environment
    container_apps_environment = azurerm_container_app_environment.main_with_vnet.name
    
    # Microservices
    api_gateway_url = "https://${azurerm_container_app.api_gateway.ingress[0].fqdn}"
    microservices = [
      azurerm_container_app.api_gateway.name,
      azurerm_container_app.user_service.name,
      azurerm_container_app.order_service.name,
      azurerm_container_app.notification_service.name
    ]
    
    # Supporting services
    container_registry = azurerm_container_registry.main.name
    service_bus_namespace = azurerm_servicebus_namespace.main.name
    redis_cache = azurerm_redis_cache.main.name
    
    # Monitoring
    application_insights = azurerm_application_insights.main.name
    log_analytics_workspace = azurerm_log_analytics_workspace.main.name
  }
}

output "cost_optimization_features" {
  description = "Microservices cost optimization features enabled"
  value = [
    "Container Apps Consumption pricing (pay-per-use)",
    "Scale-to-zero for background services",
    "Right-sized CPU and memory allocations",
    "Basic Container Registry tier",
    "Standard Service Bus (not Premium)",
    "Basic Redis Cache (C0 - 250MB)",
    "30-day log retention vs 365-day default",
    "Auto-scaling based on CPU, memory, and queue length",
    "Internal networking for service-to-service calls",
    "Partitioned Service Bus topics for better performance"
  ]
}

output "microservices_architecture_benefits" {
  description = "Microservices architecture benefits"
  value = [
    "Independent deployment and scaling per service",
    "Technology diversity - choose best tools per service",
    "Fault isolation - failure in one service doesn't affect others",
    "Team autonomy - different teams can own different services",
    "Event-driven communication with Service Bus",
    "Distributed caching with Redis for performance",
    "Container-based deployment for consistency",
    "Auto-scaling based on service-specific metrics",
    "Network isolation with VNet integration",
    "Comprehensive monitoring and observability"
  ]
}

output "service_communication_patterns" {
  description = "Inter-service communication patterns implemented"
  value = [
    "Synchronous: HTTP/REST calls between services",
    "Asynchronous: Service Bus topics for event publishing",
    "Caching: Redis for shared state and session management",
    "API Gateway: Single entry point for external clients",
    "Service Discovery: Container Apps built-in DNS resolution",
    "Load Balancing: Built-in load balancing per service",
    "Circuit Breaker: Can be implemented at application level",
    "Retry Policies: Service Bus built-in retry mechanisms",
    "Message Queuing: Service Bus queues for reliable messaging",
    "Event Sourcing: Service Bus topics for event streams"
  ]
}
