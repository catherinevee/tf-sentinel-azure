# Azure Terraform Sentinel Policies

A comprehensive collection of production-ready HashiCorp Sentinel policies for Azure infrastructure governance, security, cost control, and compliance.

## 🛡️ Security-First Design

These policies are built with **security-first principles**:
- **Fail-Secure Defaults**: Policies default to DENY when uncertain
- **Defense in Depth**: Mu#### Monitoring Success
- Track policy compliance rates over time
- Monitor cost savings from cost control policies
- Gather feedback from development teams
- Regular policy effectiveness reviews

## ⚡ Quick Reference

### Common Commands
```bash
# Test all policies
sentinel test

# Format all policy files
sentinel fmt policies/

# Test specific policy with verbose output
sentinel test -verbose policies/azure-mandatory-tags.sentinel

# Apply policy to a Terraform plan
sentinel apply -config=config.hcl policies/azure-cost-control.sentinel
```

### Enforcement Levels
| Level | Description | Behavior |
|-------|-------------|----------|
| `advisory` | Information only | Shows violations but allows deployment |
| `soft-mandatory` | Warning with override | Shows violations, allows manual override |
| `hard-mandatory` | Blocking | Prevents deployment on violation |

### Environment Detection
Policies automatically detect environment from workspace names:
- **Production**: `*prod*`, `*production*`
- **Staging**: `*stag*`, `*staging*`, `*stage*`  
- **Development**: `*dev*`, `*development*`, `*test*`

### Quick Policy Fixes
```hcl
# Fix missing tags
resource "azurerm_resource_group" "example" {
  tags = {
    Environment = "prod"
    Owner      = "team@company.com"
    Project    = "MyApp"
    CostCenter = "IT-001"
    Application = "WebPortal"
  }
}

# Fix VM size for development
resource "azurerm_linux_virtual_machine" "web" {
  size = "Standard_B2s"  # Use burstable for dev
}

# Fix storage encryption
resource "azurerm_storage_account" "data" {
  https_traffic_only_enabled = true
  min_tls_version           = "TLS1_2"
}

# Fix network security
resource "azurerm_network_security_rule" "web" {
  source_address_prefix = "10.0.0.0/16"  # Don't use 0.0.0.0/0
}
```

### Cost Optimization Examples
See the `examples/` directory for comprehensive cost optimization patterns:
- `cost-optimized-web-app.tf`: 85% cost reduction strategies
- `cost-effective-databases.tf`: Serverless and burstable tiers
- `cost-optimized-compute.tf`: Spot instances and auto-scaling
- `comprehensive-cost-management.tf`: Enterprise cost governance

## 🔧 Configurationlayers of validation and error handling
- **Input Validation**: Comprehensive validation and sanitization of all inputs
- **Least Privilege**: Explicit allow lists rather than deny lists
- **Comprehensive Error Handling**: Actionable error messages for violations

## 📋 Policy Overview

| Policy | Description | Enforcement | Scope |
|--------|-------------|-------------|-------|
| **azure-mandatory-tags** | Enforces mandatory tagging standards | Hard Mandatory | All Azure resources |
| **azure-vm-instance-types** | Controls VM sizes and configurations | Soft Mandatory | VMs, Scale Sets |
| **azure-storage-encryption** | Ensures encryption at rest and in transit | Hard Mandatory | Storage, Disks, Data Lakes |
| **azure-network-security** | Prevents overly permissive network rules | Hard Mandatory | NSGs, VNets, App Gateway |
| **azure-cost-control** | Enforces cost limits and optimization | Soft Mandatory | All resources |
| **azure-resource-naming** | Ensures consistent naming conventions | Soft Mandatory | Named resources |
| **azure-backup-compliance** | Validates backup and recovery settings | Soft Mandatory | Critical resources |

## 🚀 Quick Start

### Prerequisites
- HashiCorp Terraform Cloud/Enterprise
- Sentinel enabled on your workspace
- Azure provider configured

### Deployment

1. **Clone the repository:**
```bash
git clone https://github.com/your-org/tf-sentinel-azure.git
cd tf-sentinel-azure
```

2. **Configure your policy set in Terraform Cloud:**
   - Create a new Policy Set
   - Connect to this repository
   - Assign to your workspaces

3. **Customize parameters:**
   Edit `sentinel.hcl` to adjust enforcement levels and parameters for your environment.

## � Usage Instructions

### Step 1: Terraform Cloud/Enterprise Setup

#### Option A: Using Terraform Cloud UI
1. **Navigate to Policy Sets** in your Terraform Cloud organization
2. **Create New Policy Set**:
   - Name: `Azure Sentinel Policies`
   - Description: `Production-ready Azure governance policies`
   - Source: `Version Control System`
3. **Connect Repository**:
   - Choose your VCS provider
   - Select this repository
   - Set working directory: `/` (root)
4. **Configure Workspaces**:
   - Assign to specific workspaces or workspace tags
   - Consider starting with development workspaces first

#### Option B: Using Terraform Configuration
```hcl
resource "tfe_policy_set" "azure_governance" {
  name         = "azure-sentinel-policies"
  description  = "Production-ready Azure governance policies"
  organization = var.organization_name
  
  vcs_repo {
    identifier         = "your-org/tf-sentinel-azure"
    branch            = "main"
    ingress_submodules = false
    oauth_token_id    = var.oauth_token_id
  }
  
  workspace_ids = [
    tfe_workspace.production.id,
    tfe_workspace.staging.id,
    tfe_workspace.development.id
  ]
}
```

### Step 2: Policy Configuration

#### Basic Configuration
The `sentinel.hcl` file defines your policy enforcement:

```hcl
# Production-ready configuration
policy "azure-mandatory-tags" {
    source = "./policies/azure-mandatory-tags.sentinel"
    enforcement_level = "hard-mandatory"  # Blocks deployment on violation
}

policy "azure-storage-encryption" {
    source = "./policies/azure-storage-encryption.sentinel"  
    enforcement_level = "hard-mandatory"  # Critical security requirement
}

policy "azure-vm-instance-types" {
    source = "./policies/azure-vm-instance-types.sentinel"
    enforcement_level = "soft-mandatory"  # Warning, but allows deployment
}
```

#### Advanced Configuration with Parameters
```hcl
policy "azure-mandatory-tags" {
    source = "./policies/azure-mandatory-tags.sentinel"
    enforcement_level = "hard-mandatory"
    
    # Custom parameters for your organization
    params = {
        # Required tags for all resources
        mandatory_tags = [
            "Environment",
            "Owner", 
            "Project",
            "CostCenter",
            "Application",
            "BusinessUnit"
        ]
        
        # Tag validation rules
        tag_value_min_length = 3
        owner_email_required = true
        environment_values = ["dev", "staging", "prod"]
        
        # Organization-specific settings
        organization_prefix = "contoso"
        enforce_naming_convention = true
    }
}

policy "azure-cost-control" {
    source = "./policies/azure-cost-control.sentinel"
    enforcement_level = "soft-mandatory"
    
    params = {
        # Monthly cost limits by environment
        cost_limits = {
            "prod"    = 15000  # $15K for production
            "staging" = 5000   # $5K for staging  
            "dev"     = 2000   # $2K for development
        }
        
        # Expensive resource restrictions
        expensive_vm_sizes = [
            "Standard_E64s_v3",
            "Standard_M128s",
            "Standard_G5"
        ]
        
        # Cost increase thresholds
        max_cost_increase_percent = 25
    }
}
```

### Step 3: Environment-Specific Enforcement

#### Graduated Enforcement Strategy
```hcl
# Development: Lenient for learning
policy "azure-mandatory-tags" {
    source = "./policies/azure-mandatory-tags.sentinel"
    enforcement_level = "advisory"  # Only warnings
}

# Staging: Soft enforcement for testing
policy "azure-mandatory-tags" {
    source = "./policies/azure-mandatory-tags.sentinel"
    enforcement_level = "soft-mandatory"  # Warning + manual override
}

# Production: Strict enforcement
policy "azure-mandatory-tags" {
    source = "./policies/azure-mandatory-tags.sentinel"
    enforcement_level = "hard-mandatory"  # Blocks deployment
}
```

#### Workspace-Specific Configuration
```hcl
# Use different enforcement based on workspace
locals {
  is_production = can(regex("prod", var.workspace_name))
  is_staging    = can(regex("stag", var.workspace_name))
}

policy "azure-storage-encryption" {
    source = "./policies/azure-storage-encryption.sentinel"
    enforcement_level = local.is_production ? "hard-mandatory" : "soft-mandatory"
}
```

### Step 4: Testing Your Policies

#### Validate Configuration Syntax
```bash
# Check sentinel.hcl syntax
sentinel fmt sentinel.hcl

# Validate policy syntax
sentinel fmt policies/
```

#### Run Policy Tests
```bash
# Test all policies with mock data
sentinel test

# Test specific policy
sentinel test policies/azure-mandatory-tags.sentinel

# Run with verbose output for debugging
sentinel test -verbose

# Test only passing cases
sentinel test -run pass

# Test only failing cases  
sentinel test -run fail
```

#### Test Against Real Terraform Plans
```bash
# Generate a Terraform plan
terraform plan -out=plan.tfplan

# Convert to JSON for Sentinel
terraform show -json plan.tfplan > plan.json

# Test policies against real plan
sentinel apply -config=config.hcl policies/azure-mandatory-tags.sentinel
```

### Step 5: Monitoring and Troubleshooting

#### Viewing Policy Results
1. **Terraform Cloud UI**:
   - Navigate to workspace → Runs
   - Click on a run to see policy evaluation results
   - Review violations and recommendations

2. **Policy Run Details**:
   - **Pass**: Green checkmark - policy requirements met
   - **Fail (Soft)**: Yellow warning - violation detected but deployment allowed
   - **Fail (Hard)**: Red X - deployment blocked due to violation

#### Common Policy Violations and Fixes

##### Mandatory Tags Violation
```
VIOLATION: azure-mandatory-tags
Resource: azurerm_resource_group.example
Issue: Missing required tag 'Owner'

Fix: Add the missing tag to your resource:
resource "azurerm_resource_group" "example" {
  name     = "rg-example"
  location = "East US"
  
  tags = {
    Environment = "prod"
    Owner      = "team@company.com"  # Add this
    Project    = "MyProject"
    CostCenter = "12345"
  }
}
```

##### VM Instance Type Violation
```
VIOLATION: azure-vm-instance-types  
Resource: azurerm_linux_virtual_machine.web
Issue: VM size 'Standard_D64s_v3' exceeds limits for 'dev' environment

Fix: Use an appropriate VM size for development:
resource "azurerm_linux_virtual_machine" "web" {
  name = "vm-web-dev"
  size = "Standard_B2s"  # Changed from Standard_D64s_v3
  # ... other configuration
}
```

##### Storage Encryption Violation
```
VIOLATION: azure-storage-encryption
Resource: azurerm_storage_account.data
Issue: HTTPS-only traffic not enabled

Fix: Enable HTTPS-only traffic:
resource "azurerm_storage_account" "data" {
  name = "mystorageaccount"
  
  https_traffic_only_enabled = true  # Add this
  min_tls_version            = "TLS1_2"
  
  # ... other configuration
}
```

#### Troubleshooting Policy Issues

1. **Policy Not Running**:
   - Verify policy set is assigned to workspace
   - Check policy syntax with `sentinel fmt`
   - Ensure workspace has Sentinel enabled

2. **Unexpected Pass/Fail Results**:
   - Review policy parameters in `sentinel.hcl`
   - Check environment detection logic
   - Verify resource addresses in Terraform plan

3. **Performance Issues**:
   - Large Terraform plans may cause timeouts
   - Consider policy optimization
   - Contact HashiCorp support for assistance

### Step 6: Customizing for Your Organization

#### Modify Tag Requirements
```hcl
# In sentinel.hcl
params = {
    mandatory_tags = [
        "Environment",
        "Owner",
        "CostCenter",
        "BusinessUnit",    # Add your required tags
        "Compliance",      # Add compliance tracking
        "DataClassification"  # Add data governance
    ]
}
```

#### Adjust Cost Limits
```hcl
# In sentinel.hcl  
params = {
    cost_limits = {
        "prod"    = 25000,  # Increase for larger environments
        "staging" = 8000,   # Adjust based on your needs
        "dev"     = 3000    # Set appropriate dev limits
    }
}
```

#### Custom Naming Conventions
```hcl
# In sentinel.hcl
params = {
    organization_prefix = "mycompany",
    naming_pattern = "{prefix}-{type}-{purpose}-{env}-{sequence}",
    environment_abbreviations = {
        "production"  = "prd",
        "staging"     = "stg", 
        "development" = "dev"
    }
}
```

### Step 7: Deployment Best Practices

#### Rollout Strategy
1. **Phase 1**: Deploy to development with `advisory` enforcement
2. **Phase 2**: Enable `soft-mandatory` in staging  
3. **Phase 3**: Graduate to `hard-mandatory` in production
4. **Phase 4**: Apply lessons learned across all environments

#### Change Management
1. **Version Control**: Tag policy releases for rollback capability
2. **Testing**: Test all changes in non-production first
3. **Communication**: Notify teams of policy changes in advance
4. **Documentation**: Update internal documentation with examples

#### Monitoring Success
- Track policy compliance rates over time
- Monitor cost savings from cost control policies
- Gather feedback from development teams
- Regular policy effectiveness reviews

## �🔧 Configuration

### Environment Detection
Policies automatically detect environments from workspace names:
- `*prod*` → Production environment
- `*staging*` or `*stage*` → Staging environment  
- `*dev*` or `*development*` → Development environment

### Policy Parameters
Each policy supports customizable parameters. Example:

```hcl
policy "azure-mandatory-tags" {
    source = "./policies/azure-mandatory-tags.sentinel"
    enforcement_level = "hard-mandatory"
    
    params = {
        environment = "prod"
        mandatory_tags = ["Environment", "Owner", "Project", "CostCenter"]
        tag_value_min_length = 2
    }
}
```

## 📝 Policy Details

### Azure Mandatory Tags
**Purpose**: Enforce consistent tagging across all Azure resources  
**Key Features**:
- Environment-specific tag requirements
- Tag value validation (length, format)
- Support for computed values
- Comprehensive error reporting

**Required Tags** (default):
- `Environment`: Environment designation
- `Owner`: Resource owner email
- `Project`: Project/application name  
- `CostCenter`: Cost allocation center
- `Application`: Application identifier

### Azure VM Instance Types
**Purpose**: Control VM sizes and configurations by environment  
**Key Features**:
- Environment-based VM size restrictions
- Premium storage enforcement for production
- Availability zone validation
- Resource count limits

**Allowed VM Sizes** (by environment):
- **Production**: D-series, E-series, F-series (s variants)
- **Staging**: B-series, D-series, E-series, F-series
- **Development**: B-series, smaller D/E-series

### Azure Storage Encryption
**Purpose**: Ensure all storage resources are properly encrypted  
**Key Features**:
- Encryption at rest validation
- HTTPS-only traffic enforcement
- Customer-managed keys for production
- Infrastructure encryption validation

### Azure Network Security
**Purpose**: Prevent overly permissive network configurations  
**Key Features**:
- NSG rule validation (no 0.0.0.0/0 except allowed ports)
- DDoS protection for production VNets
- WAF enforcement for Application Gateways
- Network segmentation validation

### Azure Cost Control
**Purpose**: Prevent cost overruns and enforce budget limits  
**Key Features**:
- Monthly cost limits by environment
- Percentage increase thresholds
- Expensive resource type restrictions
- Resource count limits

**Cost Limits** (default):
- **Production**: $10,000/month
- **Staging**: $3,000/month
- **Development**: $1,000/month

### Azure Resource Naming
**Purpose**: Enforce consistent naming conventions  
**Key Features**:
- Environment abbreviations in names
- Resource type abbreviations
- Character restrictions by resource type
- Length validation

**Naming Convention**:
`{prefix}-{resource-type}-{purpose}-{environment}-{sequence}`

Example: `contoso-vm-web-prd-001`

### Azure Backup Compliance
**Purpose**: Ensure proper backup and disaster recovery  
**Key Features**:
- Recovery Services Vault validation
- VM backup policy requirements
- SQL database retention policies
- Cross-region backup for production

## 🧪 Testing

### Running Tests
```bash
# Test all policies
sentinel test

# Test specific policy
sentinel test policies/azure-mandatory-tags.sentinel

# Test with verbose output
sentinel test -verbose
```

### Test Structure
```
test/
├── azure-mandatory-tags/
│   ├── pass-compliant.hcl
│   ├── fail-missing-tags.hcl  
│   ├── edge-case-computed.hcl
│   └── mock-*.sentinel
├── azure-vm-instance-types/
└── ...
```

### Writing Custom Tests
1. Create test directory: `test/{policy-name}/`
2. Add test cases: `{scenario}.hcl`
3. Create mock data: `mock-{scenario}.sentinel`
4. Run tests: `sentinel test`

## 🔒 Security Considerations

### Fail-Secure Design
- Policies default to **DENY** when validation fails
- Unknown/computed values handled gracefully
- Multiple validation layers prevent bypasses

### Input Validation
- All inputs validated for type, range, and format
- Defensive programming against null/undefined values
- Sanitization of user-provided parameters

### Error Handling
- Comprehensive error messages with resource addresses
- Actionable guidance for fixing violations
- Clear distinction between errors and warnings

## 🎯 Best Practices

### Policy Development
1. **Start with soft-mandatory** enforcement during testing
2. **Test thoroughly** with realistic data
3. **Handle computed values** gracefully
4. **Provide clear error messages** for violations
5. **Document parameters** and customization options

### Deployment Strategy
1. **Pilot in development** environment first
2. **Gradually increase** enforcement levels
3. **Monitor policy violations** and adjust as needed
4. **Train teams** on compliance requirements
5. **Regular policy reviews** and updates

### Performance Optimization
- Use efficient resource filtering
- Minimize nested loops and iterations  
- Early returns for quick validation
- Conditional execution for expensive checks

## 🛠️ Customization

### Adding New Policies
1. Create policy file in `policies/` directory
2. Follow the established template structure
3. Add comprehensive test cases
4. Update `sentinel.hcl` configuration
5. Document in README

### Modifying Existing Policies
1. Update parameter defaults as needed
2. Test changes thoroughly
3. Update documentation
4. Consider backward compatibility

### Environment-Specific Configuration
```hcl
# Different enforcement levels by environment
policy "azure-mandatory-tags" {
    source = "./policies/azure-mandatory-tags.sentinel"
    enforcement_level = var.environment == "prod" ? "hard-mandatory" : "soft-mandatory"
}
```

## 📊 Monitoring and Reporting

### Policy Violations
- Monitor Terraform Cloud policy runs
- Set up alerts for repeated violations
- Track compliance metrics over time

### Cost Impact Analysis
- Review cost control policy effectiveness
- Monitor actual vs. projected costs
- Adjust limits based on business needs

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add/modify policies with tests
4. Ensure all tests pass
5. Submit a pull request

### Contribution Guidelines
- Follow security-first principles
- Include comprehensive tests
- Document all changes
- Maintain backward compatibility where possible

## 📖 Additional Resources

- [HashiCorp Sentinel Documentation](https://docs.hashicorp.com/sentinel/)
- [Terraform Cloud Policy Sets](https://www.terraform.io/docs/cloud/sentinel/manage-policies.html)  
- [Azure Resource Naming Conventions](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging)
- [Azure Security Best Practices](https://docs.microsoft.com/en-us/azure/security/fundamentals/best-practices-and-patterns)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- Create an issue for bug reports or feature requests
- Review existing policies for examples
- Consult HashiCorp Sentinel documentation for syntax

---

**Built with ❤️ for Azure infrastructure governance and security**