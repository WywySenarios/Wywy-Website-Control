resource "proxmox_download_file" "database_template_image" {
  node_name           = local.database_template.node_name
  datastore_id        = "local"
  content_type        = "import"
  url                 = local.template_image.url
  file_name           = local.template_image.file_name
  checksum            = local.template_image.sha512
  checksum_algorithm  = "sha512"
  overwrite_unmanaged = true
  upload_timeout      = 1200
}

resource "proxmox_virtual_environment_vm" "database_template" {
  name      = local.database_template.name
  node_name = local.database_template.node_name
  vm_id     = local.database_template.vm_id
  template  = true
  started   = false

  cpu {
    cores = local.database_template.cores
    type  = local.database_template.cpu_type
  }

  memory {
    dedicated = local.database_template.memory_mb
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = local.database_template.disk_size_gb
    import_from  = "local:import/${local.template_image.file_name}"
  }

  depends_on = [proxmox_download_file.database_template_image]

  network_device = [
    {
      bridge       = "vmbr0"
      model        = "virtio"
      disconnected = false
      enabled      = null
      firewall     = false
      mac_address  = null
      mtu          = null
      queues       = null
      rate_limit   = null
      trunks       = null
      vlan_id      = null
    }
  ]

  initialization {
    datastore_id = "local-lvm"
    interface    = "ide2"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "wywy"
      keys     = local.ssh_public_keys
    }

    upgrade = false
  }

  operating_system {
    type = "l26"
  }

  boot_order    = ["scsi0"]
  scsi_hardware = "virtio-scsi-pci"
}

resource "proxmox_virtual_environment_vm" "database" {
  name      = local.database_vm.name
  node_name = local.database_vm.node_name
  vm_id     = local.database_vm.vm_id
  started   = true
  on_boot   = true

  clone {
    vm_id     = local.database_template.vm_id
    node_name = local.database_template.node_name
    full      = true
  }

  depends_on = [proxmox_virtual_environment_vm.database_template]

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = local.database_vm.disk_size_gb
  }

  network_device = [
    {
      bridge       = local.network.proxmox_sdn.vnet
      model        = "virtio"
      disconnected = false
      enabled      = null
      firewall     = false
      mac_address  = null
      mtu          = null
      queues       = null
      rate_limit   = null
      trunks       = null
      vlan_id      = null
    }
  ]

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    dns {
      servers = [local.network.proxmox_sdn.dns]
    }
  }
}
