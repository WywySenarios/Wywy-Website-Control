resource "proxmox_download_file" "files_template_image" {
  node_name           = local.files_template.node_name
  datastore_id        = "local"
  content_type        = "import"
  url                 = local.template_image.url
  file_name           = local.template_image.file_name
  checksum            = local.template_image.sha512
  checksum_algorithm  = "sha512"
  overwrite_unmanaged = true
  upload_timeout      = 1200
}

resource "proxmox_virtual_environment_vm" "files_template" {
  name      = local.files_template.name
  node_name = local.files_template.node_name
  vm_id     = local.files_template.vm_id
  template  = true
  started   = false

  cpu {
    cores = local.files_template.cores
    type  = local.files_template.cpu_type
  }

  memory {
    dedicated = local.files_template.memory_mb
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = local.files_template.disk_size_gb
    import_from  = "local:import/${local.template_image.file_name}"
  }

  depends_on = [proxmox_download_file.files_template_image]

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

resource "proxmox_virtual_environment_vm" "files" {
  name      = local.files_vm.name
  node_name = local.files_vm.node_name
  vm_id     = local.files_vm.vm_id
  started   = true
  on_boot   = true

  clone {
    vm_id     = local.files_template.vm_id
    node_name = local.files_template.node_name
    full      = true
  }

  depends_on = [proxmox_virtual_environment_vm.files_template]

  # scsi0 is the OS disk; scsi1 is the NFS payload volume that the NFS role
  # formats XFS and mounts at /srv/nfs.
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = local.files_vm.disk_size_gb
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi1"
    size         = local.files_vm.data_disk_size_gb
  }

  network_device = [
    {
      bridge       = local.network.proxmox_sdn.vnet
      model        = "virtio"
      disconnected = false
      enabled      = null
      firewall     = true
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
