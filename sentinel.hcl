policy "azure-mandatory-tags" {
    source = "./policies/azure-mandatory-tags.sentinel"
    enforcement_level = "hard-mandatory"
}

policy "azure-vm-instance-types" {
    source = "./policies/azure-vm-instance-types.sentinel"
    enforcement_level = "soft-mandatory"
}

policy "azure-storage-encryption" {
    source = "./policies/azure-storage-encryption.sentinel"
    enforcement_level = "hard-mandatory"
}

policy "azure-network-security" {
    source = "./policies/azure-network-security.sentinel"
    enforcement_level = "hard-mandatory"
}

policy "azure-cost-control" {
    source = "./policies/azure-cost-control.sentinel"
    enforcement_level = "soft-mandatory"
}

policy "azure-resource-naming" {
    source = "./policies/azure-resource-naming.sentinel"
    enforcement_level = "soft-mandatory"
}

policy "azure-backup-compliance" {
    source = "./policies/azure-backup-compliance.sentinel"
    enforcement_level = "soft-mandatory"
}
