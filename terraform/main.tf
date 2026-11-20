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
  registry_template = merge(
    local.proxmox_base.registry_template,
    local.proxmox_env.registry_template,
  )
  registry_vm = merge(
    local.proxmox_base.registry_vm,
    local.proxmox_env.registry_vm,
  )
  files_template = merge(
    local.proxmox_base.files_template,
    local.proxmox_env.files_template,
  )
  files_vm = merge(
    local.proxmox_base.files_vm,
    local.proxmox_env.files_vm,
  )
  k8s_worker_templates = {
    for key, config in local.proxmox_base.k8s_worker_templates :
    key => merge(config, lookup(local.proxmox_env.k8s_worker_templates, key, {}))
  }
  k8s_worker_vms = {
    for key, config in local.proxmox_base.k8s_worker_vms :
    key => merge(config, lookup(local.proxmox_env.k8s_worker_vms, key, {}))
  }
  k8s_control_plane_templates = {
    for key, config in local.proxmox_base.k8s_control_plane_templates :
    key => merge(config, lookup(local.proxmox_env.k8s_control_plane_templates, key, {}))
  }
  k8s_control_plane_vms = {
    for key, config in local.proxmox_base.k8s_control_plane_vms :
    key => merge(config, lookup(local.proxmox_env.k8s_control_plane_vms, key, {}))
  }
  network_prefix_length = split("/", local.network.proxmox_sdn.subnet)[1]

  template_image  = local.proxmox_base.template_image
  ssh_public_keys = local.proxmox_env.ssh_public_keys
}
