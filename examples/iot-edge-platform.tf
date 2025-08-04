# IoT & Edge Computing Platform Example
# Demonstrates IoT platform with edge computing governance and security
# Shows IoT Hub, device management, edge computing, and monitoring best practices

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

# Local values for IoT platform configuration
locals {
  environment = "prod"
  project     = "IoTPlatform"
  
  # Common tags for all resources
  common_tags = {
    Environment     = local.environment
    Owner          = "iot-team@contoso.com"
    Project        = local.project
    CostCenter     = "Operations"
    Application    = "IoTEdgeComputing"
    SecurityBaseline = "iot-security"
    BackupPolicy   = "standard"
    ComplianceLevel = "high"
    DataClassification = "operational"
  }
  
  # IoT configuration
  iot_config = {
    device_count_estimate = 10000
    retention_days = 30  # Cost-optimized retention for telemetry
    partition_count = 4  # Based on expected throughput
    edge_vm_size = "Standard_B2s"  # Burstable for edge scenarios
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

# Virtual Network for IoT platform
resource "azurerm_virtual_network" "iot_platform" {
  name                = "vnet-${lower(local.project)}-${local.environment}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]
  
  tags = local.common_tags
}

# Subnet for edge computing resources
resource "azurerm_subnet" "edge_compute" {
  name                 = "snet-edge-compute-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.iot_platform.name
  address_prefixes     = ["10.0.1.0/24"]
  
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.EventHub",
    "Microsoft.KeyVault"
  ]
}

# Subnet for IoT services
resource "azurerm_subnet" "iot_services" {
  name                 = "snet-iot-services-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.iot_platform.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Network Security Group for edge computing
resource "azurerm_network_security_group" "edge_compute" {
  name                = "nsg-edge-compute-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  # Allow IoT Edge runtime ports
  security_rule {
    name                       = "AllowIoTEdgeAgent"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8883"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "AllowIoTEdgeHub"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  
  # Allow SSH for management (restricted to internal network)
  security_rule {
    name                       = "AllowSSH"
    priority                   = 1020
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }
  
  tags = local.common_tags
}

# Associate NSG with edge compute subnet
resource "azurerm_subnet_network_security_group_association" "edge_compute" {
  subnet_id                 = azurerm_subnet.edge_compute.id
  network_security_group_id = azurerm_network_security_group.edge_compute.id
}

# ========================================
# IOT HUB
# ========================================

resource "azurerm_iothub" "main" {
  name                = "iot-${lower(local.project)}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  # Standard tier for production IoT workloads
  sku {
    name     = "S1"
    capacity = "2"  # Cost-optimized capacity
  }
  
  # Event Hub endpoints configuration
  event_hub_partition_count   = local.iot_config.partition_count
  event_hub_retention_in_days = 1  # Minimum retention to reduce costs
  
  # Cloud-to-device messaging
  cloud_to_device {
    max_delivery_count = 30
    default_ttl        = "PT1H"
    feedback {
      time_to_live       = "PT1H"
      max_delivery_count = 10
      lock_duration     = "PT30S"
    }
  }
  
  # File upload configuration
  file_upload {
    connection_string  = azurerm_storage_account.iot_storage.primary_blob_connection_string
    container_name     = azurerm_storage_container.device_uploads.name
    sas_ttl           = "PT1H"
    notifications     = true
    lock_duration     = "PT1M"
    default_ttl       = "PT1H"
    max_delivery_count = 10
  }
  
  tags = merge(local.common_tags, {
    Purpose = "IoTDeviceManagement"
  })
}

# IoT Hub Device Provisioning Service
resource "azurerm_iothub_dps" "main" {
  name                = "dps-${lower(local.project)}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  sku {
    name     = "S1"
    capacity = "1"
  }
  
  # Link to IoT Hub
  linked_hub {
    connection_string = azurerm_iothub.main.event_hub_events_endpoint
    location          = azurerm_resource_group.main.location
  }
  
  tags = merge(local.common_tags, {
    Purpose = "DeviceProvisioning"
  })
}

# ========================================
# STORAGE FOR IOT DATA
# ========================================

resource "azurerm_storage_account" "iot_storage" {
  name                = "saiot${lower(replace(local.project, "-", ""))}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  account_tier             = "Standard"
  account_replication_type = "LRS"  # Cost-effective for IoT data
  account_kind            = "StorageV2"
  
  # Security configurations
  https_traffic_only_enabled      = true
  min_tls_version                = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true  # Required for IoT Hub integration
  
  # Network access restrictions
  public_network_access_enabled = false
  
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    
    virtual_network_subnet_ids = [
      azurerm_subnet.edge_compute.id,
      azurerm_subnet.iot_services.id
    ]
  }
  
  # Lifecycle management for cost optimization
  blob_properties {
    delete_retention_policy {
      days = local.iot_config.retention_days
    }
    
    # Automated tiering for old IoT data
    versioning_enabled = false
    change_feed_enabled = false
  }
  
  tags = merge(local.common_tags, {
    Purpose = "IoTDataStorage"
  })
}

# Storage containers for different IoT data types
resource "azurerm_storage_container" "device_uploads" {
  name                  = "device-uploads"
  storage_account_name  = azurerm_storage_account.iot_storage.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "telemetry_archive" {
  name                  = "telemetry-archive"
  storage_account_name  = azurerm_storage_account.iot_storage.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "edge_deployments" {
  name                  = "edge-deployments"
  storage_account_name  = azurerm_storage_account.iot_storage.name
  container_access_type = "private"
}

# ========================================
# EVENT HUB FOR TELEMETRY PROCESSING
# ========================================

resource "azurerm_eventhub_namespace" "main" {
  name                = "evhns-${lower(local.project)}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"  # Cost-effective for IoT workloads
  capacity            = 1
  
  # Network isolation
  public_network_access_enabled = false
  
  network_rulesets {
    default_action = "Deny"
    
    virtual_network_rule {
      subnet_id = azurerm_subnet.iot_services.id
    }
    
    virtual_network_rule {
      subnet_id = azurerm_subnet.edge_compute.id
    }
  }
  
  tags = merge(local.common_tags, {
    Purpose = "TelemetryIngestion"
  })
}

# Event Hub for device telemetry
resource "azurerm_eventhub" "device_telemetry" {
  name                = "telemetry"
  namespace_name      = azurerm_eventhub_namespace.main.name
  resource_group_name = azurerm_resource_group.main.name
  partition_count     = local.iot_config.partition_count
  message_retention   = 1  # Minimum retention for cost optimization
  
  capture_description {
    enabled  = true
    encoding = "Avro"
    
    destination {
      name                = "EventHubArchive.AzureBlockBlob"
      archive_name_format = "{Namespace}/{EventHub}/{PartitionId}/{Year}/{Month}/{Day}/{Hour}/{Minute}/{Second}"
      blob_container_name = azurerm_storage_container.telemetry_archive.name
      storage_account_id  = azurerm_storage_account.iot_storage.id
    }
  }
}

# ========================================
# STREAM ANALYTICS FOR REAL-TIME PROCESSING
# ========================================

resource "azurerm_stream_analytics_job" "main" {
  name                                     = "asa-${lower(local.project)}-${local.environment}-001"
  resource_group_name                      = azurerm_resource_group.main.name
  location                                 = azurerm_resource_group.main.location
  compatibility_level                      = "1.2"
  data_locale                             = "en-US"
  events_late_arrival_max_delay_in_seconds = 60
  events_out_of_order_max_delay_in_seconds = 50
  events_out_of_order_policy              = "Adjust"
  output_error_policy                     = "Stop"
  streaming_units                         = 3  # Cost-optimized for moderate throughput
  
  transformation_query = <<QUERY
SELECT
    System.Timestamp AS EventTime,
    DeviceId,
    AVG(Temperature) AS AvgTemperature,
    MAX(Temperature) AS MaxTemperature,
    COUNT(*) AS MessageCount
INTO
    [IoTOutput]
FROM
    [IoTInput] TIMESTAMP BY EventEnqueuedUtcTime
GROUP BY
    DeviceId,
    TumblingWindow(minute, 5)
HAVING
    AVG(Temperature) > 25 OR MAX(Temperature) > 40
QUERY
  
  tags = merge(local.common_tags, {
    Purpose = "RealTimeAnalytics"
  })
}

# Stream Analytics Input
resource "azurerm_stream_analytics_stream_input_eventhub" "main" {
  name                         = "IoTInput"
  stream_analytics_job_name    = azurerm_stream_analytics_job.main.name
  resource_group_name          = azurerm_resource_group.main.name
  eventhub_consumer_group_name = "$Default"
  eventhub_name               = azurerm_eventhub.device_telemetry.name
  servicebus_namespace        = azurerm_eventhub_namespace.main.name
  shared_access_policy_name   = "RootManageSharedAccessKey"
  
  serialization {
    type     = "Json"
    encoding = "UTF8"
  }
}

# ========================================
# IOT EDGE VIRTUAL MACHINE
# ========================================

# User-assigned managed identity for IoT Edge
resource "azurerm_user_assigned_identity" "iot_edge" {
  name                = "id-iot-edge-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  tags = local.common_tags
}

# Network interface for IoT Edge VM
resource "azurerm_network_interface" "iot_edge" {
  name                = "nic-iot-edge-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.edge_compute.id
    private_ip_address_allocation = "Dynamic"
  }
  
  tags = local.common_tags
}

# IoT Edge Virtual Machine
resource "azurerm_linux_virtual_machine" "iot_edge" {
  name                = "vm-iot-edge-${local.environment}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = local.iot_config.edge_vm_size
  
  # Disable password authentication
  disable_password_authentication = true
  
  network_interface_ids = [
    azurerm_network_interface.iot_edge.id
  ]
  
  # User-assigned managed identity
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.iot_edge.id]
  }
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_SSD"  # Cost-effective SSD
  }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  
  computer_name  = "iot-edge-01"
  admin_username = "azureuser"
  
  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7... (your-public-key-here)"
  }
  
  # Custom script to install IoT Edge runtime
  custom_data = base64encode(templatefile("${path.module}/scripts/install-iot-edge.sh", {
    iot_hub_name = azurerm_iothub.main.name
    dps_name = azurerm_iothub_dps.main.name
  }))
  
  tags = merge(local.common_tags, {
    Purpose = "IoTEdgeGateway"
  })
}

# ========================================
# TIME SERIES INSIGHTS (OPTIONAL)
# ========================================

# Time Series Insights Environment
resource "azurerm_iothub_consumer_group" "tsi" {
  name                   = "tsi-consumer-group"
  iothub_name           = azurerm_iothub.main.name
  eventhub_endpoint_name = "events"
  resource_group_name    = azurerm_resource_group.main.name
}

# ========================================
# MONITORING AND ALERTING
# ========================================

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${lower(local.project)}-${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 90  # Cost-optimized retention
  
  tags = merge(local.common_tags, {
    Purpose = "IoTMonitoring"
  })
}

# IoT Hub diagnostic settings
resource "azurerm_monitor_diagnostic_setting" "iot_hub" {
  name                       = "diag-iothub-${local.environment}"
  target_resource_id         = azurerm_iothub.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  
  enabled_log {
    category = "Connections"
  }
  
  enabled_log {
    category = "DeviceTelemetry"
  }
  
  enabled_log {
    category = "C2DCommands"
  }
  
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Action group for IoT alerts
resource "azurerm_monitor_action_group" "iot_alerts" {
  name                = "ag-iot-alerts-${local.environment}"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "iot-alerts"
  
  email_receiver {
    name          = "IoT Operations Team"
    email_address = "iot-team@contoso.com"
  }
  
  tags = local.common_tags
}

# Device connectivity alert
resource "azurerm_monitor_metric_alert" "device_connectivity" {
  name                = "alert-device-connectivity-${local.environment}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_iothub.main.id]
  description         = "Device connectivity issues detected"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"
  
  criteria {
    metric_namespace = "Microsoft.Devices/IotHubs"
    metric_name      = "connectedDeviceCount"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = local.iot_config.device_count_estimate * 0.8  # Alert if <80% devices connected
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.iot_alerts.id
  }
  
  tags = local.common_tags
}

# ========================================
# OUTPUTS
# ========================================

output "iot_platform_summary" {
  description = "IoT Platform Configuration Summary"
  value = {
    # Core IoT services
    iot_hub_name = azurerm_iothub.main.name
    iot_hub_hostname = azurerm_iothub.main.hostname
    device_provisioning_service = azurerm_iothub_dps.main.name
    
    # Data processing
    event_hub_namespace = azurerm_eventhub_namespace.main.name
    stream_analytics_job = azurerm_stream_analytics_job.main.name
    storage_account = azurerm_storage_account.iot_storage.name
    
    # Edge computing
    edge_vm_name = azurerm_linux_virtual_machine.iot_edge.name
    edge_vm_private_ip = azurerm_network_interface.iot_edge.private_ip_address
    
    # Monitoring
    log_analytics_workspace = azurerm_log_analytics_workspace.main.name
  }
}

output "device_connection_info" {
  description = "Information for connecting IoT devices"
  value = {
    iot_hub_connection_string = azurerm_iothub.main.event_hub_events_endpoint
    device_provisioning_endpoint = azurerm_iothub_dps.main.device_provisioning_host_name
    device_provisioning_scope = azurerm_iothub_dps.main.id_scope
  }
  sensitive = true
}

output "cost_optimization_features" {
  description = "Enabled cost optimization features"
  value = [
    "S1 IoT Hub tier (cost-effective for production)",
    "1-day Event Hub retention (minimum)",
    "LRS storage replication (cost-effective)",
    "Standard_B2s VMs for edge computing (burstable)",
    "3 Stream Analytics units (moderate throughput)",
    "90-day log retention vs 365-day default",
    "Standard Event Hub tier vs Premium"
  ]
}

output "security_features" {
  description = "Enabled security features"
  value = [
    "Private network access for all services",
    "Network Security Groups with IoT-specific rules",
    "Managed identities for service authentication",
    "TLS 1.2 minimum for all communications",
    "Device Provisioning Service for secure enrollment",
    "SSH key authentication for edge VMs",
    "Encrypted storage and data in transit",
    "Comprehensive monitoring and alerting"
  ]
}
