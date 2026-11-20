resource "proxmox_download_file" "k8s_worker_template_image" {
  for_each = local.k8s_worker_templates

  node_name           = each.value.node_name
  datastore_id        = "local"
  content_type        = "import"
  url                 = local.template_image.url
  file_name           = local.template_image.file_name
  checksum            = local.template_image.sha512
  checksum_algorithm  = "sha512"
  overwrite_unmanaged = true
  upload_timeout      = 1200
}

resource "proxmox_virtual_environment_vm" "k8s_worker_template" {
  for_each = local.k8s_worker_templates

  name      = each.value.name
  node_name = each.value.node_name
  vm_id     = each.value.vm_id
  template  = true
  started   = false

  cpu {
    cores = each.value.cores
    type  = each.value.cpu_type
  }

  memory {
    dedicated = each.value.memory_mb
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = each.value.disk_size_gb
    import_from  = "local:import/${local.template_image.file_name}"
  }

  depends_on = [proxmox_download_file.k8s_worker_template_image]

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

resource "proxmox_virtual_environment_vm" "k8s_workers" {
  for_each = local.k8s_worker_vms

  name      = each.value.name
  node_name = each.value.node_name
  vm_id     = each.value.vm_id
  started   = true
  on_boot   = true

  clone {
    vm_id     = local.k8s_worker_templates[each.key].vm_id
    node_name = local.k8s_worker_templates[each.key].node_name
    full      = true
  }

  depends_on = [proxmox_virtual_environment_vm.k8s_worker_template]

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = each.value.disk_size_gb
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
