# Azure Terraform Sentinel Policies

HashiCorp Sentinel policies for Azure infrastructure governance. Covers security, cost control, and compliance requirements with reasonable defaults and clear violation messages.

## Why These Policies Exist

Teams often struggle with Azure governance - VMs get deployed with weak security, storage accounts lack encryption, and dev environments rack up production-level costs. These policies catch issues before deployment rather than after.

Policies default to DENY when validation fails. Unknown/computed values are handled gracefully without false positives.

## Available Policies

| Policy | Purpose | Enforcement |
|--------|---------|-------------|
| azure-mandatory-tags | Requires Environment, Owner, Project, CostCenter tags | Hard |
| azure-vm-instance-types | Restricts VM sizes by environment (B-series for dev, etc.) | Soft |
| azure-storage-encryption | Forces HTTPS-only and encryption at rest | Hard |
| azure-network-security | Blocks 0.0.0.0/0 sources (except ports 80/443) | Hard |
| azure-cost-control | Prevents monthly cost overruns | Soft |
| azure-resource-naming | Enforces naming conventions | Soft |
| azure-backup-compliance | Validates backup configurations for production | Soft |

Environment detection is automatic from workspace names containing `prod`, `staging`/`stage`, or `dev`/`development`.

## Quick Start

1. Add this repository as a Policy Set in your Terraform Cloud organization
2. Assign the policy set to your workspaces
3. Customize enforcement levels in `sentinel.hcl` if needed

Start with `advisory` enforcement to see what violations would occur, then graduate to `soft-mandatory` or `hard-mandatory`.

## Common Violations and Fixes

### Missing Required Tags
```hcl
# Before - will fail
resource "azurerm_resource_group" "example" {
  name     = "rg-example"
  location = "East US"
}

# After - will pass
resource "azurerm_resource_group" "example" {
  name     = "rg-example"
  location = "East US"
  
  tags = {
    Environment = "prod"
    Owner      = "team@company.com"
    Project    = "WebApp"
    CostCenter = "Engineering"
  }
}
```

### VM Size Too Large for Development
```hcl
# Before - will warn in dev environment
resource "azurerm_linux_virtual_machine" "web" {
  size = "Standard_D16s_v3"  # Expensive for dev
}

# After - will pass
resource "azurerm_linux_virtual_machine" "web" {
  size = "Standard_B2s"  # Burstable, cost-effective
}
```

### Storage Not Encrypted
```hcl
# Before - will fail
resource "azurerm_storage_account" "data" {
  name = "mystorageaccount"
}

# After - will pass
resource "azurerm_storage_account" "data" {
  name = "mystorageaccount"
  https_traffic_only_enabled = true
  min_tls_version            = "TLS1_2"
}
```

## Configuration

### Basic Policy Setup
```hcl
# sentinel.hcl
policy "azure-mandatory-tags" {
    source = "./policies/azure-mandatory-tags.sentinel"
    enforcement_level = "hard-mandatory"
}

policy "azure-cost-control" {
    source = "./policies/azure-cost-control.sentinel"  
    enforcement_level = "soft-mandatory"
    
    params = {
        monthly_cost_limits = {
            "prod" = 15000
            "staging" = 5000
            "dev" = 2000
        }
    }
}
```

### Customizing Tag Requirements
```hcl
policy "azure-mandatory-tags" {
    params = {
        mandatory_tags = [
            "Environment",
            "Owner", 
            "Project",
            "CostCenter",
            "BusinessUnit"  # Add your required tags
        ]
    }
}
```

### Adjusting VM Size Limits
```hcl
policy "azure-vm-instance-types" {
    params = {
        allowed_vm_sizes = {
            "prod" = ["Standard_D2s_v3", "Standard_D4s_v3", "Standard_E2s_v3"]
            "dev" = ["Standard_B1s", "Standard_B2s"]  # Keep dev cheap
        }
    }
}
```

## Testing

```bash
# Test all policies
sentinel test

# Test specific policy with verbose output
sentinel test -verbose policies/azure-mandatory-tags.sentinel

# Format policy files
sentinel fmt policies/
```

Tests are in the `test/` directory with realistic mock data for each scenario.

## Policy Details

### Cost Control Logic
The cost control policy uses Terraform Cloud's cost estimation API to check:
- Monthly cost increases vs. environment limits
- Percentage increases vs. previous deployments
- Resource count limits (e.g., max 5 VMs in dev)
- Expensive resource types (Databricks, HDInsight) blocked in non-prod

Cost limits default to $10K prod, $3K staging, $1K dev but are configurable.

### Network Security Logic
Blocks NSG rules with source `0.0.0.0/0` except for ports 80 and 443. Management ports (22, 3389) must use specific IP ranges.

Production environments require DDoS protection on VNets and WAF on Application Gateways.

### Tag Validation
Validates tag presence, minimum length (2 chars), and specific format requirements:
- Environment must be one of: dev, staging, prod, test, qa
- Owner should be an email address
- CostCenter validated against allowed list if configured

Computed/unknown values are allowed to pass (avoids false positives).

## Rollout Strategy

1. **Phase 1**: Deploy with `advisory` enforcement to development workspaces
2. **Phase 2**: Enable `soft-mandatory` in staging after fixing initial violations
3. **Phase 3**: Graduate to `hard-mandatory` in production
4. **Phase 4**: Apply lessons learned and roll out to all environments

Monitor violation rates and adjust parameters based on team feedback.

## Contributing

See `CONFIGURATION.md` for detailed parameter documentation.

1. Fork the repository
2. Add/modify policies with comprehensive tests
3. Test changes with `sentinel test`
4. Submit a pull request

Follow the existing patterns for error messages and parameter validation.

## License

MIT License - see LICENSE file for details.

## Support

- Create an issue for bugs or feature requests
- Check the `examples/` directory for usage patterns
- Review `test/` directory for mock data examples
