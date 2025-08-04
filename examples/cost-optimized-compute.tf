# Cost-Optimized Compute Infrastructure Example
# Demonstrates cost-effective VM deployments, auto-scaling, and compute optimization strategies
# Shows how to balance performance requirements with cost control policies

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

# Local values for cost-optimized compute
locals {
  environment = "dev"
  project     = "ComputePlatform"
  
  # Cost-focused tagging
  cost_tags = {
    Environment = local.environment
    Owner      = "platform-team@contoso.com"
    Project    = local.project
    CostCenter = "Infrastructure"
    Application = "ComputePlatform"
    
    # Cost optimization tracking
    CostModel      = "spot-instances"
    AutoScale      = "enabled"
    ScheduledShutdown = "enabled"
    BudgetCategory = "compute-development"
  }
}

# Resource Group for compute resources
resource "azurerm_resource_group" "compute" {
  name     = "rg-compute-cost-optimized-dev-001"
  location = "East US"  # Cost-effective region
  
  tags = merge(local.cost_tags, {
    Purpose = "CostOptimizedCompute"
  })
}

# ========================================
# VIRTUAL NETWORK AND SUBNETS
# ========================================

# Virtual Network for compute resources
resource "azurerm_virtual_network" "compute" {
  name                = "vnet-compute-cost-dev-001"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  address_space       = ["10.3.0.0/16"]
  
  tags = merge(local.cost_tags, {
    Purpose = "ComputeNetworking"
  })
}

# Subnet for compute resources
resource "azurerm_subnet" "compute" {
  name                 = "snet-compute-dev-001"
  resource_group_name  = azurerm_resource_group.compute.name
  virtual_network_name = azurerm_virtual_network.compute.name
  address_prefixes     = ["10.3.1.0/24"]
}

# ========================================
# SPOT VIRTUAL MACHINE SCALE SET
# ========================================

# Network Security Group with minimal rules for cost
resource "azurerm_network_security_group" "compute" {
  name                = "nsg-compute-cost-dev-001"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  
  # Minimal security rules for development
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.3.0.0/16"  # Only from VNet
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  tags = local.cost_tags
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "compute" {
  subnet_id                 = azurerm_subnet.compute.id
  network_security_group_id = azurerm_network_security_group.compute.id
}

# VM Scale Set with Spot instances for maximum cost savings
resource "azurerm_linux_virtual_machine_scale_set" "spot_instances" {
  name                = "vmss-spot-cost-dev-001"
  resource_group_name = azurerm_resource_group.compute.name
  location            = azurerm_resource_group.compute.location
  
  # Cost-optimized VM size (complies with cost control policy)
  sku       = "Standard_B1s"  # Burstable, lowest cost VM size
  instances = 2               # Minimum instances for development
  
  # Spot instance configuration for massive cost savings (up to 90% off)
  priority        = "Spot"
  eviction_policy = "Deallocate"  # Deallocate when evicted (don't delete)
  max_bid_price   = 0.02          # Maximum hourly price ($0.02/hour)
  
  # Authentication
  admin_username                  = "azureuser"
  disable_password_authentication = true
  
  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.vm_ssh.public_key_openssh
  }
  
  # Source image - use latest Ubuntu LTS for cost efficiency
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"  # Ubuntu 20.04 LTS
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  
  # OS disk configuration for cost optimization
  os_disk {
    storage_account_type = "Standard_LRS"  # Standard LRS for cost savings
    caching              = "ReadWrite"
    disk_size_gb         = 30              # Minimum OS disk size
  }
  
  # Network interface configuration
  network_interface {
    name    = "internal"
    primary = true
    
    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.compute.id
      
      # No public IPs to save costs (use bastion or VPN for access)
      public_ip_address {
        name = "public"
      }
    }
  }
  
  # Custom data script for application installation
  custom_data = base64encode(templatefile("${path.module}/scripts/init-web-server.sh", {
    app_name = "cost-optimized-app"
  }))
  
  # Upgrade policy for cost control
  upgrade_mode = "Manual"  # Manual upgrades to control timing and costs
  
  # Health probe for auto-scaling
  health_probe_id = azurerm_lb_probe.web.id
  
  tags = merge(local.cost_tags, {
    VMType    = "Spot"
    MaxBid    = "$0.02/hour"
    SpotSavings = "Up to 90%"
  })
}

# ========================================
# LOAD BALANCER (BASIC TIER)
# ========================================

# Public IP for Load Balancer - Basic SKU for cost savings
resource "azurerm_public_ip" "lb" {
  name                = "pip-lb-cost-dev-001"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  allocation_method   = "Static"
  sku                = "Basic"  # Basic SKU for cost optimization
  
  tags = local.cost_tags
}

# Load Balancer - Basic tier for cost optimization
resource "azurerm_lb" "web" {
  name                = "lb-web-cost-dev-001"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  sku                = "Basic"  # Basic tier - no SLA but significant cost savings
  
  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
  
  tags = merge(local.cost_tags, {
    Tier = "Basic"
  })
}

# Backend address pool
resource "azurerm_lb_backend_address_pool" "web" {
  loadbalancer_id = azurerm_lb.web.id
  name            = "BackEndAddressPool"
}

# Health probe
resource "azurerm_lb_probe" "web" {
  loadbalancer_id = azurerm_lb.web.id
  name            = "http-probe"
  port            = 80
  protocol        = "Http"
  request_path    = "/health"
}

# Load balancing rule
resource "azurerm_lb_rule" "web" {
  loadbalancer_id                = azurerm_lb.web.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  probe_id                       = azurerm_lb_probe.web.id
}

# ========================================
# AUTO-SCALING CONFIGURATION
# ========================================

# Auto-scaling settings for cost optimization
resource "azurerm_monitor_autoscale_setting" "vmss" {
  name                = "autoscale-vmss-cost-dev"
  resource_group_name = azurerm_resource_group.compute.name
  location            = azurerm_resource_group.compute.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.spot_instances.id
  
  # Profile for cost-optimized scaling
  profile {
    name = "defaultProfile"
    
    capacity {
      default = 2  # Start with minimal instances
      minimum = 1  # Minimum for cost control
      maximum = 5  # Maximum to control costs
    }
    
    # Scale out rule - conservative to control costs
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.spot_instances.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 80  # Higher threshold to avoid unnecessary scaling
      }
      
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"      # Scale by 1 instance at a time
        cooldown  = "PT5M"   # 5-minute cooldown
      }
    }
    
    # Scale in rule - aggressive to save costs
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.spot_instances.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25  # Lower threshold for aggressive scale-in
      }
      
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT3M"   # Shorter cooldown for cost savings
      }
    }
  }
  
  # Weekend profile - scale down for cost savings
  profile {
    name = "weekendProfile"
    
    capacity {
      default = 1
      minimum = 1
      maximum = 2  # Limited scaling on weekends
    }
    
    # Weekend schedule (Saturday-Sunday)
    recurrence {
      timezone = "Eastern Standard Time"
      days     = ["Saturday", "Sunday"]
      hours    = [0]
      minutes  = [0]
    }
  }
  
  tags = merge(local.cost_tags, {
    ScalingStrategy = "CostOptimized"
  })
}

# ========================================
# SCHEDULED SHUTDOWN AUTOMATION
# ========================================

# Automation Account for scheduled operations
resource "azurerm_automation_account" "compute_automation" {
  name                = "aa-compute-cost-dev-001"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  sku_name           = "Basic"
  
  # Managed identity for VM operations
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.cost_tags, {
    Purpose = "CostAutomation"
  })
}

# Role assignment for automation account
resource "azurerm_role_assignment" "automation_contributor" {
  scope                = azurerm_resource_group.compute.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_automation_account.compute_automation.identity[0].principal_id
}

# Runbook for scheduled shutdown
resource "azurerm_automation_runbook" "shutdown_vms" {
  name                    = "Shutdown-VMs-Cost-Control"
  location                = azurerm_resource_group.compute.location
  resource_group_name     = azurerm_resource_group.compute.name
  automation_account_name = azurerm_automation_account.compute_automation.name
  log_verbose             = false
  log_progress            = false
  runbook_type            = "PowerShell"
  
  content = <<-EOT
    # Cost control shutdown script
    param(
        [string]$ResourceGroupName = "${azurerm_resource_group.compute.name}",
        [string]$ScaleSetName = "${azurerm_linux_virtual_machine_scale_set.spot_instances.name}"
    )
    
    # Connect using Managed Identity
    Connect-AzAccount -Identity
    
    # Get current time
    $currentTime = Get-Date
    $hour = $currentTime.Hour
    
    # Shutdown logic based on time
    if ($hour -ge 22 -or $hour -le 6) {
        Write-Output "Off-hours detected. Scaling down VMSS to minimum instances."
        
        # Scale down to 1 instance for cost savings
        $vmss = Get-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $ScaleSetName
        if ($vmss.Sku.Capacity -gt 1) {
            Update-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $ScaleSetName -SkuCapacity 1
            Write-Output "VMSS scaled down to 1 instance for cost savings."
        }
    } else {
        Write-Output "Business hours detected. No scaling action needed."
    }
  EOT
  
  tags = local.cost_tags
}

# Schedule for nightly cost control (10 PM)
resource "azurerm_automation_schedule" "nightly_cost_control" {
  name                    = "nightly-cost-control-10pm"
  resource_group_name     = azurerm_resource_group.compute.name
  automation_account_name = azurerm_automation_account.compute_automation.name
  frequency               = "Day"
  interval                = 1
  start_time              = "2025-08-05T22:00:00-05:00"  # 10 PM EST
  description             = "Nightly cost control scaling"
}

# Link schedule to runbook
resource "azurerm_automation_job_schedule" "cost_control_schedule" {
  resource_group_name     = azurerm_resource_group.compute.name
  automation_account_name = azurerm_automation_account.compute_automation.name
  schedule_name           = azurerm_automation_schedule.nightly_cost_control.name
  runbook_name           = azurerm_automation_runbook.shutdown_vms.name
}

# ========================================
# COST MONITORING
# ========================================

# Budget for compute resources
resource "azurerm_consumption_budget_resource_group" "compute" {
  name              = "budget-compute-dev-monthly"
  resource_group_id = azurerm_resource_group.compute.id
  
  amount     = 150  # $150 monthly budget for compute
  time_grain = "Monthly"
  
  time_period {
    start_date = "2025-08-01T00:00:00Z"
    end_date   = "2026-07-31T23:59:59Z"
  }
  
  # Budget notifications
  notification {
    enabled   = true
    threshold = 70.0
    operator  = "GreaterThan"
    
    contact_emails = [
      "platform-team@contoso.com"
    ]
  }
  
  notification {
    enabled   = true
    threshold = 85.0
    operator  = "GreaterThan"
    
    contact_emails = [
      "platform-team@contoso.com",
      "finance@contoso.com"
    ]
  }
  
  notification {
    enabled   = true
    threshold = 95.0
    operator  = "GreaterThan"
    
    contact_emails = [
      "platform-team@contoso.com",
      "finance@contoso.com",
      "management@contoso.com"
    ]
  }
}

# ========================================
# SSH KEY GENERATION
# ========================================

# Generate SSH key for VM access
resource "tls_private_key" "vm_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store SSH private key in Key Vault
resource "azurerm_key_vault" "compute" {
  name                = "kv-compute-cost-dev-001"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  
  sku_name = "standard"
  
  # Cost-conscious settings
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  
  tags = merge(local.cost_tags, {
    Purpose = "SSHKeys"
  })
}

# Store SSH private key
resource "azurerm_key_vault_secret" "ssh_private_key" {
  name         = "vm-ssh-private-key"
  value        = tls_private_key.vm_ssh.private_key_pem
  key_vault_id = azurerm_key_vault.compute.id
  
  tags = local.cost_tags
}

# Data sources
data "azurerm_client_config" "current" {}

# ========================================
# OUTPUTS
# ========================================

output "cost_savings_estimate" {
  description = "Estimated cost savings from optimization strategies"
  value = {
    spot_instances        = "Up to 90% savings vs regular VMs"
    basic_load_balancer   = "~60% savings vs Standard LB"
    burstable_vm_size     = "~70% savings vs general purpose VMs"
    auto_scaling          = "Pay only for needed capacity"
    scheduled_shutdown    = "~40% savings during off-hours"
    standard_storage      = "~50% savings vs Premium SSD"
    total_monthly_estimate = "$25-40/month (vs $150-200 without optimization)"
  }
}

output "cost_optimization_features" {
  description = "Implemented cost optimization features"
  value = {
    "spot_instances"          = "90% cost reduction, eviction handling"
    "burstable_vm_size"       = "B1s - lowest cost VM size"
    "auto_scaling"            = "1-5 instances based on CPU"
    "basic_load_balancer"     = "No SLA but significant cost savings"
    "standard_lrs_storage"    = "Cost-effective storage tier"
    "scheduled_cost_control"  = "Nightly scaling for off-hours"
    "weekend_scaling_profile" = "Reduced capacity weekends"
    "no_premium_features"     = "Avoided premium SKUs and features"
    "manual_upgrade_mode"     = "Control timing of expensive operations"
  }
}

output "access_information" {
  description = "How to access the cost-optimized infrastructure"
  value = {
    load_balancer_ip = azurerm_public_ip.lb.ip_address
    ssh_key_vault    = azurerm_key_vault.compute.name
    ssh_username     = "azureuser"
    vm_scale_set     = azurerm_linux_virtual_machine_scale_set.spot_instances.name
    spot_max_price   = "$0.02/hour"
  }
}

output "monitoring_and_alerts" {
  description = "Cost monitoring configuration"
  value = {
    monthly_budget     = "$150"
    alert_thresholds   = ["70%", "85%", "95%"]
    auto_scaling       = "CPU-based, 1-5 instances"
    shutdown_schedule  = "Nightly at 10 PM EST"
    weekend_scaling    = "Reduced capacity on weekends"
  }
}
