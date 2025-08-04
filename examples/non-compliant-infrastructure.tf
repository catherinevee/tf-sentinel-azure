# Non-Compliant Infrastructure Example
# This example demonstrates common violations that would be caught by the Sentinel policies

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

# VIOLATION: Missing required tags (azure-mandatory-tags policy)
resource "azurerm_resource_group" "bad_example" {
  name     = "rg-bad-example"  # VIOLATION: Poor naming convention
  location = "East US"
  
  # Missing all required tags: Environment, Owner, Project, CostCenter, Application
  tags = {}
}

# VIOLATION: Non-compliant VM size for production (azure-vm-instance-types policy)
resource "azurerm_linux_virtual_machine" "oversized_vm" {
  name                = "vm-oversized"  # VIOLATION: Missing environment and sequence
  resource_group_name = azurerm_resource_group.bad_example.name
  location            = azurerm_resource_group.bad_example.location
  size                = "Standard_D64s_v3"  # VIOLATION: Too large for most use cases
  
  # VIOLATION: No availability zone specified for production
  admin_username = "adminuser"
  
  network_interface_ids = [
    azurerm_network_interface.bad_example.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"  # VIOLATION: Should use Premium for production
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  
  # VIOLATION: Missing required tags
  tags = {
    "temp" = "true"  # VIOLATION: Contains prohibited word
  }
}

# VIOLATION: Overly permissive network security group (azure-network-security policy)
resource "azurerm_network_security_group" "permissive" {
  name                = "nsg-permissive"
  location            = azurerm_resource_group.bad_example.location
  resource_group_name = azurerm_resource_group.bad_example.name

  # VIOLATION: Allows all traffic from internet
  security_rule {
    name                       = "AllowEverything"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"  # VIOLATION: 0.0.0.0/0 equivalent
    destination_address_prefix = "*"
  }
  
  # VIOLATION: SSH open to internet
  security_rule {
    name                       = "AllowSSH"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "0.0.0.0/0"  # VIOLATION: SSH should not be public
    destination_address_prefix = "*"
  }
  
  # Missing required tags
}

# VIOLATION: Insecure storage account (azure-storage-encryption policy)
resource "azurerm_storage_account" "insecure" {
  name                = "stinsecureexample123"
  resource_group_name = azurerm_resource_group.bad_example.name
  location            = azurerm_resource_group.bad_example.location
  
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  # VIOLATION: HTTPS not enforced
  https_traffic_only_enabled = false
  
  # VIOLATION: Weak TLS version
  min_tls_version = "TLS1_0"
  
  # VIOLATION: No customer-managed keys for production
  # VIOLATION: No infrastructure encryption
  
  # Missing blob properties for backup compliance
  
  # Missing required tags
}

# VIOLATION: VNet without DDoS protection (azure-network-security policy)
resource "azurerm_virtual_network" "insecure_vnet" {
  name                = "vnet-insecure"
  address_space       = ["10.0.0.0/8"]  # VIOLATION: Overly broad address space
  location            = azurerm_resource_group.bad_example.location
  resource_group_name = azurerm_resource_group.bad_example.name
  
  # VIOLATION: No DDoS protection for production
  # Missing required tags
}

# Subnet without NSG association
resource "azurerm_subnet" "unprotected" {
  name                 = "subnet-unprotected"
  resource_group_name  = azurerm_resource_group.bad_example.name
  virtual_network_name = azurerm_virtual_network.insecure_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  
  # VIOLATION: No NSG association for production subnet
}

# Network Interface for the bad VM
resource "azurerm_network_interface" "bad_example" {
  name                = "nic-bad-example"
  location            = azurerm_resource_group.bad_example.location
  resource_group_name = azurerm_resource_group.bad_example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.unprotected.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bad_example.id  # VIOLATION: Direct public IP
  }
  
  # Missing required tags
}

# Public IP without proper restrictions
resource "azurerm_public_ip" "bad_example" {
  name                = "pip-bad-example"
  resource_group_name = azurerm_resource_group.bad_example.name
  location            = azurerm_resource_group.bad_example.location
  allocation_method   = "Static"
  
  # VIOLATION: No DDoS protection
  # Missing required tags
}

# VIOLATION: Expensive resource in development (azure-cost-control policy)
resource "azurerm_hdinsight_hadoop_cluster" "expensive_dev" {
  name                = "hdinsight-dev-cluster"
  resource_group_name = azurerm_resource_group.bad_example.name
  location            = azurerm_resource_group.bad_example.location
  cluster_version     = "4.0"
  
  component_version {
    hadoop = "3.1"
  }
  
  tier = "Premium"  # VIOLATION: Expensive tier in development
  
  gateway {
    username = "acctestusrgw"
    password = "TerrAform123!"
  }
  
  storage_account {
    storage_container_id = azurerm_storage_container.bad_example.id
    storage_account_key  = azurerm_storage_account.insecure.primary_access_key
    is_default          = true
  }
  
  roles {
    head_node {
      vm_size  = "Standard_D12_V2"  # VIOLATION: Large VM size
      username = "acctestusrvm"
      password = "AccTestvdSC4daf986!"
    }
    
    worker_node {
      vm_size               = "Standard_D4_V2"
      username              = "acctestusrvm"
      password              = "AccTestvdSC4daf986!"
      target_instance_count = 10  # VIOLATION: High instance count for dev
    }
    
    zookeeper_node {
      vm_size  = "Standard_A4_V2"
      username = "acctestusrvm"
      password = "AccTestvdSC4daf986!"
    }
  }
  
  # Missing required tags including CostCenter
}

# Storage container for HDInsight
resource "azurerm_storage_container" "bad_example" {
  name                  = "accteststoragecontainer"
  storage_account_id    = azurerm_storage_account.insecure.id
  container_access_type = "blob"  # VIOLATION: Public access
}

# VIOLATION: SQL Database without proper backup configuration
resource "azurerm_mssql_server" "bad_sql" {
  name                         = "sql-server-bad-example"
  resource_group_name          = azurerm_resource_group.bad_example.name
  location                     = azurerm_resource_group.bad_example.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "P@ssw0rd123!"  # VIOLATION: Hardcoded password
  
  # VIOLATION: Public network access enabled
  public_network_access_enabled = true
  
  # Missing required tags
}

resource "azurerm_mssql_database" "bad_database" {
  name           = "database-bad-example"
  server_id      = azurerm_mssql_server.bad_sql.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  sku_name       = "DW100c"  # VIOLATION: Expensive SKU
  zone_redundant = false     # VIOLATION: No zone redundancy for production
  
  # VIOLATION: No backup retention policy configured
  # VIOLATION: Geo-backup not explicitly enabled
  
  # Missing required tags
}

# VIOLATION: Key Vault with weak configuration
resource "azurerm_key_vault" "weak" {
  name                = "kv-weak-example-123"
  location            = azurerm_resource_group.bad_example.location
  resource_group_name = azurerm_resource_group.bad_example.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  
  sku_name = "standard"  # VIOLATION: Should use premium for production
  
  # VIOLATION: Purge protection disabled
  purge_protection_enabled = false
  
  # VIOLATION: Short retention period
  soft_delete_retention_days = 7
  
  # VIOLATION: Public network access enabled
  public_network_access_enabled = true
  
  # Missing network ACLs
  # Missing required tags
}

# Data source
data "azurerm_client_config" "current" {}

# Outputs showing the violations
output "violations_summary" {
  value = {
    "resource_group" = "Missing all required tags, poor naming"
    "virtual_machine" = "Oversized, no availability zones, standard storage, missing tags"
    "network_security_group" = "Overly permissive rules, SSH open to internet"
    "storage_account" = "HTTP allowed, weak TLS, no encryption, missing backup config"
    "virtual_network" = "No DDoS protection, overly broad CIDR"
    "hdinsight_cluster" = "Expensive resource in dev, large VMs, high instance count"
    "sql_database" = "Public access, expensive SKU, no backup policy"
    "key_vault" = "Weak configuration, no purge protection, public access"
  }
}
