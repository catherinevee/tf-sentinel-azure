# Terraform Sentinel Azure Examples Guide

This directory contains comprehensive examples demonstrating various Azure infrastructure patterns and how they interact with the Sentinel policies defined in this repository, with a strong focus on cost optimization, security best practices, and compliance.

## 📁 Example Files Overview

### Core Policy Examples

#### 1. `compliant-infrastructure.tf`
**Purpose**: Demonstrates a fully compliant production Azure infrastructure setup that passes all Sentinel policy validations.

**Key Features**:
- Production-grade Virtual Machine Scale Sets
- Application Gateway with WAF protection
- Azure SQL Database with Advanced Threat Protection
- Container Registry with geo-replication
- Key Vault with HSM support
- All resources properly tagged and encrypted

**Use Cases**:
- Production environment template
- Policy compliance validation
- Security best practices demonstration

**Policies Validated**:
- ✅ Mandatory tagging
- ✅ VM type restrictions
- ✅ Storage encryption requirements
- ✅ Network security controls
- ✅ Cost control measures
- ✅ Naming conventions
- ✅ Backup compliance

#### 2. `non-compliant-infrastructure.tf`
**Purpose**: Shows common policy violations and misconfigurations that would trigger Sentinel policy failures.

**Key Violations Demonstrated**:
- Missing required tags
- Oversized VM instances
- Unencrypted storage accounts
- Open network security groups
- Non-compliant naming conventions
- Missing backup configurations

**Use Cases**:
- Policy testing and validation
- Training and education
- Troubleshooting configuration issues

**Expected Policy Failures**:
- ❌ Missing Environment and Owner tags
- ❌ VM size Standard_D32s_v3 exceeds cost limits
- ❌ Storage account without encryption
- ❌ NSG allows unrestricted inbound access
- ❌ Resources not following naming conventions

#### 3. `development-environment.tf`
**Purpose**: Cost-optimized development environment that maintains security standards while reducing operational costs.

**Key Features**:
- Smaller VM SKUs appropriate for development
- Basic tier services where appropriate
- Shorter retention periods for non-critical data
- Development-specific network configurations
- Still maintains encryption and security controls

**Use Cases**:
- Development team infrastructure
- Cost-conscious deployments
- Testing and experimentation

#### 4. `staging-environment.tf`
**Purpose**: Production-like staging environment with optimizations for testing and validation.

**Key Features**:
- Production-similar architecture
- WAF in detection mode for testing
- Scaled-down but representative infrastructure
- Full security controls enabled
- Integration testing capabilities

#### 5. `multi-cloud-governance.tf`
**Purpose**: Demonstrates multi-cloud governance patterns with Azure and AWS integration.

**Key Features**:
- Hybrid connectivity (VPN between Azure and AWS)
- Cross-cloud backup strategies
- Unified tagging across providers
- Centralized logging and monitoring
- Multi-cloud secret management

### Enterprise Architecture Examples

#### 6. `disaster-recovery-ha.tf` 🆕
**Purpose**: Multi-region disaster recovery with automated failover and comprehensive backup strategies.

**Key Features**:
- Primary and secondary region deployment
- Traffic Manager for automatic failover
- Geo-replicated SQL databases with backup vaults
- Cross-region VNet peering
- Automated DR testing and validation

**Cost Optimization**:
- Basic Traffic Manager profile
- LRS storage in secondary region
- Optimized backup retention policies
- **Estimated Monthly Savings**: 35-40% vs premium DR solutions

#### 7. `aks-container-governance.tf` 🆕
**Purpose**: Enterprise Kubernetes platform with comprehensive container governance and security.

**Key Features**:
- AKS cluster with spot node pools for cost savings
- Application Gateway with WAF protection
- Azure Container Registry with vulnerability scanning
- Log Analytics integration for monitoring
- RBAC and network policies for security

**Cost Optimization**:
- Spot instances for non-critical workloads (70-90% savings)
- Auto-scaling from 0-10 nodes
- Basic Container Registry tier
- **Estimated Monthly Savings**: 60-70% vs dedicated VMs

#### 8. `data-platform-governance.tf` 🆕
**Purpose**: Comprehensive data analytics platform with strict governance and cost controls.

**Key Features**:
- Synapse Analytics workspace with serverless SQL
- Data Lake Gen2 with lifecycle management
- Data Factory for ETL pipelines
- Private endpoints for secure data access
- HSM-backed Key Vault for encryption

**Cost Optimization**:
- Serverless compute for sporadic workloads
- Hot/Cool/Archive storage tiers
- Pause Synapse SQL pools when not in use
- **Estimated Monthly Savings**: 50-60% vs always-on dedicated pools

#### 9. `devops-platform.tf` 🆕
**Purpose**: Self-hosted DevOps platform with security best practices and cost optimization.

**Key Features**:
- Self-hosted build agents on VMs with auto-shutdown
- Container Registry for build artifacts
- Key Vault for secure credential management
- Monitoring and alerting for build performance
- Network isolation for security

**Cost Optimization**:
- Auto-shutdown VMs outside business hours (65% savings)
- Burstable B-series VMs for variable workloads
- Basic monitoring and alerting
- **Estimated Monthly Savings**: 60-70% vs premium hosted agents

#### 10. `serverless-platform.tf` 🆕
**Purpose**: Event-driven serverless architecture with pay-per-use pricing model.

**Key Features**:
- Azure Functions with consumption plan
- Cosmos DB serverless for variable workloads
- Service Bus and Event Hub for messaging
- API Management consumption tier
- Logic Apps for workflow automation

**Cost Optimization**:
- True pay-per-execution model
- Scale-to-zero when not in use
- Consumption-based pricing for all services
- **Estimated Monthly Savings**: 80-90% vs always-on alternatives

#### 11. `ml-ai-platform.tf` 🆕
**Purpose**: Machine Learning platform with responsible AI practices and cost optimization.

**Key Features**:
- ML workspace with auto-scaling compute clusters
- Cognitive Services with network isolation
- OpenAI integration for generative AI
- Container Registry for ML model storage
- Comprehensive monitoring and governance

**Cost Optimization**:
- Auto-scaling compute (scale to zero)
- Basic ML workspace SKU
- Cost alerts for training jobs
- **Estimated Monthly Savings**: 70-80% vs dedicated ML infrastructure

#### 12. `hybrid-cloud-integration.tf` 🆕
**Purpose**: Hybrid connectivity with comprehensive governance and security.

**Key Features**:
- VPN Gateway with BGP routing
- Hub-spoke network topology
- Azure Firewall for centralized security
- Private DNS zones for hybrid resolution
- Azure Arc for on-premises management

**Cost Optimization**:
- VpnGw1AZ for zone redundancy at basic cost
- Standard firewall tier (not Premium)
- Shared firewall across all spokes
- **Estimated Monthly Savings**: 40-50% vs multiple gateways

#### 13. `microservices-platform.tf` 🆕
**Purpose**: Cloud-native microservices architecture with container orchestration.

**Key Features**:
- Container Apps with auto-scaling
- Service Bus for event-driven communication
- Redis cache for distributed state
- API Gateway pattern implementation
- Comprehensive service monitoring

**Cost Optimization**:
- Scale-to-zero for background services
- Consumption-based Container Apps pricing
- Basic Redis and Service Bus tiers
- **Estimated Monthly Savings**: 70-80% vs dedicated Kubernetes

### Industry-Specific Examples

#### 14. `finserv-compliance.tf` 🆕
**Purpose**: Financial services infrastructure with PCI DSS compliance and security controls.

**Key Features**:
- HSM-backed Key Vault for PCI compliance
- Network segmentation with NSGs and firewalls
- SQL Server with Advanced Threat Protection
- Immutable audit logging for compliance
- DDoS protection and WAF v2

**Compliance Features**:
- PCI DSS Level 1 controls
- Immutable audit logs (7+ year retention)
- Network tokenization support
- Fraud detection capabilities

#### 15. `healthcare-hipaa-compliance.tf` 🆕
**Purpose**: HIPAA-compliant healthcare infrastructure with comprehensive PHI protection.

**Key Features**:
- Customer-managed encryption with HSM keys
- Private endpoints for all services (no public access)
- Advanced Threat Protection and vulnerability scanning
- 7-year audit log retention for compliance
- Azure AD authentication with MFA

**HIPAA Compliance**:
- Administrative, Physical, and Technical safeguards
- Access controls and audit trails
- Encryption at rest and in transit
- Incident response and breach notification

#### 16. `startup-small-business.tf` 🆕
**Purpose**: Cost-effective platform for startups and small businesses.

**Key Features**:
- Free App Service tier (F1) for initial deployment
- Basic SQL Database (2GB) for minimal cost
- CDN for global performance
- Basic monitoring and alerting
- Scaling path recommendations

**Cost Optimization**:
- **Starting cost**: ~$21/month for full platform
- Free App Service tier (60 min/day limit)
- Basic SQL Database ($5/month)
- Upgrade path as business grows

### Cost-Focused Examples

#### 17. `cost-optimized-web-app.tf`
**Purpose**: Demonstrates cost-effective web app deployment with comprehensive cost optimization strategies.

**Key Cost Optimizations**:
- Basic App Service Plan (B1) with Linux OS
- Auto-shutdown scheduling during off-hours
- Cool storage tier for infrequent access
- Standard Key Vault (vs Premium HSM)
- Minimal Application Insights retention
- Automated budget monitoring with alerts

**Estimated Monthly Cost**: $20-25 (vs $150-200 without optimization)

**Cost Features**:
- Always-on disabled for app sleep savings
- Pay-per-GB logging model
- Standard LRS storage replication
- Budget alerts at 80% and 90%
- PowerShell automation for shutdown

#### 18. `cost-effective-databases.tf`
**Purpose**: Shows cost-optimized database deployments across multiple Azure database services.

**Database Services Covered**:
- SQL Database (Serverless with auto-pause)
- MySQL Flexible Server (Burstable B1s tier)
- PostgreSQL Flexible Server (Burstable B1ms tier)
- Cosmos DB (Serverless mode)
- Redis Cache (Basic C0 tier)

**Estimated Monthly Cost**: $50-75 (highly usage-dependent)

**Cost Optimizations**:
- Serverless auto-pause after 60 minutes inactivity
- Burstable compute tiers for databases
- Minimum storage allocations
- Single-region deployments (no geo-redundancy)
- 7-day backup retention
- Service endpoints for cost-effective private connectivity

### 8. `cost-optimized-compute.tf` 🆕
**Purpose**: Demonstrates cost-effective VM deployments with spot instances and advanced auto-scaling.

**Key Features**:
- Spot Virtual Machine Scale Sets (up to 90% savings)
- Burstable B1s VM size for cost efficiency
- Basic Load Balancer (vs Standard for cost savings)
- Automated scaling based on CPU (1-5 instances)
- Scheduled shutdown during off-hours
- Weekend scaling profiles for reduced capacity

**Estimated Monthly Cost**: $25-40 (vs $150-200 without optimization)

**Advanced Cost Controls**:
- Spot instance bid price of $0.02/hour
- Eviction handling for graceful shutdowns
- Cost monitoring with health checks
- Automated log rotation for disk space management
- Security updates automation

### 9. `comprehensive-cost-management.tf` 🆕
**Purpose**: Enterprise-grade cost management, budget monitoring, and automated cost optimization across the entire subscription.

**Cost Management Features**:
- Subscription-level budget ($20,000/month) with multi-threshold alerting
- Department-specific budgets with individual tracking
- Cosmos DB serverless billing model
- Azure Cache for Redis (Basic C0 - $16/month)
- Point-in-time restore features
- Cross-region read replicas for critical databases

## 📊 Cost Optimization Summary

### Total Cost Savings Across Examples
- **Serverless Platform**: 80-90% savings vs always-on
- **Container Platform (AKS)**: 60-70% savings with spot instances
- **ML/AI Platform**: 70-80% savings with auto-scaling compute
- **Microservices Platform**: 70-80% savings vs dedicated Kubernetes
- **DevOps Platform**: 60-70% savings with auto-shutdown VMs
- **Startup Platform**: Starting at $21/month for full stack
- **Data Platform**: 50-60% savings with serverless compute

### Key Cost Optimization Strategies Demonstrated
1. **Auto-scaling and Scale-to-Zero**: Implemented across multiple examples
2. **Serverless Computing**: Functions, Cosmos DB, ML compute
3. **Spot Instances**: AKS node pools with 70-90% cost reduction
4. **Storage Tiering**: Hot/Cool/Archive tiers with lifecycle policies
5. **Basic vs Premium Tiers**: Cost-effective service tiers where appropriate
6. **Regional Deployment**: Using cost-effective regions like East US
7. **Reserved Instances**: Recommendations for long-term workloads
8. **Resource Scheduling**: Auto-shutdown for development resources

## 🔐 Security and Compliance Features

### Security Controls Demonstrated
- **Encryption**: Customer-managed keys, TDE, storage encryption
- **Network Security**: Private endpoints, NSGs, Azure Firewall
- **Identity and Access**: Azure AD integration, managed identities, RBAC
- **Monitoring**: Comprehensive logging, threat detection, alerts
- **Backup and DR**: Geo-redundant backups, cross-region replication

### Compliance Standards Covered
- **HIPAA**: Healthcare PHI protection with 7-year retention
- **PCI DSS**: Financial services with HSM-backed encryption
- **SOC 2**: Enterprise governance and audit controls
- **GDPR**: Data residency and privacy controls
- **ISO 27001**: Information security management

## 🏢 Industry-Specific Examples

### Healthcare (`healthcare-hipaa-compliance.tf`)
- **Compliance**: HIPAA Technical, Administrative, and Physical safeguards
- **Features**: HSM encryption, private networking, 7-year audit retention
- **Cost**: Premium tier services for compliance requirements

### Financial Services (`finserv-compliance.tf`)
- **Compliance**: PCI DSS Level 1, SOX, regulatory reporting
- **Features**: Network segmentation, immutable audit logs, fraud detection
- **Cost**: Premium security features with compliance controls

### Startups (`startup-small-business.tf`)
- **Approach**: Minimal viable product with scaling path
- **Features**: Free tiers, basic monitoring, upgrade recommendations
- **Cost**: Starting at $21/month with clear scaling milestones

## 🚀 Getting Started

### Prerequisites
- Terraform >= 1.0
- Azure CLI configured with appropriate permissions
- Sentinel CLI (for policy testing)
- Valid Azure subscription

### Quick Start Guide

1. **Choose Your Example**:
   - **Learning**: Start with `compliant-infrastructure.tf`
   - **Cost Focus**: Use `startup-small-business.tf` or `cost-optimized-web-app.tf`
   - **Enterprise**: Begin with `disaster-recovery-ha.tf` or `aks-container-governance.tf`
   - **Compliance**: Select industry-specific examples

2. **Review Configuration**:
   ```bash
   # Clone the repository
   git clone <repository-url>
   cd tf-sentinel-azure/examples
   
   # Review the chosen example
   cat serverless-platform.tf  # Example
   ```

3. **Initialize and Plan**:
   ```bash
   terraform init
   terraform plan -var-file="terraform.tfvars"
   ```

4. **Deploy Infrastructure**:
   ```bash
   terraform apply
   ```

### Required Variables

Create a `terraform.tfvars` file with common variables:

```hcl
# Common variables
resource_group_location = "East US"  # Cost-effective region
organization_prefix     = "contoso"
environment            = "dev"  # or "staging", "prod"

# Multi-cloud example specific
azure_subscription_id = "your-azure-subscription-id"
aws_region           = "us-east-1"

# Environment-specific
environment = "prod"           # or "dev", "staging"
team_name   = "platform-team"

# Application-specific (adjust per example)
app_service_plan_sku = "B1"    # Cost-optimized
sql_server_admin     = "sqladmin"
```

## 🔍 Policy Testing with Examples

### Testing Compliant Infrastructure
```bash
# Test that compliant infrastructure passes all policies
sentinel test -run="test-compliant" policies/
```

### Testing Non-Compliant Infrastructure
```bash
# Test that non-compliant infrastructure fails appropriately
sentinel test -run="test-violations" policies/
```

### Environment-Specific Testing
```bash
# Test development environment optimizations
terraform plan -var="environment=dev" examples/development-environment.tf

# Test enterprise examples
terraform plan examples/disaster-recovery-ha.tf
terraform plan examples/ml-ai-platform.tf
```

## 📊 Comprehensive Cost Analysis

### Cost Comparison by Example Category

| Example Category | Monthly Cost Range* | Cost Optimization Level | Primary Benefits |
|------------------|--------------------|-----------------------|------------------|
| **Startup/Small Business** | $21-50 | **Extreme (90%+ savings)** | Free tiers, minimal resources |
| **Serverless Platform** | $50-150 | **Extreme (80-90% savings)** | Pay-per-use, scale-to-zero |
| **Container Platform** | $100-300 | **High (60-70% savings)** | Spot instances, auto-scaling |
| **ML/AI Platform** | $200-500 | **High (70-80% savings)** | Auto-scaling compute, serverless |
| **Microservices** | $150-400 | **High (70-80% savings)** | Container Apps consumption model |
| **Data Platform** | $300-700 | **Medium (50-60% savings)** | Serverless analytics, storage tiers |
| **DevOps Platform** | $100-250 | **High (60-70% savings)** | Auto-shutdown, burstable VMs |
| **Hybrid Cloud** | $400-800 | **Medium (40-50% savings)** | Shared infrastructure, basic tiers |
| **Enterprise DR** | $500-1200 | **Medium (35-40% savings)** | Basic Traffic Manager, LRS secondary |
| **Compliance (HIPAA)** | $800-1500 | **Low (Premium required)** | Compliance over cost optimization |
| **Compliance (PCI DSS)** | $1000-2000 | **Low (Premium required)** | Security and compliance features |

*Estimates based on East US region with moderate usage

### Key Cost Optimization Patterns

#### 🎯 **Scale-to-Zero Technologies**
- **Azure Functions**: Consumption plan (no idle costs)
- **Container Apps**: Scale to 0 replicas when unused
- **Cosmos DB Serverless**: Pay only for consumed RU/s
- **ML Compute**: Auto-scale training clusters to 0 nodes

#### 💾 **Storage Optimization**
- **Hot/Cool/Archive Tiers**: 50-80% savings for infrequent access
- **Lifecycle Management**: Automatic tier transitions
- **LRS vs GRS**: 50% savings when geo-redundancy not needed
- **Blob Indexing**: Only enable when searching required

#### 🖥️ **Compute Right-Sizing**
- **Burstable VMs**: B-series for variable workloads (40-60% savings)
- **Spot Instances**: 70-90% savings for fault-tolerant workloads
- **Reserved Instances**: 40-65% savings for predictable workloads
- **Auto-shutdown**: 65% savings for dev/test environments

#### 🌐 **Networking Cost Control**
- **Hub-Spoke Topology**: Shared gateway costs
- **Private Endpoints**: Reduce data transfer charges
- **CDN Optimization**: Reduce origin server load
- **Traffic Manager Basic**: vs Premium for simple scenarios

## 🏗️ Architecture Patterns Demonstrated

### **Enterprise Patterns**
- **Hub-Spoke Networking**: Centralized security and connectivity
- **Multi-Region DR**: Business continuity and disaster recovery
- **Microservices**: Scalable, independent service deployment
- **Data Lake Architecture**: Comprehensive analytics platform

### **Cost-Optimized Patterns**
- **Serverless-First**: Event-driven, consumption-based pricing
- **Container Orchestration**: Efficient resource utilization
- **Auto-Scaling**: Dynamic capacity management
- **Tiered Storage**: Match access patterns to storage costs

### **Security Patterns**
- **Zero Trust Network**: Private endpoints, no public access
- **Defense in Depth**: Multiple security layers
- **Compliance by Design**: Built-in regulatory requirements
- **Encryption Everywhere**: Data at rest, in transit, in use

### **Operational Patterns**
- **Infrastructure as Code**: Consistent, repeatable deployments
- **GitOps**: Version-controlled infrastructure changes
- **Monitoring and Alerting**: Proactive issue detection
- **Cost Governance**: Automated budget controls and optimization

## 🎓 Learning Path Recommendations

### **Beginner Journey**
1. Start with `startup-small-business.tf` - Learn basic concepts
2. Explore `cost-optimized-web-app.tf` - Understand cost optimization
3. Try `compliant-infrastructure.tf` - Learn policy compliance
4. Review `non-compliant-infrastructure.tf` - Understand policy failures

### **Intermediate Journey**
1. Deploy `serverless-platform.tf` - Modern application patterns
2. Implement `microservices-platform.tf` - Container orchestration
3. Explore `devops-platform.tf` - CI/CD infrastructure
4. Try `aks-container-governance.tf` - Kubernetes governance

### **Advanced Journey**
1. Deploy `disaster-recovery-ha.tf` - Business continuity
2. Implement `ml-ai-platform.tf` - AI/ML infrastructure
3. Explore `hybrid-cloud-integration.tf` - Multi-cloud scenarios
4. Try compliance examples - Industry-specific requirements

### **Enterprise Journey**
1. Study `data-platform-governance.tf` - Analytics at scale
2. Implement multiple examples - Comprehensive platform
3. Customize for specific requirements - Organization needs
4. Integrate with existing systems - Enterprise connectivity
- **Cool access tiers**: 50% storage cost reduction for infrequent access
- **Standard LRS replication**: Local redundancy vs geo-redundancy
- **Lifecycle management**: Automated cleanup and archival

#### **Service Tier Selection**
- **Basic vs Standard/Premium**: Strategic tier selection for non-critical workloads
- **Serverless models**: Pay-per-use for databases and compute
- **Linux vs Windows**: Cost-effective OS selection

#### **Automation & Scheduling**
- **Auto-shutdown**: Off-hours resource deallocation
- **Weekend scaling**: Reduced capacity during low-usage periods
- **Idle resource detection**: Automated identification and cleanup

#### **Budget Monitoring & Alerting**
- **Multi-threshold budgets**: Proactive cost management
- **Department-specific tracking**: Granular cost accountability
- **Executive escalation**: Automated notifications to leadership
- **Forecasting alerts**: Prevention of budget overruns

## 🛡️ Security Considerations by Example

### Development Environment
- **Relaxed Policies**: Some cost controls relaxed
- **Security Maintained**: Encryption and access controls still enforced
- **Network**: More permissive for development workflows

### Staging Environment
- **Production-Like Security**: Full security stack enabled
- **Testing Mode**: WAF in detection mode for testing
- **Monitoring**: Full observability for validation

### Production Environment
- **Maximum Security**: All policies at strictest enforcement
- **Zero Trust**: All network access explicitly defined
- **Compliance**: Full audit trails and compliance controls

### Multi-Cloud Environment
- **Unified Security**: Consistent security posture across clouds
- **Encrypted Transit**: All cross-cloud communication encrypted
- **Centralized Monitoring**: Single pane of glass for security events

## 🏗️ Architecture Patterns

### Single Region (Development, Staging, Production)
```
┌─────────────────────────────────────────┐
│               Azure Region              │
├─────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────────┐   │
│  │    VNet     │  │   App Gateway   │   │
│  │             │  │                 │   │
│  │ ┌─────────┐ │  │  ┌───────────┐  │   │
│  │ │  VMSS   │ │  │  │    WAF    │  │   │
│  │ └─────────┘ │  │  └───────────┘  │   │
│  └─────────────┘  └─────────────────┘   │
│                                         │
│  ┌─────────────────┐  ┌──────────────┐  │
│  │   SQL Database  │  │  Key Vault   │  │
│  └─────────────────┘  └──────────────┘  │
└─────────────────────────────────────────┘
```

### Multi-Cloud (Multi-Cloud Example)
```
┌─────────────────┐    VPN    ┌─────────────────┐
│     Azure       │◄─────────►│      AWS        │
├─────────────────┤           ├─────────────────┤
│  ┌───────────┐  │           │  ┌───────────┐  │
│  │   VNet    │  │           │  │    VPC    │  │
│  │           │  │           │  │           │  │
│  │ Resources │  │           │  │ Resources │  │
│  └───────────┘  │           │  └───────────┘  │
│                 │           │                 │
│ ┌─────────────┐ │           │ ┌─────────────┐ │
│ │ Key Vault   │ │           │ │ S3 Backup   │ │
│ └─────────────┘ │           │ └─────────────┘ │
└─────────────────┘           └─────────────────┘
```

## 📈 Monitoring and Observability

Each example includes monitoring configurations:

- **Azure Monitor**: Centralized metrics and logging
- **Log Analytics**: Query and analysis capabilities
- **Application Insights**: Application performance monitoring
- **Security Center**: Security posture monitoring
- **Cost Management**: Resource cost tracking

## 🔄 CI/CD Integration

These examples work with the provided GitHub Actions workflow:

1. **Validation**: Terraform validate and plan
2. **Security Scanning**: Checkov security analysis
3. **Policy Testing**: Sentinel policy validation
4. **Cost Analysis**: Infracost impact assessment
5. **Deployment**: Conditional deployment based on environment

## 📚 Additional Resources

- [Azure Well-Architected Framework](https://docs.microsoft.com/en-us/azure/architecture/framework/)
- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [HashiCorp Sentinel Documentation](https://docs.hashicorp.com/sentinel)
- [Azure Security Best Practices](https://docs.microsoft.com/en-us/azure/security/)

## 🤝 Contributing

When adding new examples:

1. **Follow naming conventions** established in existing examples
2. **Include comprehensive comments** explaining design decisions
3. **Test against all policies** to ensure expected behavior
4. **Document cost implications** and security considerations
5. **Update this README** with the new example details

## 📝 License

These examples are provided under the same license as the parent repository. See LICENSE file for details.

---

*For questions or support, please refer to the main repository documentation or open an issue.*
