# Policy Configuration Guide

Configuration options for customizing Azure Sentinel policies to match your organization's requirements.

## Enforcement Levels

- `advisory`: Shows violations but allows deployment (good for testing)
- `soft-mandatory`: Prevents deployment but allows manual override
- `hard-mandatory`: Always blocks deployment on violation

## Environment Detection

Policies automatically detect environments from workspace names:
- Names containing `prod` → production
- Names containing `staging` or `stage` → staging  
- Names containing `dev` or `development` → development

Override with explicit `environment` parameter if needed.

## Policy-Specific Configuration

### Mandatory Tags Policy

```hcl
policy "azure-mandatory-tags" {
    source = "./policies/azure-mandatory-tags.sentinel"
    enforcement_level = "hard-mandatory"
    
    params = {
        mandatory_tags = ["Environment", "Owner", "Project", "CostCenter"]
        
        # Environment-specific additional tags
        environment_specific_tags = {
            "prod" = ["BackupPolicy", "ComplianceLevel"]
            "staging" = ["BackupPolicy"]
            "dev" = []
        }
        
        tag_value_min_length = 2
        tag_value_max_length = 100
    }
}
```

**Industry-specific examples:**

Healthcare (HIPAA):
```hcl
mandatory_tags = [
    "Environment", "Owner", "Project", "CostCenter",
    "DataClassification", "PHIData", "ComplianceLevel"
]
```

Financial Services (SOX):
```hcl
mandatory_tags = [
    "Environment", "Owner", "Project", "CostCenter", 
    "SOXScope", "DataRetention", "AuditTrail"
]
```

### VM Instance Types Policy

```hcl
policy "azure-vm-instance-types" {
    params = {
        allowed_vm_sizes = {
            "prod" = [
                "Standard_D2s_v3", "Standard_D4s_v3", "Standard_D8s_v3",
                "Standard_E2s_v3", "Standard_E4s_v3"
            ]
            "staging" = [
                "Standard_B2s", "Standard_B4ms", 
                "Standard_D2s_v3", "Standard_D4s_v3"
            ]
            "dev" = ["Standard_B1s", "Standard_B1ms", "Standard_B2s"]
        }
        
        require_premium_storage_prod = true
        require_availability_zones_prod = true
        
        max_vm_count_per_deployment = {
            "prod" = 10, "staging" = 5, "dev" = 3
        }
    }
}
```

**Cost-optimized version:**
```hcl
allowed_vm_sizes = {
    "prod" = ["Standard_B2s", "Standard_B4ms"],  # Burstable only
    "staging" = ["Standard_B1s", "Standard_B2s"], 
    "dev" = ["Standard_B1s"]
}
require_premium_storage_prod = false  # Use Standard SSD
```

### Storage Encryption Policy

```hcl  
policy "azure-storage-encryption" {
    params = {
        require_customer_managed_keys_prod = true
        require_https_only = true
        allowed_tls_versions = ["TLS1_2"]
        require_infrastructure_encryption = true
    }
}
```

### Network Security Policy

```hcl
policy "azure-network-security" {
    params = {
        allowed_public_ports = [80, 443]  # Only HTTP/HTTPS
        allowed_management_ports = [22, 3389, 5985, 5986]
        
        require_ddos_protection_prod = true
        require_private_endpoints_prod = true
        
        max_priority_threshold = 1000  # NSG rule priority limit
    }
}
```

**Zero-trust configuration:**
```hcl
allowed_public_ports = [443]  # HTTPS only
allowed_management_ports = []  # No public management access
max_priority_threshold = 500  # Stricter priority rules
```

### Cost Control Policy

```hcl
policy "azure-cost-control" {
    params = {
        monthly_cost_limits = {
            "prod" = 10000, "staging" = 3000, "dev" = 1000
        }
        
        cost_increase_percentage_limit = 50
        
        expensive_resource_types = [
            "azurerm_hdinsight_hadoop_cluster",
            "azurerm_synapse_workspace",
            "azurerm_databricks_workspace"
        ]
        
        max_resource_counts = {
            "prod" = {"azurerm_virtual_machine" = 20}
            "staging" = {"azurerm_virtual_machine" = 10}
            "dev" = {"azurerm_virtual_machine" = 5}
        }
        
        require_cost_center_tag = true
        allowed_cost_centers = ["Engineering", "Marketing", "Sales"]
    }
}
```

**Startup/SMB version:**
```hcl
monthly_cost_limits = {
    "prod" = 2000, "staging" = 500, "dev" = 200
}
cost_increase_percentage_limit = 25  # Stricter control
```

### Resource Naming Policy

```hcl
policy "azure-resource-naming" {
    params = {
        # Template: prefix-resourcetype-purpose-environment-sequence
        organization_prefix = "contoso"
        
        environment_abbreviations = {
            "dev" = "dev", "staging" = "stg", "prod" = "prd"
        }
        
        resource_type_abbreviations = {
            "azurerm_resource_group" = "rg"
            "azurerm_virtual_machine" = "vm"
            "azurerm_storage_account" = "st"
            "azurerm_app_service" = "app"
        }
        
        max_name_length = {
            "azurerm_storage_account" = 24
            "azurerm_key_vault" = 24
            "default" = 80
        }
        
        prohibited_words = ["test", "temp", "delete"]
        require_sequence_number = true
    }
}
```

**Microsoft CAF aligned:**
```hcl
environment_abbreviations = {
    "dev" = "d", "staging" = "t", "prod" = "p"  # Single character
}
resource_type_abbreviations = {
    "azurerm_virtual_network" = "vnet"
    "azurerm_network_security_group" = "nsg"
    "azurerm_kubernetes_cluster" = "aks"
    # ... following CAF naming conventions
}
```

## Advanced Configuration

### Multi-Region Deployment
```hcl
policy "azure-mandatory-tags-eastus" {
    params = {
        mandatory_tags = ["Environment", "Owner", "Project", "Region"]
        region_specific_tags = {
            "eastus" = ["DisasterRecovery"]
            "westus" = ["BackupSite"]
        }
    }
}
```

### Conditional Policy Application
```hcl
# Apply stricter policies to production workspaces only
policy "azure-cost-control-prod" {
    workspace_filter = "prod-*"
    params = {
        monthly_cost_limits = {"prod" = 5000}  # Stricter limit
        cost_increase_percentage_limit = 25
    }
}
```

### External System Integration

**ServiceNow integration:**
```hcl
mandatory_tags = [
    "Environment", "Owner", "Project", "CostCenter",
    "ServiceNowCMDB", "ChangeRequest"
]
tag_validation_patterns = {
    "ServiceNowCMDB" = "^CMDB[0-9]{6}$"
    "ChangeRequest" = "^CHG[0-9]{7}$"
}
```

## Testing Configuration Changes

1. Test in development first:
   ```bash
   sentinel test -global environment=dev
   ```

2. Validate with mock data:
   ```bash
   sentinel test test/azure-mandatory-tags/
   ```

3. Check all policies:
   ```bash
   make test
   ```

## Troubleshooting

**Policy not triggering:**
- Check workspace name matches environment detection patterns
- Verify resource types are included in policy filters
- Ensure enforcement level isn't "advisory" if expecting blocks

**Too many false positives:**
- Adjust parameter values (increase cost limits, etc.)
- Add exceptions for computed values
- Use "soft-mandatory" during tuning

**Performance issues:**
- Optimize resource filtering in custom policies
- Reduce nested loops
- Use early returns for quick validation

## Best Practices

1. Start with "advisory" enforcement and gradually increase
2. Use similar policies across environments with different parameters
3. Review and update policies quarterly based on violation patterns
4. Document all customizations and exceptions
5. Maintain test coverage for all parameter combinations
6. Track policy violation trends over time

## Parameter Reference

For complete parameter documentation, see the policy source files in the `policies/` directory. Each policy includes parameter defaults and validation rules in the header comments.
