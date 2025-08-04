# Azure Sentinel Policy Configuration Guide

This guide provides detailed information on configuring and customizing the Azure Terraform Sentinel policies for your organization.

## Table of Contents
- [Policy Enforcement Levels](#policy-enforcement-levels)
- [Environment Configuration](#environment-configuration)
- [Policy-Specific Configuration](#policy-specific-configuration)
- [Parameter Customization](#parameter-customization)
- [Advanced Configuration](#advanced-configuration)

## Policy Enforcement Levels

Sentinel supports three enforcement levels:

### Advisory
- **Description**: Policy violations are logged but do not prevent deployment
- **Use Case**: New policies in testing, informational warnings
- **Example**: `enforcement_level = "advisory"`

### Soft Mandatory
- **Description**: Policy violations prevent deployment but can be overridden
- **Use Case**: Production policies with business override capability
- **Example**: `enforcement_level = "soft-mandatory"`

### Hard Mandatory
- **Description**: Policy violations always prevent deployment
- **Use Case**: Critical security and compliance requirements
- **Example**: `enforcement_level = "hard-mandatory"`

## Environment Configuration

Policies automatically detect environments from workspace names, but you can override this behavior:

### Automatic Detection
```hcl
# Workspace names containing these strings map to environments:
# *prod* → production
# *staging* or *stage* → staging  
# *dev* or *development* → development
```

### Manual Override
```hcl
policy "azure-mandatory-tags" {
    source = "./policies/azure-mandatory-tags.sentinel"
    enforcement_level = "hard-mandatory"
    
    params = {
        environment = "prod"  # Override automatic detection
    }
}
```

## Policy-Specific Configuration

### Azure Mandatory Tags Policy

#### Basic Configuration
```hcl
policy "azure-mandatory-tags" {
    source = "./policies/azure-mandatory-tags.sentinel"
    enforcement_level = "hard-mandatory"
    
    params = {
        # Required tags for all environments
        mandatory_tags = [
            "Environment",
            "Owner", 
            "Project",
            "CostCenter",
            "Application"
        ]
        
        # Environment-specific additional tags
        environment_specific_tags = {
            "prod" = [
                "BackupPolicy",
                "ComplianceLevel", 
                "DataClassification"
            ]
            "staging" = [
                "BackupPolicy",
                "ComplianceLevel"
            ]
            "dev" = []
        }
        
        # Tag value validation
        tag_value_min_length = 2
        tag_value_max_length = 100
    }
}
```

#### Industry-Specific Configurations

**Healthcare (HIPAA Compliance)**
```hcl
params = {
    mandatory_tags = [
        "Environment", "Owner", "Project", "CostCenter",
        "DataClassification", "PHIData", "ComplianceLevel"
    ]
    environment_specific_tags = {
        "prod" = ["BackupPolicy", "EncryptionLevel", "AccessControl"]
    }
}
```

**Financial Services (SOX Compliance)**
```hcl
params = {
    mandatory_tags = [
        "Environment", "Owner", "Project", "CostCenter", 
        "SOXScope", "DataRetention", "AuditTrail"
    ]
}
```

### Azure VM Instance Types Policy

#### Basic Configuration
```hcl
policy "azure-vm-instance-types" {
    source = "./policies/azure-vm-instance-types.sentinel" 
    enforcement_level = "soft-mandatory"
    
    params = {
        # Allowed VM sizes by environment
        allowed_vm_sizes = {
            "prod" = [
                "Standard_D2s_v3", "Standard_D4s_v3", "Standard_D8s_v3",
                "Standard_E2s_v3", "Standard_E4s_v3", "Standard_E8s_v3"
            ]
            "staging" = [
                "Standard_B2s", "Standard_B4ms", "Standard_B8ms",
                "Standard_D2s_v3", "Standard_D4s_v3"
            ]
            "dev" = [
                "Standard_B1s", "Standard_B1ms", "Standard_B2s"
            ]
        }
        
        # Production requirements
        require_premium_storage_prod = true
        require_availability_zones_prod = true
        
        # Resource limits
        max_vm_count_per_deployment = {
            "prod" = 10
            "staging" = 5
            "dev" = 3
        }
    }
}
```

#### Cost-Optimized Configuration
```hcl
params = {
    allowed_vm_sizes = {
        "prod" = ["Standard_B2s", "Standard_B4ms", "Standard_B8ms"]
        "staging" = ["Standard_B1s", "Standard_B2s"] 
        "dev" = ["Standard_B1s"]
    }
    require_premium_storage_prod = false  # Use Standard SSD
    max_vm_count_per_deployment = {
        "prod" = 5
        "staging" = 3
        "dev" = 2
    }
}
```

### Azure Storage Encryption Policy

#### Basic Configuration
```hcl
policy "azure-storage-encryption" {
    source = "./policies/azure-storage-encryption.sentinel"
    enforcement_level = "hard-mandatory"
    
    params = {
        # Encryption requirements
        require_customer_managed_keys_prod = true
        require_https_only = true
        require_secure_transfer = true
        
        # TLS configuration
        allowed_tls_versions = ["TLS1_2"]
        
        # Service encryption
        require_blob_encryption = true
        require_file_encryption = true
        require_queue_encryption = true
        require_table_encryption = true
    }
}
```

#### High-Security Configuration
```hcl
params = {
    require_customer_managed_keys_prod = true
    require_https_only = true
    allowed_tls_versions = ["TLS1_2"]  # Only TLS 1.2
    require_infrastructure_encryption = true
    require_blob_encryption = true
    require_file_encryption = true
    require_queue_encryption = true
    require_table_encryption = true
}
```

### Azure Network Security Policy

#### Basic Configuration
```hcl
policy "azure-network-security" {
    source = "./policies/azure-network-security.sentinel"
    enforcement_level = "hard-mandatory"
    
    params = {
        # Allowed public ports
        allowed_public_ports = [80, 443]
        
        # Management ports (restricted access)
        allowed_management_ports = [22, 3389, 5985, 5986]
        
        # Production requirements
        require_ddos_protection_prod = true
        require_private_endpoints_prod = true
        require_network_watcher = true
        
        # Rule validation
        max_priority_threshold = 1000
        allowed_protocols = ["TCP", "UDP", "ICMP", "*"]
    }
}
```

#### Zero-Trust Configuration
```hcl
params = {
    allowed_public_ports = [443]  # HTTPS only
    allowed_management_ports = []  # No public management access
    require_ddos_protection_prod = true
    require_private_endpoints_prod = true
    require_network_watcher = true
    max_priority_threshold = 500  # Stricter priority rules
}
```

### Azure Cost Control Policy

#### Basic Configuration
```hcl
policy "azure-cost-control" {
    source = "./policies/azure-cost-control.sentinel"
    enforcement_level = "soft-mandatory"
    
    params = {
        # Monthly cost limits by environment
        monthly_cost_limits = {
            "prod" = decimal.new(10000)
            "staging" = decimal.new(3000)  
            "dev" = decimal.new(1000)
        }
        
        # Cost increase limits
        cost_increase_percentage_limit = 50
        
        # Expensive resource restrictions
        expensive_resource_types = [
            "azurerm_hdinsight_hadoop_cluster",
            "azurerm_synapse_workspace",
            "azurerm_databricks_workspace"
        ]
        
        # Resource count limits
        max_resource_counts = {
            "prod" = {
                "azurerm_virtual_machine" = 20
                "azurerm_kubernetes_cluster" = 5
            }
            "staging" = {
                "azurerm_virtual_machine" = 10
                "azurerm_kubernetes_cluster" = 3
            }
            "dev" = {
                "azurerm_virtual_machine" = 5
                "azurerm_kubernetes_cluster" = 2
            }
        }
        
        # Cost center validation
        require_cost_center_tag = true
        allowed_cost_centers = [
            "Engineering", "Marketing", "Sales", "Operations"
        ]
    }
}
```

#### Startup/SMB Configuration
```hcl
params = {
    monthly_cost_limits = {
        "prod" = decimal.new(2000)
        "staging" = decimal.new(500)
        "dev" = decimal.new(200)
    }
    cost_increase_percentage_limit = 25  # Stricter control
    expensive_resource_types = [
        "azurerm_hdinsight_hadoop_cluster",
        "azurerm_synapse_workspace", 
        "azurerm_databricks_workspace",
        "azurerm_kubernetes_cluster"  # Additional restriction
    ]
}
```

### Azure Resource Naming Policy

#### Basic Configuration
```hcl
policy "azure-resource-naming" {
    source = "./policies/azure-resource-naming.sentinel"
    enforcement_level = "soft-mandatory"
    
    params = {
        # Naming convention template
        naming_convention = "prefix-resourcetype-purpose-environment-sequence"
        
        # Environment abbreviations
        environment_abbreviations = {
            "dev" = "dev"
            "staging" = "stg"
            "prod" = "prd"
        }
        
        # Resource type abbreviations  
        resource_type_abbreviations = {
            "azurerm_resource_group" = "rg"
            "azurerm_virtual_machine" = "vm"
            "azurerm_storage_account" = "st"
            "azurerm_app_service" = "app"
        }
        
        # Organization settings
        organization_prefix = "contoso"
        
        # Length restrictions
        max_name_length = {
            "azurerm_storage_account" = 24
            "azurerm_key_vault" = 24
            "default" = 80
        }
        min_name_length = 3
        
        # Validation rules
        prohibited_words = ["test", "temp", "delete", "remove"]
        require_sequence_number = true
    }
}
```

#### Microsoft CAF Aligned Configuration
```hcl
params = {
    organization_prefix = "contoso"
    environment_abbreviations = {
        "dev" = "d"
        "staging" = "t"  # Test
        "prod" = "p"
    }
    resource_type_abbreviations = {
        # Following Microsoft CAF recommendations
        "azurerm_resource_group" = "rg"
        "azurerm_virtual_network" = "vnet"
        "azurerm_subnet" = "snet"
        "azurerm_network_security_group" = "nsg"
        "azurerm_virtual_machine" = "vm"
        "azurerm_storage_account" = "st"
        "azurerm_key_vault" = "kv"
        "azurerm_app_service" = "app"
        "azurerm_sql_server" = "sql"
        "azurerm_kubernetes_cluster" = "aks"
    }
}
```

### Azure Backup Compliance Policy

#### Basic Configuration
```hcl
policy "azure-backup-compliance" {
    source = "./policies/azure-backup-compliance.sentinel"
    enforcement_level = "soft-mandatory"
    
    params = {
        # Backup requirements
        require_backup_prod = true
        require_cross_region_backup_prod = true
        require_backup_encryption = true
        
        # Backup policy requirements by environment
        backup_policy_requirements = {
            "prod" = {
                "daily_backup" = true
                "retention_days" = 30
                "weekly_retention_weeks" = 12
                "monthly_retention_months" = 12
                "yearly_retention_years" = 7
            }
            "staging" = {
                "daily_backup" = true
                "retention_days" = 14
                "weekly_retention_weeks" = 4
            }
            "dev" = {
                "daily_backup" = false
                "retention_days" = 7
            }
        }
        
        # Critical resource types requiring backup
        critical_resource_types = [
            "azurerm_virtual_machine",
            "azurerm_sql_database",
            "azurerm_storage_account"
        ]
    }
}
```

## Advanced Configuration

### Multi-Region Deployment
```hcl
# Configure different policies for different regions
policy "azure-mandatory-tags-eastus" {
    source = "./policies/azure-mandatory-tags.sentinel"
    enforcement_level = "hard-mandatory"
    
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
# Apply stricter policies to production workspaces
policy "azure-cost-control-prod" {
    source = "./policies/azure-cost-control.sentinel"
    enforcement_level = "hard-mandatory"
    
    # Only apply to production workspaces
    workspace_filter = "prod-*"
    
    params = {
        monthly_cost_limits = {
            "prod" = decimal.new(5000)  # Stricter limit
        }
        cost_increase_percentage_limit = 25
    }
}
```

### Integration with External Systems

#### ServiceNow Integration
```hcl
params = {
    mandatory_tags = [
        "Environment", "Owner", "Project", "CostCenter",
        "ServiceNowCMDB", "ChangeRequest"
    ]
    tag_validation_patterns = {
        "ServiceNowCMDB" = "^CMDB[0-9]{6}$"
        "ChangeRequest" = "^CHG[0-9]{7}$"
    }
}
```

#### ITSM Integration
```hcl
params = {
    mandatory_tags = [
        "Environment", "Owner", "Project", "CostCenter",
        "ITSMTicket", "ApprovalID"
    ]
    require_approval_tags_prod = true
}
```

## Testing Configuration Changes

Before deploying configuration changes to production:

1. **Test in Development**
   ```bash
   sentinel test -global environment=dev
   ```

2. **Validate with Mock Data**
   ```bash
   sentinel test test/azure-mandatory-tags/
   ```

3. **Run Full Test Suite**
   ```bash
   make test
   ```

4. **Check Policy Coverage**
   ```bash
   make policy-analysis
   ```

## Troubleshooting Common Issues

### Policy Not Triggering
- Check workspace name matches environment detection patterns
- Verify resource types are included in policy filters
- Ensure enforcement level is not "advisory" if expecting blocks

### Too Many False Positives
- Adjust parameter values (e.g., increase cost limits)
- Add exceptions for computed values
- Use "soft-mandatory" enforcement during tuning

### Performance Issues
- Optimize resource filtering
- Reduce nested loops in custom policies
- Use early returns for quick validation

## Best Practices

1. **Start Conservative**: Begin with "advisory" enforcement and gradually increase
2. **Environment Parity**: Use similar policies across environments with different parameters
3. **Regular Reviews**: Review and update policies quarterly
4. **Documentation**: Document all customizations and exceptions
5. **Testing**: Maintain comprehensive test coverage
6. **Monitoring**: Track policy violation trends over time

## Support and Maintenance

For questions or issues with policy configuration:

1. Review the policy source code for parameter definitions
2. Check test cases for configuration examples
3. Create an issue in the repository for bugs or feature requests
4. Consult HashiCorp Sentinel documentation for advanced features
