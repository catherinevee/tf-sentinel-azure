# Makefile for Azure Terraform Sentinel Policies

.PHONY: test test-verbose test-policy fmt validate clean help

# Default target
all: validate test

# Run all tests
test:
	@echo "Running all Sentinel policy tests..."
	sentinel test

# Run tests with verbose output  
test-verbose:
	@echo "Running all Sentinel policy tests (verbose)..."
	sentinel test -verbose

# Test a specific policy
test-policy:
	@echo "Usage: make test-policy POLICY=azure-mandatory-tags"
	@if [ -z "$(POLICY)" ]; then echo "Error: POLICY parameter required"; exit 1; fi
	sentinel test policies/$(POLICY).sentinel

# Format Sentinel files
fmt:
	@echo "Formatting Sentinel files..."
	@find . -name "*.sentinel" -exec sentinel fmt {} \;
	@find . -name "*.hcl" -exec terraform fmt {} \;

# Validate Sentinel syntax
validate:
	@echo "Validating Sentinel policy syntax..."
	@for policy in policies/*.sentinel; do \
		echo "Validating $$policy..."; \
		sentinel fmt -check $$policy || exit 1; \
	done
	@echo "All policies validated successfully!"

# Clean test artifacts
clean:
	@echo "Cleaning test artifacts..."
	@find . -name "*.log" -delete
	@find . -name ".sentinel" -type d -exec rm -rf {} + 2>/dev/null || true

# Run specific test cases
test-tags:
	sentinel test test/azure-mandatory-tags/

test-vm:
	sentinel test test/azure-vm-instance-types/ 

test-storage:
	sentinel test test/azure-storage-encryption/

test-network:
	sentinel test test/azure-network-security/

test-cost:
	sentinel test test/azure-cost-control/

test-naming:
	sentinel test test/azure-resource-naming/

test-backup:
	sentinel test test/azure-backup-compliance/

# Simulate policy runs with different environments
test-dev:
	@echo "Testing with development environment..."
	sentinel test -global environment=dev

test-staging:
	@echo "Testing with staging environment..."
	sentinel test -global environment=staging

test-prod:
	@echo "Testing with production environment..."
	sentinel test -global environment=prod

# Generate policy documentation
docs:
	@echo "Generating policy documentation..."
	@echo "# Policy Documentation" > POLICIES.md
	@echo "" >> POLICIES.md
	@for policy in policies/*.sentinel; do \
		echo "## $$(basename $$policy .sentinel)" >> POLICIES.md; \
		echo "" >> POLICIES.md; \
		head -20 $$policy | grep "^//" | sed 's|^//||' >> POLICIES.md; \
		echo "" >> POLICIES.md; \
	done

# Install Sentinel (if not already installed)
install-sentinel:
	@echo "Installing Sentinel..."
	@if ! command -v sentinel >/dev/null 2>&1; then \
		echo "Please install Sentinel from https://docs.hashicorp.com/sentinel/downloads"; \
		exit 1; \
	else \
		echo "Sentinel is already installed: $$(sentinel version)"; \
	fi

# Continuous integration target
ci: validate test
	@echo "CI pipeline completed successfully!"

# Help target
help:
	@echo "Available targets:"
	@echo "  test          - Run all policy tests"
	@echo "  test-verbose  - Run all tests with verbose output"
	@echo "  test-policy   - Test specific policy (requires POLICY=name)"
	@echo "  fmt           - Format all Sentinel and HCL files"
	@echo "  validate      - Validate Sentinel syntax"
	@echo "  clean         - Clean test artifacts"
	@echo "  docs          - Generate policy documentation"
	@echo "  ci            - Run validation and tests (for CI/CD)"
	@echo "  help          - Show this help message"
	@echo ""
	@echo "Environment-specific tests:"
	@echo "  test-dev      - Test with development environment"
	@echo "  test-staging  - Test with staging environment" 
	@echo "  test-prod     - Test with production environment"
	@echo ""
	@echo "Policy-specific tests:"
	@echo "  test-tags     - Test mandatory tags policy"
	@echo "  test-vm       - Test VM instance types policy"
	@echo "  test-storage  - Test storage encryption policy"
	@echo "  test-network  - Test network security policy"
	@echo "  test-cost     - Test cost control policy"
	@echo "  test-naming   - Test resource naming policy"
	@echo "  test-backup   - Test backup compliance policy"
