# Hybrid Cloud Integration Example
# Demonstrates hybrid connectivity with comprehensive governance and security
# Shows VPN Gateway, ExpressRoute, Arc-enabled servers, hybrid identity, and multi-cloud management

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Generate random suffix for globally unique names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Local values for hybrid cloud configuration
locals {
  environment = "prod"
  project     = "HybridCloud"
  
  # Common tags for all resources
  common_tags = {
    Environment     = local.environment
    Owner          = "infrastructure-team@contoso.com"
    Project        = local.project
    CostCenter     = "IT-Infrastructure"
    Application    = "HybridIntegration"
    Architecture   = "hybrid-cloud"
    BackupPolicy   = "standard"
    ComplianceLevel = "enterprise"
    DataClassification = "internal"
  }
  
  # Hybrid connectivity configuration
  hybrid_config = {
    # VPN Gateway configuration (cost-optimized)
    vpn_gateway_sku = "VpnGw1AZ"  # Zone-redundant basic tier
    vpn_generation = "Generation1"
    
    # ExpressRoute Gateway (if needed)
    er_gateway_sku = "Standard"  # Basic tier for cost optimization
    
    # Network configuration
    hub_address_space = ["10.0.0.0/16"]
    spoke1_address_space = ["10.1.0.0/16"]
    spoke2_address_space = ["10.2.0.0/16"]
    on_premises_address_space = ["192.168.0.0/16"]
    
    # DNS configuration
    custom_dns_servers = ["192.168.1.10", "192.168.1.11"]  # On-premises DNS
    
    # Arc configuration
    arc_location = "eastus"
  }
}

# ========================================
# RESOURCE GROUPS
# ========================================

# Main resource group for hub
resource "azurerm_resource_group" "hub" {
  name     = "rg-${lower(local.project)}-hub-${local.environment}-001"
  location = "East US"
  
  tags = merge(local.common_tags, {
    NetworkTier = "Hub"
  })
}

# Resource group for spoke 1 (production workloads)
resource "azurerm_resource_group" "spoke1" {
  name     = "rg-${lower(local.project)}-spoke1-${local.environment}-001"
  location = "East US"
  
  tags = merge(local.common_tags, {
    NetworkTier = "Spoke-Production"
  })
}

# Resource group for spoke 2 (development workloads)
resource "azurerm_resource_group" "spoke2" {
  name     = "rg-${lower(local.project)}-spoke2-dev-001"
  location = "East US"
  
  tags = merge(local.common_tags, {
    NetworkTier = "Spoke-Development"
    Environment = "development"
  })
}

# ========================================
# HUB VIRTUAL NETWORK
# ========================================

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${lower(local.project)}-hub-${local.environment}-001"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  address_space       = local.hybrid_config.hub_address_space
  dns_servers         = local.hybrid_config.custom_dns_servers
  
  tags = merge(local.common_tags, {
    Purpose = "HubNetwork"
    NetworkType = "Hub"
  })
}

# Gateway subnet for VPN/ExpressRoute
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"  # Must be exactly this name
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.0.0/24"]
}

# Azure Firewall subnet
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"  # Must be exactly this name
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Shared services subnet
resource "azurerm_subnet" "shared_services" {
  name                 = "snet-shared-services-001"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.2.0/24"]
  
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.KeyVault",
    "Microsoft.Sql"
  ]
}

# ========================================
# SPOKE VIRTUAL NETWORKS
# ========================================

# Spoke 1 VNet (Production)
resource "azurerm_virtual_network" "spoke1" {
  name                = "vnet-${lower(local.project)}-spoke1-${local.environment}-001"
  resource_group_name = azurerm_resource_group.spoke1.name
  location            = azurerm_resource_group.spoke1.location
  address_space       = local.hybrid_config.spoke1_address_space
  dns_servers         = local.hybrid_config.custom_dns_servers
  
  tags = merge(local.common_tags, {
    Purpose = "ProductionWorkloads"
    NetworkType = "Spoke"
  })
}

resource "azurerm_subnet" "spoke1_workloads" {
  name                 = "snet-workloads-001"
  resource_group_name  = azurerm_resource_group.spoke1.name
  virtual_network_name = azurerm_virtual_network.spoke1.name
  address_prefixes     = ["10.1.0.0/24"]
  
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.Sql",
    "Microsoft.KeyVault"
  ]
}

# Spoke 2 VNet (Development)
resource "azurerm_virtual_network" "spoke2" {
  name                = "vnet-${lower(local.project)}-spoke2-dev-001"
  resource_group_name = azurerm_resource_group.spoke2.name
  location            = azurerm_resource_group.spoke2.location
  address_space       = local.hybrid_config.spoke2_address_space
  dns_servers         = local.hybrid_config.custom_dns_servers
  
  tags = merge(local.common_tags, {
    Purpose = "DevelopmentWorkloads"
    NetworkType = "Spoke"
    Environment = "development"
  })
}

resource "azurerm_subnet" "spoke2_workloads" {
  name                 = "snet-workloads-001"
  resource_group_name  = azurerm_resource_group.spoke2.name
  virtual_network_name = azurerm_virtual_network.spoke2.name
  address_prefixes     = ["10.2.0.0/24"]
  
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.Sql"
  ]
}

# ========================================
# VNET PEERING (HUB-SPOKE TOPOLOGY)
# ========================================

# Hub to Spoke 1 peering
resource "azurerm_virtual_network_peering" "hub_to_spoke1" {
  name                = "peer-hub-to-spoke1"
  resource_group_name = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke1.id
  
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways         = false
}

resource "azurerm_virtual_network_peering" "spoke1_to_hub" {
  name                = "peer-spoke1-to-hub"
  resource_group_name = azurerm_resource_group.spoke1.name
  virtual_network_name = azurerm_virtual_network.spoke1.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways         = true
  
  depends_on = [azurerm_virtual_network_gateway.vpn]
}

# Hub to Spoke 2 peering
resource "azurerm_virtual_network_peering" "hub_to_spoke2" {
  name                = "peer-hub-to-spoke2"
  resource_group_name = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke2.id
  
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways         = false
}

resource "azurerm_virtual_network_peering" "spoke2_to_hub" {
  name                = "peer-spoke2-to-hub"
  resource_group_name = azurerm_resource_group.spoke2.name
  virtual_network_name = azurerm_virtual_network.spoke2.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways         = true
  
  depends_on = [azurerm_virtual_network_gateway.vpn]
}

# ========================================
# VPN GATEWAY FOR HYBRID CONNECTIVITY
# ========================================

# Public IP for VPN Gateway
resource "azurerm_public_ip" "vpn_gateway" {
  name                = "pip-vpngateway-${local.environment}-001"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                = "Standard"
  zones              = ["1", "2", "3"]  # Zone redundancy
  
  tags = merge(local.common_tags, {
    Purpose = "VPNGateway"
  })
}

# VPN Gateway
resource "azurerm_virtual_network_gateway" "vpn" {
  name                = "vgw-${lower(local.project)}-${local.environment}-001"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  
  type     = "Vpn"
  vpn_type = "RouteBased"
  
  active_active = false
  enable_bgp    = true
  sku           = local.hybrid_config.vpn_gateway_sku
  generation    = local.hybrid_config.vpn_generation
  
  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }
  
  bgp_settings {
    asn = 65515  # Azure default ASN
  }
  
  tags = merge(local.common_tags, {
    Purpose = "HybridConnectivity"
    ConnectivityType = "VPN"
  })
}

# Local Network Gateway (representing on-premises)
resource "azurerm_local_network_gateway" "onprem" {
  name                = "lgw-onprem-${local.environment}-001"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  
  gateway_address = "203.0.113.1"  # Example on-premises public IP
  address_space   = local.hybrid_config.on_premises_address_space
  
  bgp_settings {
    asn                 = 65001  # On-premises ASN
    bgp_peering_address = "192.168.1.1"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "OnPremisesGateway"
  })
}

# VPN Connection
resource "azurerm_virtual_network_gateway_connection" "onprem" {
  name                = "cn-onprem-${local.environment}-001"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn.id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem.id
  
  shared_key = "SecureVPNKey123!"  # In production, use Key Vault
  enable_bgp = true
  
  tags = merge(local.common_tags, {
    Purpose = "HybridConnection"
  })
}

# ========================================
# AZURE FIREWALL FOR CENTRAL SECURITY
# ========================================

# Public IP for Azure Firewall
resource "azurerm_public_ip" "firewall" {
  name                = "pip-azfw-${local.environment}-001"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                = "Standard"
  zones              = ["1", "2", "3"]
  
  tags = merge(local.common_tags, {
    Purpose = "AzureFirewall"
  })
}

# Azure Firewall
resource "azurerm_firewall" "hub" {
  name                = "azfw-${lower(local.project)}-${local.environment}-001"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku_name           = "AZFW_VNet"
  sku_tier           = "Standard"  # Cost-effective tier
  firewall_policy_id = azurerm_firewall_policy.hub.id
  
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
  
  tags = merge(local.common_tags, {
    Purpose = "CentralFirewall"
    SecurityTier = "Standard"
  })
}

# Firewall Policy
resource "azurerm_firewall_policy" "hub" {
  name                = "afwp-${lower(local.project)}-${local.environment}-001"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  
  # Threat intelligence configuration
  threat_intelligence_mode = "Alert"  # Cost-effective mode
  
  tags = local.common_tags
}

# ========================================
# PRIVATE DNS ZONES FOR HYBRID DNS
# ========================================

# Private DNS zone for internal resolution
resource "azurerm_private_dns_zone" "internal" {
  name                = "internal.contoso.com"
  resource_group_name = azurerm_resource_group.hub.name
  
  tags = merge(local.common_tags, {
    Purpose = "HybridDNS"
  })
}

# Link to hub VNet
resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  name                  = "hub-link"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.internal.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = true
  
  tags = local.common_tags
}

# Link to spoke networks
resource "azurerm_private_dns_zone_virtual_network_link" "spoke1" {
  name                  = "spoke1-link"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.internal.name
  virtual_network_id    = azurerm_virtual_network.spoke1.id
  registration_enabled  = true
  
  tags = local.common_tags
}

# ========================================
# AZURE ARC FOR HYBRID MANAGEMENT
# ========================================

# Log Analytics Workspace for Arc monitoring
resource "azurerm_log_analytics_workspace" "arc" {
  name                = "log-arc-${local.environment}-001"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku                 = "PerGB2018"
  retention_in_days   = 90  # Extended retention for compliance
  
  tags = merge(local.common_tags, {
    Purpose = "ArcMonitoring"
  })
}

# Azure Arc-enabled Kubernetes cluster configuration (placeholder)
# Note: Actual Arc registration happens outside Terraform
resource "azurerm_resource_group" "arc_resources" {
  name     = "rg-arc-resources-${local.environment}-001"
  location = "East US"
  
  tags = merge(local.common_tags, {
    Purpose = "ArcManagedResources"
    ResourceType = "HybridInfrastructure"
  })
}

# ========================================
# STORAGE ACCOUNT FOR HYBRID OPERATIONS
# ========================================

resource "azurerm_storage_account" "hybrid_ops" {
  name                = "sahybridops${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  
  account_tier             = "Standard"
  account_replication_type = "LRS"  # Cost-effective for operational data
  account_kind            = "StorageV2"
  
  # Security configurations
  https_traffic_only_enabled          = true
  min_tls_version                     = "TLS1_2"
  allow_nested_items_to_be_public     = false
  shared_access_key_enabled           = false
  default_to_oauth_authentication     = true
  
  # Network restrictions
  public_network_access_enabled = false
  
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    
    virtual_network_subnet_ids = [
      azurerm_subnet.shared_services.id,
      azurerm_subnet.spoke1_workloads.id
    ]
  }
  
  tags = merge(local.common_tags, {
    Purpose = "HybridOperations"
  })
}

# ========================================
# ROUTE TABLES FOR HYBRID ROUTING
# ========================================

# Route table for spoke networks to force traffic through firewall
resource "azurerm_route_table" "spoke_routes" {
  name                = "rt-spoke-${local.environment}-001"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  
  # Route on-premises traffic through VPN Gateway
  route {
    name           = "OnPremisesRoute"
    address_prefix = "192.168.0.0/16"
    next_hop_type  = "VirtualNetworkGateway"
  }
  
  # Route internet traffic through Azure Firewall
  route {
    name                   = "InternetRoute"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub.ip_configuration[0].private_ip_address
  }
  
  tags = merge(local.common_tags, {
    Purpose = "HybridRouting"
  })
}

# Associate route table with spoke subnets
resource "azurerm_subnet_route_table_association" "spoke1" {
  subnet_id      = azurerm_subnet.spoke1_workloads.id
  route_table_id = azurerm_route_table.spoke_routes.id
}

resource "azurerm_subnet_route_table_association" "spoke2" {
  subnet_id      = azurerm_subnet.spoke2_workloads.id
  route_table_id = azurerm_route_table.spoke_routes.id
}

# ========================================
# AUTOMATION ACCOUNT FOR HYBRID RUNBOOKS
# ========================================

resource "azurerm_automation_account" "hybrid" {
  name                = "aa-hybrid-${local.environment}-001"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku_name           = "Basic"  # Cost-effective for hybrid operations
  
  # Managed identity for secure operations
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "HybridAutomation"
  })
}

# Link to Log Analytics for monitoring
resource "azurerm_log_analytics_linked_service" "automation" {
  resource_group_name = azurerm_resource_group.hub.name
  workspace_id        = azurerm_log_analytics_workspace.arc.id
  read_access_id      = azurerm_automation_account.hybrid.id
}

# ========================================
# NETWORK SECURITY GROUPS
# ========================================

# NSG for shared services subnet
resource "azurerm_network_security_group" "shared_services" {
  name                = "nsg-shared-services-001"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  
  # Allow inbound from on-premises
  security_rule {
    name                       = "AllowOnPremisesInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "192.168.0.0/16"
    destination_address_prefix = "*"
  }
  
  # Allow Azure health monitoring
  security_rule {
    name                       = "AllowAzureLoadBalancer"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
  
  tags = merge(local.common_tags, {
    Purpose = "SharedServicesNetworkSecurity"
  })
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "shared_services" {
  subnet_id                 = azurerm_subnet.shared_services.id
  network_security_group_id = azurerm_network_security_group.shared_services.id
}

# ========================================
# OUTPUTS
# ========================================

output "hybrid_cloud_summary" {
  description = "Hybrid Cloud Integration Summary"
  value = {
    # Network topology
    hub_vnet = azurerm_virtual_network.hub.name
    spoke_vnets = [
      azurerm_virtual_network.spoke1.name,
      azurerm_virtual_network.spoke2.name
    ]
    
    # Connectivity
    vpn_gateway = azurerm_virtual_network_gateway.vpn.name
    vpn_gateway_ip = azurerm_public_ip.vpn_gateway.ip_address
    local_network_gateway = azurerm_local_network_gateway.onprem.name
    
    # Security
    azure_firewall = azurerm_firewall.hub.name
    firewall_private_ip = azurerm_firewall.hub.ip_configuration[0].private_ip_address
    
    # DNS and routing
    private_dns_zone = azurerm_private_dns_zone.internal.name
    route_table = azurerm_route_table.spoke_routes.name
    
    # Hybrid management
    automation_account = azurerm_automation_account.hybrid.name
    log_analytics_workspace = azurerm_log_analytics_workspace.arc.name
    arc_resource_group = azurerm_resource_group.arc_resources.name
  }
}

output "connectivity_configuration" {
  description = "Hybrid connectivity configuration details"
  value = {
    # Network addressing
    hub_address_space = local.hybrid_config.hub_address_space
    spoke1_address_space = local.hybrid_config.spoke1_address_space
    spoke2_address_space = local.hybrid_config.spoke2_address_space
    onprem_address_space = local.hybrid_config.on_premises_address_space
    
    # Gateway configuration
    vpn_gateway_sku = local.hybrid_config.vpn_gateway_sku
    bgp_enabled = azurerm_virtual_network_gateway.vpn.enable_bgp
    azure_asn = 65515
    onprem_asn = 65001
    
    # DNS servers
    custom_dns_servers = local.hybrid_config.custom_dns_servers
  }
}

output "cost_optimization_features" {
  description = "Hybrid cloud cost optimization features"
  value = [
    "VpnGw1AZ SKU for cost-effective zone redundancy",
    "Azure Firewall Standard tier (not Premium)",
    "Basic Automation Account for hybrid operations",
    "LRS storage for operational data",
    "Threat intelligence in Alert mode (not Deny)",
    "Single VPN connection (not active-active)",
    "Hub-spoke topology minimizes gateway costs",
    "Shared firewall across all spokes",
    "Basic SKU for ExpressRoute Gateway preparation",
    "Optimized routing reduces data transfer costs"
  ]
}

output "hybrid_management_capabilities" {
  description = "Hybrid cloud management capabilities"
  value = [
    "Centralized network security with Azure Firewall",
    "Hub-spoke network topology for scalability",
    "BGP routing for dynamic route learning",
    "Private DNS integration for name resolution",
    "Azure Arc for on-premises server management",
    "Hybrid runbooks with Automation Account",
    "Centralized monitoring with Log Analytics",
    "Network traffic inspection and filtering",
    "Site-to-site VPN connectivity",
    "Zone-redundant gateways for high availability"
  ]
}
