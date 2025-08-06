# Terraform Examples

Basic examples showing how resources interact with the Sentinel policies.

## Files

- `compliant-infrastructure.tf` - Shows infrastructure that passes all policies
- `non-compliant-infrastructure.tf` - Shows common violations and what fails  
- `development-environment.tf` - Cost-optimized setup for dev workspaces
- `staging-environment.tf` - Production-like staging environment

## Usage

1. Copy the relevant example to your own directory
2. Update variables for your environment
3. Run `terraform plan` to see how policies evaluate
4. Check Terraform Cloud policy runs for detailed validation results

## Common Variables

Create a `terraform.tfvars` file:

```hcl
resource_group_location = "East US"
organization_prefix     = "mycompany" 
environment            = "dev"        # or "staging", "prod"
```

## Testing Policy Compliance

Use the non-compliant example to test policy failures:

```bash
terraform plan -var-file=terraform.tfvars non-compliant-infrastructure.tf
```

The plan will show which policies would fail and why.
