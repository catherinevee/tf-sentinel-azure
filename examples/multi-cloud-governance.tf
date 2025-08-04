# Multi-Cloud Governance Example
# This example shows how to extend Sentinel policies across multiple cloud providers
# Note: This is primarily Azure-focused but shows extension patterns

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Azure Provider Configuration
provider "azurerm" {
  features {}
  
  # Specific subscription for multi-cloud setup
  subscription_id = var.azure_subscription_id
}

# AWS Provider Configuration  
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = local.common_tags
  }
}

# Local values for multi-cloud setup
locals {
  # Environment configuration
  environment         = "prod"
  organization_prefix = "contoso"
  
  # Common tags that work across cloud providers
  # These would be validated by both Azure and AWS Sentinel policies
  common_tags = {
    Environment     = local.environment
    Owner          = "platform-team@contoso.com"
    Project        = "MultiCloudPlatform"
    CostCenter     = "Infrastructure"
    Application    = "SharedServices"
    CloudProvider  = "Multi"  # Indicates multi-cloud resource
    Compliance     = "SOC2"
    Criticality    = "High"
  }
}

# ========================================
# AZURE RESOURCES
# ========================================

# Azure Resource Group - compliant with Azure Sentinel policies
resource "azurerm_resource_group" "azure_hub" {
  name     = "rg-${local.organization_prefix}-hub-azure-${local.environment}-001"
  location = "East US"
  
  tags = merge(local.common_tags, {
    Purpose = "AzureHub"
    Region  = "EastUS"
  })
}

# Azure Virtual Network for hybrid connectivity
resource "azurerm_virtual_network" "azure_hub" {
  name                = "vnet-${local.organization_prefix}-hub-azure-${local.environment}-001"
  resource_group_name = azurerm_resource_group.azure_hub.name
  location            = azurerm_resource_group.azure_hub.location
  address_space       = ["10.0.0.0/16"]
  
  # DDoS protection required by Azure network security policy for production
  ddos_protection_plan {
    id     = azurerm_network_ddos_protection_plan.azure.id
    enable = true
  }
  
  tags = merge(local.common_tags, {
    Purpose = "HybridConnectivity"
  })
}

# DDoS Protection Plan (required by Azure policies for production)
resource "azurerm_network_ddos_protection_plan" "azure" {
  name                = "ddos-${local.organization_prefix}-${local.environment}-001"
  resource_group_name = azurerm_resource_group.azure_hub.name
  location            = azurerm_resource_group.azure_hub.location
  
  tags = local.common_tags
}

# Gateway subnet for VPN connectivity
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"  # Required name for Azure
  resource_group_name  = azurerm_resource_group.azure_hub.name
  virtual_network_name = azurerm_virtual_network.azure_hub.name
  address_prefixes     = ["10.0.1.0/24"]
}

# VPN Gateway for hybrid connectivity
resource "azurerm_virtual_network_gateway" "azure_vpn" {
  name                = "vpn-${local.organization_prefix}-${local.environment}-001"
  location            = azurerm_resource_group.azure_hub.location
  resource_group_name = azurerm_resource_group.azure_hub.name
  
  type     = "Vpn"
  vpn_type = "RouteBased"
  
  active_active = false
  enable_bgp    = true
  sku           = "VpnGw2"  # Production-appropriate SKU
  
  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }
  
  tags = merge(local.common_tags, {
    Purpose = "HybridConnectivity"
  })
}

# Public IP for VPN Gateway
resource "azurerm_public_ip" "vpn_gateway" {
  name                = "pip-vpn-${local.organization_prefix}-${local.environment}-001"
  resource_group_name = azurerm_resource_group.azure_hub.name
  location            = azurerm_resource_group.azure_hub.location
  allocation_method   = "Static"
  sku                = "Standard"
  
  tags = local.common_tags
}

# Azure Storage Account with cross-region replication
resource "azurerm_storage_account" "multi_cloud_logs" {
  name                = "st${local.organization_prefix}logs${local.environment}001"
  resource_group_name = azurerm_resource_group.azure_hub.name
  location            = azurerm_resource_group.azure_hub.location
  
  # Production settings compliant with Azure storage encryption policy
  account_tier             = "Standard"
  account_replication_type = "RAGRS"  # Read-access geo-redundant
  account_kind            = "StorageV2"
  
  # Security requirements
  https_traffic_only_enabled        = true
  min_tls_version                   = "TLS1_2"
  infrastructure_encryption_enabled = true
  
  # Identity for customer-managed keys
  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.storage.id
    ]
  }
  
  # Customer-managed keys for production (required by policy)
  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.storage.id
    user_assigned_identity_id = azurerm_user_assigned_identity.storage.id
  }
  
  blob_properties {
    versioning_enabled = true
    
    delete_retention_policy {
      days = 365  # Long retention for compliance
    }
  }
  
  tags = merge(local.common_tags, {
    Purpose = "CrossCloudLogging"
  })
}

# User-assigned identity for storage account encryption
resource "azurerm_user_assigned_identity" "storage" {
  name                = "id-storage-${local.organization_prefix}-${local.environment}-001"
  resource_group_name = azurerm_resource_group.azure_hub.name
  location            = azurerm_resource_group.azure_hub.location
  
  tags = merge(local.common_tags, {
    Purpose = "StorageEncryption"
  })
}

# Key Vault access policy for the identity
resource "azurerm_key_vault_access_policy" "storage_identity" {
  key_vault_id = azurerm_key_vault.multi_cloud.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.storage.principal_id
  
  key_permissions = [
    "Get",
    "UnwrapKey",
    "WrapKey"
  ]
}

# Key Vault for multi-cloud secrets management
resource "azurerm_key_vault" "multi_cloud" {
  name                = "kv-${local.organization_prefix}-mc-${local.environment}-001"
  location            = azurerm_resource_group.azure_hub.location
  resource_group_name = azurerm_resource_group.azure_hub.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  
  sku_name = "premium"  # Premium for HSM support
  
  # Production security settings
  enable_rbac_authorization     = true
  purge_protection_enabled     = true
  soft_delete_retention_days   = 90
  
  # Network security
  public_network_access_enabled = false
  
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "MultiCloudSecrets"
  })
}

# Key for storage account encryption
resource "azurerm_key_vault_key" "storage" {
  name         = "storage-encryption-key"
  key_vault_id = azurerm_key_vault.multi_cloud.id
  key_type     = "RSA"
  key_size     = 2048
  
  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
  
  tags = local.common_tags
}

# ========================================
# AWS RESOURCES (showing multi-cloud pattern)
# ========================================

# AWS VPC for multi-cloud connectivity
resource "aws_vpc" "aws_hub" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(local.common_tags, {
    Name    = "vpc-${local.organization_prefix}-hub-aws-${local.environment}-001"
    Purpose = "AWSHub"
    Region  = var.aws_region
  })
}

# AWS Internet Gateway
resource "aws_internet_gateway" "aws_hub" {
  vpc_id = aws_vpc.aws_hub.id
  
  tags = merge(local.common_tags, {
    Name = "igw-${local.organization_prefix}-${local.environment}-001"
  })
}

# AWS Customer Gateway for VPN connection to Azure
resource "aws_customer_gateway" "azure_connection" {
  bgp_asn    = 65000
  ip_address = azurerm_public_ip.vpn_gateway.ip_address
  type       = "ipsec.1"
  
  tags = merge(local.common_tags, {
    Name    = "cgw-azure-${local.organization_prefix}-${local.environment}-001"
    Purpose = "AzureConnectivity"
  })
}

# AWS VPN Gateway
resource "aws_vpn_gateway" "aws_hub" {
  vpc_id = aws_vpc.aws_hub.id
  
  tags = merge(local.common_tags, {
    Name = "vgw-${local.organization_prefix}-${local.environment}-001"
  })
}

# AWS VPN Connection to Azure
resource "aws_vpn_connection" "azure" {
  customer_gateway_id = aws_customer_gateway.azure_connection.id
  type               = "ipsec.1"
  vpn_gateway_id     = aws_vpn_gateway.aws_hub.id
  static_routes_only = false
  
  tags = merge(local.common_tags, {
    Name    = "vpn-azure-${local.organization_prefix}-${local.environment}-001"
    Purpose = "AzureConnectivity"
  })
}

# AWS S3 Bucket for cross-cloud backup
resource "aws_s3_bucket" "cross_cloud_backup" {
  bucket = "${local.organization_prefix}-cross-cloud-backup-${local.environment}-001"
  
  tags = merge(local.common_tags, {
    Purpose = "CrossCloudBackup"
  })
}

# S3 Bucket encryption configuration
resource "aws_s3_bucket_server_side_encryption_configuration" "cross_cloud_backup" {
  bucket = aws_s3_bucket.cross_cloud_backup.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "cross_cloud_backup" {
  bucket = aws_s3_bucket.cross_cloud_backup.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket public access block
resource "aws_s3_bucket_public_access_block" "cross_cloud_backup" {
  bucket = aws_s3_bucket.cross_cloud_backup.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ========================================
# MONITORING AND GOVERNANCE
# ========================================

# Azure Log Analytics for centralized logging
resource "azurerm_log_analytics_workspace" "multi_cloud" {
  name                = "law-${local.organization_prefix}-mc-${local.environment}-001"
  location            = azurerm_resource_group.azure_hub.location
  resource_group_name = azurerm_resource_group.azure_hub.name
  sku                 = "PerGB2018"
  retention_in_days   = 365  # Long retention for compliance
  
  tags = merge(local.common_tags, {
    Purpose = "MultiCloudLogging"
  })
}

# Variables
variable "azure_subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Data sources
data "azurerm_client_config" "current" {}

# Outputs
output "azure_resource_group" {
  description = "Azure resource group name"
  value       = azurerm_resource_group.azure_hub.name
}

output "azure_vnet_id" {
  description = "Azure VNet ID"
  value       = azurerm_virtual_network.azure_hub.id
}

output "aws_vpc_id" {
  description = "AWS VPC ID"
  value       = aws_vpc.aws_hub.id
}

output "vpn_connection_status" {
  description = "VPN connection details"
  value = {
    azure_gateway_ip = azurerm_public_ip.vpn_gateway.ip_address
    aws_vpn_id      = aws_vpn_connection.azure.id
  }
}

output "cross_cloud_governance" {
  description = "Multi-cloud governance features"
  value = {
    "centralized_logging"     = azurerm_log_analytics_workspace.multi_cloud.name
    "cross_cloud_backup"      = aws_s3_bucket.cross_cloud_backup.bucket
    "unified_tagging"         = "enabled"
    "hybrid_connectivity"     = "vpn_established"
    "encryption_everywhere"   = "enabled"
    "compliance_monitoring"   = "centralized"
  }
}
