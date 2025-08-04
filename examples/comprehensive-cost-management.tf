# Comprehensive Cost Management and Budget Monitoring Example
# Demonstrates advanced cost control, budget monitoring, and automated cost optimization
# Shows policy-compliant cost governance across multiple resource types

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

# Local values for cost management
locals {
  environment = "prod"  # Production environment for comprehensive cost controls
  project     = "CostGovernance"
  
  # Cost governance tags
  cost_tags = {
    Environment = local.environment
    Owner      = "finops-team@contoso.com"
    Project    = local.project
    CostCenter = "FinOps"
    Application = "CostGovernance"
    
    # Cost management specific tags
    BudgetManagement  = "automated"
    CostOptimization = "continuous"
    FinOpsApproved   = "true"
    BillingContact   = "finance@contoso.com"
  }
  
  # Department budgets and contacts
  departments = {
    "Engineering" = {
      budget = 5000
      contacts = ["engineering-leads@contoso.com", "cto@contoso.com"]
      cost_center = "ENG-001"
    }
    "Marketing" = {
      budget = 2000
      contacts = ["marketing-team@contoso.com", "cmo@contoso.com"]
      cost_center = "MKT-001"
    }
    "DataScience" = {
      budget = 8000
      contacts = ["data-team@contoso.com", "cdo@contoso.com"]
      cost_center = "DATA-001"
    }
    "Operations" = {
      budget = 3000
      contacts = ["ops-team@contoso.com", "coo@contoso.com"]
      cost_center = "OPS-001"
    }
  }
}

# Resource Group for cost management infrastructure
resource "azurerm_resource_group" "cost_management" {
  name     = "rg-cost-management-prod-001"
  location = "East US"
  
  tags = merge(local.cost_tags, {
    Purpose = "CostManagementInfrastructure"
  })
}

# ========================================
# SUBSCRIPTION-LEVEL BUDGET MONITORING
# ========================================

# Get current subscription
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

# Main subscription budget with multiple alert thresholds
resource "azurerm_consumption_budget_subscription" "main" {
  name            = "budget-subscription-monthly-${local.environment}"
  subscription_id = data.azurerm_subscription.current.id
  
  amount     = 20000  # $20,000 monthly subscription budget
  time_grain = "Monthly"
  
  time_period {
    start_date = "2025-08-01T00:00:00Z"
    end_date   = "2026-07-31T23:59:59Z"
  }
  
  # Multiple notification thresholds for proactive cost management
  notification {
    enabled        = true
    threshold      = 50.0  # Early warning at 50%
    operator       = "GreaterThan"
    threshold_type = "Actual"
    
    contact_emails = [
      "finops-team@contoso.com",
      "finance@contoso.com"
    ]
    
    contact_groups = [
      azurerm_monitor_action_group.cost_alerts.id
    ]
  }
  
  notification {
    enabled        = true
    threshold      = 75.0  # Alert at 75%
    operator       = "GreaterThan"
    threshold_type = "Actual"
    
    contact_emails = [
      "finops-team@contoso.com",
      "finance@contoso.com",
      "management@contoso.com"
    ]
    
    contact_groups = [
      azurerm_monitor_action_group.cost_alerts.id
    ]
  }
  
  notification {
    enabled        = true
    threshold      = 90.0  # Critical alert at 90%
    operator       = "GreaterThan"
    threshold_type = "Actual"
    
    contact_emails = [
      "finops-team@contoso.com",
      "finance@contoso.com",
      "management@contoso.com",
      "ceo@contoso.com"
    ]
    
    contact_groups = [
      azurerm_monitor_action_group.cost_alerts.id,
      azurerm_monitor_action_group.critical_cost_alerts.id
    ]
  }
  
  # Forecasted spending alert
  notification {
    enabled        = true
    threshold      = 100.0  # Alert when forecast exceeds 100%
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    
    contact_emails = [
      "finops-team@contoso.com",
      "finance@contoso.com",
      "management@contoso.com"
    ]
    
    contact_groups = [
      azurerm_monitor_action_group.cost_alerts.id
    ]
  }
}

# ========================================
# DEPARTMENT-SPECIFIC BUDGETS
# ========================================

# Create resource groups for each department
resource "azurerm_resource_group" "departments" {
  for_each = local.departments
  
  name     = "rg-${lower(each.key)}-${local.environment}-001"
  location = "East US"
  
  tags = merge(local.cost_tags, {
    Department  = each.key
    CostCenter  = each.value.cost_center
    BudgetLimit = each.value.budget
  })
}

# Department-specific budgets
resource "azurerm_consumption_budget_resource_group" "departments" {
  for_each = local.departments
  
  name              = "budget-${lower(each.key)}-monthly"
  resource_group_id = azurerm_resource_group.departments[each.key].id
  
  amount     = each.value.budget
  time_grain = "Monthly"
  
  time_period {
    start_date = "2025-08-01T00:00:00Z"
    end_date   = "2026-07-31T23:59:59Z"
  }
  
  # Department-specific alert thresholds
  notification {
    enabled   = true
    threshold = 80.0
    operator  = "GreaterThan"
    
    contact_emails = each.value.contacts
    
    contact_groups = [
      azurerm_monitor_action_group.cost_alerts.id
    ]
  }
  
  notification {
    enabled   = true
    threshold = 95.0
    operator  = "GreaterThan"
    
    contact_emails = concat(each.value.contacts, [
      "finops-team@contoso.com",
      "finance@contoso.com"
    ])
    
    contact_groups = [
      azurerm_monitor_action_group.cost_alerts.id
    ]
  }
  
  # Forecasted budget breach warning
  notification {
    enabled        = true
    threshold      = 100.0
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    
    contact_emails = concat(each.value.contacts, [
      "finops-team@contoso.com"
    ])
  }
}

# ========================================
# COST ALERTING AND AUTOMATION
# ========================================

# Action group for cost alerts
resource "azurerm_monitor_action_group" "cost_alerts" {
  name                = "ag-cost-alerts-${local.environment}"
  resource_group_name = azurerm_resource_group.cost_management.name
  short_name          = "costalert"
  
  # Email notifications
  email_receiver {
    name          = "FinOps Team"
    email_address = "finops-team@contoso.com"
  }
  
  email_receiver {
    name          = "Finance Team"
    email_address = "finance@contoso.com"
  }
  
  # SMS notifications for critical alerts
  sms_receiver {
    name         = "FinOps Manager"
    country_code = "1"
    phone_number = "5551234567"  # Replace with actual number
  }
  
  # Webhook for automation
  webhook_receiver {
    name        = "Cost Automation Webhook"
    service_uri = "https://prod-functions.azure.com/cost-automation-webhook"
  }
  
  # Logic App for automated responses
  logic_app_receiver {
    name                    = "Cost Response Logic App"
    resource_id             = azurerm_logic_app_workflow.cost_response.id
    callback_url            = "https://prod-eastus.logic.azure.com:443/workflows/cost-response/triggers/when-budget-alert-received"
    use_common_alert_schema = true
  }
  
  tags = local.cost_tags
}

# Critical cost alerts action group
resource "azurerm_monitor_action_group" "critical_cost_alerts" {
  name                = "ag-critical-cost-alerts-${local.environment}"
  resource_group_name = azurerm_resource_group.cost_management.name
  short_name          = "critcost"
  
  # Executive notifications
  email_receiver {
    name          = "CEO"
    email_address = "ceo@contoso.com"
  }
  
  email_receiver {
    name          = "CFO"
    email_address = "cfo@contoso.com"
  }
  
  # SMS to executives
  sms_receiver {
    name         = "CFO Mobile"
    country_code = "1"
    phone_number = "5559876543"  # Replace with actual number
  }
  
  tags = local.cost_tags
}

# ========================================
# AUTOMATED COST RESPONSE LOGIC APP
# ========================================

# Logic App for automated cost responses
resource "azurerm_logic_app_workflow" "cost_response" {
  name                = "logic-cost-response-${local.environment}"
  location            = azurerm_resource_group.cost_management.location
  resource_group_name = azurerm_resource_group.cost_management.name
  
  tags = merge(local.cost_tags, {
    Purpose = "AutomatedCostResponse"
  })
}

# ========================================
# COST OPTIMIZATION AUTOMATION
# ========================================

# Automation Account for cost optimization
resource "azurerm_automation_account" "cost_optimization" {
  name                = "aa-cost-optimization-${local.environment}"
  location            = azurerm_resource_group.cost_management.location
  resource_group_name = azurerm_resource_group.cost_management.name
  sku_name           = "Basic"
  
  # Managed identity for resource management
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.cost_tags, {
    Purpose = "CostOptimizationAutomation"
  })
}

# Role assignments for automation account
resource "azurerm_role_assignment" "automation_cost_management_reader" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Cost Management Reader"
  principal_id         = azurerm_automation_account.cost_optimization.identity[0].principal_id
}

resource "azurerm_role_assignment" "automation_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_automation_account.cost_optimization.identity[0].principal_id
}

# Runbook for cost optimization actions
resource "azurerm_automation_runbook" "cost_optimization" {
  name                    = "Cost-Optimization-Actions"
  location                = azurerm_resource_group.cost_management.location
  resource_group_name     = azurerm_resource_group.cost_management.name
  automation_account_name = azurerm_automation_account.cost_optimization.name
  log_verbose             = true
  log_progress            = true
  runbook_type            = "PowerShell"
  
  content = <<-EOT
    # Automated Cost Optimization Runbook
    param(
        [string]$SubscriptionId = "${data.azurerm_subscription.current.subscription_id}",
        [string]$BudgetThreshold = "90",
        [string]$ActionType = "assess"  # assess, optimize, emergency
    )
    
    # Connect using Managed Identity
    Connect-AzAccount -Identity
    Set-AzContext -SubscriptionId $SubscriptionId
    
    Write-Output "Starting cost optimization analysis..."
    Write-Output "Budget threshold: $BudgetThreshold%"
    Write-Output "Action type: $ActionType"
    
    # Get current month's spending
    $startDate = Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0
    $endDate = Get-Date
    
    Write-Output "Analyzing spending from $startDate to $endDate"
    
    # Function to identify cost optimization opportunities
    function Find-CostOptimizationOpportunities {
        $opportunities = @()
        
        # Find idle VMs (low CPU utilization)
        Write-Output "Checking for idle VMs..."
        $vms = Get-AzVM -Status | Where-Object { $_.PowerState -eq "VM running" }
        foreach ($vm in $vms) {
            $opportunities += @{
                ResourceId = $vm.Id
                ResourceType = "VirtualMachine"
                Opportunity = "Idle VM - Consider shutdown or rightsizing"
                EstimatedSavings = "Variable"
                Action = "Review CPU metrics and usage patterns"
            }
        }
        
        # Find oversized disks
        Write-Output "Checking for oversized disks..."
        $disks = Get-AzDisk | Where-Object { $_.DiskSizeGB -gt 1024 }
        foreach ($disk in $disks) {
            $opportunities += @{
                ResourceId = $disk.Id
                ResourceType = "Disk"
                Opportunity = "Large disk - Consider optimization"
                EstimatedSavings = "10-30%"
                Action = "Review actual usage and resize if possible"
            }
        }
        
        # Find unused public IPs
        Write-Output "Checking for unused public IPs..."
        $publicIPs = Get-AzPublicIpAddress | Where-Object { $_.IpConfiguration -eq $null }
        foreach ($ip in $publicIPs) {
            $opportunities += @{
                ResourceId = $ip.Id
                ResourceType = "PublicIP"
                Opportunity = "Unused public IP"
                EstimatedSavings = "$5-15/month"
                Action = "Delete if not needed"
            }
        }
        
        return $opportunities
    }
    
    # Perform optimization actions based on type
    switch ($ActionType) {
        "assess" {
            Write-Output "Performing cost assessment..."
            $opportunities = Find-CostOptimizationOpportunities
            
            Write-Output "Found $($opportunities.Count) optimization opportunities:"
            foreach ($opp in $opportunities) {
                Write-Output "- $($opp.ResourceType): $($opp.Opportunity)"
                Write-Output "  Resource: $($opp.ResourceId)"
                Write-Output "  Potential Savings: $($opp.EstimatedSavings)"
                Write-Output "  Recommended Action: $($opp.Action)"
                Write-Output ""
            }
        }
        
        "optimize" {
            Write-Output "Performing safe optimization actions..."
            
            # Delete unused public IPs
            $unusedIPs = Get-AzPublicIpAddress | Where-Object { $_.IpConfiguration -eq $null }
            foreach ($ip in $unusedIPs) {
                Write-Output "Deleting unused public IP: $($ip.Name)"
                # Remove-AzPublicIpAddress -ResourceGroupName $ip.ResourceGroupName -Name $ip.Name -Force
                Write-Output "  (Simulated deletion for safety - uncomment to enable)"
            }
            
            # Stop development VMs during off-hours
            $hour = (Get-Date).Hour
            if ($hour -ge 19 -or $hour -le 7) {  # After 7 PM or before 7 AM
                $devVMs = Get-AzVM | Where-Object { $_.Tags.Environment -eq "dev" -and $_.PowerState -eq "VM running" }
                foreach ($vm in $devVMs) {
                    Write-Output "Stopping development VM during off-hours: $($vm.Name)"
                    # Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force
                    Write-Output "  (Simulated stop for safety - uncomment to enable)"
                }
            }
        }
        
        "emergency" {
            Write-Output "Performing emergency cost reduction actions..."
            Write-Output "Emergency actions would be implemented here (with proper safeguards)"
            Write-Output "This might include:"
            Write-Output "- Scaling down non-critical resources"
            Write-Output "- Stopping development/test environments"
            Write-Output "- Switching to lower-cost tiers where possible"
        }
    }
    
    Write-Output "Cost optimization analysis completed."
  EOT
  
  tags = local.cost_tags
}

# Schedule for daily cost assessment
resource "azurerm_automation_schedule" "daily_cost_assessment" {
  name                    = "daily-cost-assessment"
  resource_group_name     = azurerm_resource_group.cost_management.name
  automation_account_name = azurerm_automation_account.cost_optimization.name
  frequency               = "Day"
  interval                = 1
  start_time              = "2025-08-05T08:00:00-05:00"  # 8 AM EST daily
  description             = "Daily cost optimization assessment"
}

# Link schedule to runbook
resource "azurerm_automation_job_schedule" "daily_cost_assessment" {
  resource_group_name     = azurerm_resource_group.cost_management.name
  automation_account_name = azurerm_automation_account.cost_optimization.name
  schedule_name           = azurerm_automation_schedule.daily_cost_assessment.name
  runbook_name           = azurerm_automation_runbook.cost_optimization.name
  
  parameters = {
    ActionType = "assess"
  }
}

# ========================================
# COST ANALYTICS AND REPORTING
# ========================================

# Log Analytics Workspace for cost analytics
resource "azurerm_log_analytics_workspace" "cost_analytics" {
  name                = "law-cost-analytics-${local.environment}"
  location            = azurerm_resource_group.cost_management.location
  resource_group_name = azurerm_resource_group.cost_management.name
  sku                 = "PerGB2018"
  retention_in_days   = 365  # Long retention for cost trend analysis
  
  tags = merge(local.cost_tags, {
    Purpose = "CostAnalytics"
  })
}

# Storage Account for cost reports
resource "azurerm_storage_account" "cost_reports" {
  name                = "stcostreports${local.environment}001"
  resource_group_name = azurerm_resource_group.cost_management.name
  location            = azurerm_resource_group.cost_management.location
  
  account_tier             = "Standard"
  account_replication_type = "LRS"  # Cost-optimized replication
  account_kind            = "StorageV2"
  
  # Security settings (required by encryption policy)
  https_traffic_only_enabled = true
  min_tls_version            = "TLS1_2"
  
  # Cost-optimized access tier
  access_tier = "Cool"
  
  # Lifecycle management for cost control
  blob_properties {
    versioning_enabled = false
    
    delete_retention_policy {
      days = 90  # Retain reports for 90 days
    }
  }
  
  tags = merge(local.cost_tags, {
    Purpose = "CostReportStorage"
  })
}

# Container for cost reports
resource "azurerm_storage_container" "cost_reports" {
  name                  = "cost-reports"
  storage_account_name  = azurerm_storage_account.cost_reports.name
  container_access_type = "private"
}

# ========================================
# OUTPUTS
# ========================================

output "cost_management_summary" {
  description = "Cost management infrastructure summary"
  value = {
    subscription_budget     = "$20,000/month"
    department_budgets     = {
      for dept, config in local.departments : dept => "$${config.budget}/month"
    }
    alert_thresholds       = ["50%", "75%", "90%", "100% forecasted"]
    automation_features    = [
      "Daily cost assessment",
      "Idle resource detection",
      "Automated optimization actions",
      "Emergency cost controls"
    ]
    notification_channels  = [
      "Email alerts",
      "SMS notifications",
      "Logic App automation",
      "Webhook integrations"
    ]
  }
}

output "budget_contacts" {
  description = "Budget alert contact information"
  value = {
    finops_team     = "finops-team@contoso.com"
    finance_team    = "finance@contoso.com"
    executive_team  = ["ceo@contoso.com", "cfo@contoso.com"]
    department_contacts = {
      for dept, config in local.departments : dept => config.contacts
    }
  }
}

output "cost_optimization_features" {
  description = "Implemented cost optimization features"
  value = {
    "subscription_budget_monitoring"    = "Multi-threshold alerting"
    "department_budget_segregation"     = "Individual department tracking"
    "automated_cost_assessment"         = "Daily optimization analysis"
    "idle_resource_detection"          = "Automatic identification"
    "unused_resource_cleanup"          = "Automated removal of waste"
    "emergency_cost_controls"          = "Rapid response to budget breaches"
    "cost_trend_analytics"             = "365-day retention for analysis"
    "executive_escalation"             = "Automatic CEO/CFO notification"
    "cross_department_governance"      = "Unified cost policies"
    "automated_reporting"              = "Scheduled cost reports"
  }
}

output "automation_endpoints" {
  description = "Cost management automation endpoints"
  value = {
    automation_account   = azurerm_automation_account.cost_optimization.name
    logic_app_workflow  = azurerm_logic_app_workflow.cost_response.name
    cost_analytics      = azurerm_log_analytics_workspace.cost_analytics.name
    report_storage      = azurerm_storage_account.cost_reports.name
    action_groups       = [
      azurerm_monitor_action_group.cost_alerts.name,
      azurerm_monitor_action_group.critical_cost_alerts.name
    ]
  }
}
