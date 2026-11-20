locals {
  network = yamldecode(
    file("${path.module}/../config/base/network.yaml")
  )
  proxmox_base = yamldecode(
    file("${path.module}/env/base/proxmox.yaml")
  )
  proxmox_env = yamldecode(
    file("${path.module}/env/${var.environment}/proxmox.yaml")
  )
  database_template = merge(
    local.proxmox_base.database_template,
    local.proxmox_env.database_template,
  )
  database_vm = merge(
    local.proxmox_base.database_vm,
    local.proxmox_env.database_vm,
  )
  template_image  = local.proxmox_base.template_image
  ssh_public_keys = local.proxmox_env.ssh_public_keys
}
