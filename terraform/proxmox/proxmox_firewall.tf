# Proxmox firewall for everything on the SDN VNet.
#
# Rule logic lives in cluster security groups. Addresses live in IPSets:
# - +operator is the static operator address from config/base/network.yaml.
# - +k8s-control-planes is the static control-plane address plan.
# - +k8s-workers is the static worker address plan derived from the VMIDs.
#
# Some items of note:
# - The datacenter firewall is the master switch.
# - Host input stays ACCEPT so turning it on does not change access to the PVE hosts.

locals {
  firewall_operator_source = local.network.openwrt.operator_source

  firewall_control_plane_ips = [
    for vm in local.k8s_control_plane_vms : vm.ipv4_address
  ]

  firewall_worker_ips = [
    for vm in local.k8s_worker_vms : vm.ipv4_address
  ]

  firewall_vms = merge(
    {
      database = {
        node_name = local.database_vm.node_name
        vm_id     = local.database_vm.vm_id
        group     = "db"
      }
      files = {
        node_name = local.files_vm.node_name
        vm_id     = local.files_vm.vm_id
        group     = "files"
      }
      registry = {
        node_name = local.registry_vm.node_name
        vm_id     = local.registry_vm.vm_id
        group     = "registry"
      }
    },
    {
      for key, vm in local.k8s_control_plane_vms :
      "k8s-control-plane-${key}" => {
        node_name = vm.node_name
        vm_id     = vm.vm_id
        group     = "k8s"
      }
    },
    {
      for key, vm in local.k8s_worker_vms :
      "k8s-worker-${key}" => {
        node_name = vm.node_name
        vm_id     = vm.vm_id
        group     = "k8s"
      }
    },
  )
}

resource "proxmox_virtual_environment_cluster_firewall" "main" {
  enabled        = true
  input_policy   = "ACCEPT"
  output_policy  = "ACCEPT"
  forward_policy = "ACCEPT"
}

resource "proxmox_virtual_environment_firewall_ipset" "operator" {
  name    = "operator"
  comment = "Operator workstation from config/base/network.yaml"

  cidr {
    name = local.firewall_operator_source
  }
}

resource "proxmox_virtual_environment_firewall_ipset" "k8s_control_planes" {
  name    = "k8s-control-planes"
  comment = "Static Kubernetes control-plane addresses"

  dynamic "cidr" {
    for_each = local.firewall_control_plane_ips
    content {
      name = cidr.value
    }
  }
}

resource "proxmox_virtual_environment_firewall_ipset" "k8s_workers" {
  name    = "k8s-workers"
  comment = "Static Kubernetes worker addresses from the VMID convention"

  dynamic "cidr" {
    for_each = local.firewall_worker_ips
    content {
      name = cidr.value
    }
  }
}

resource "proxmox_virtual_environment_cluster_firewall_security_group" "db" {
  name    = "db"
  comment = "Postgres: operator and Kubernetes workers"

  # The referenced IPSets must exist before PVE validates the rules.
  depends_on = [
    proxmox_virtual_environment_firewall_ipset.operator,
    proxmox_virtual_environment_firewall_ipset.k8s_workers,
  ]

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "22"
    source  = "+operator"
    comment = "SSH from operator"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "5432"
    source  = "+operator"
    comment = "Postgres from operator"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "5432"
    source  = "+k8s-workers"
    comment = "Postgres from Kubernetes workers"
  }
}

resource "proxmox_virtual_environment_cluster_firewall_security_group" "files" {
  name    = "files"
  comment = "NFS: Kubernetes nodes"

  # The referenced IPSets must exist before PVE validates the rules.
  depends_on = [
    proxmox_virtual_environment_firewall_ipset.operator,
    proxmox_virtual_environment_firewall_ipset.k8s_control_planes,
    proxmox_virtual_environment_firewall_ipset.k8s_workers,
  ]

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "22"
    source  = "+operator"
    comment = "SSH from operator"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "2049"
    source  = "+k8s-control-planes"
    comment = "NFS from control planes"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "2049"
    source  = "+k8s-workers"
    comment = "NFS from Kubernetes workers"
  }
}

resource "proxmox_virtual_environment_cluster_firewall_security_group" "registry" {
  name    = "registry"
  comment = "Registry: operator and Kubernetes nodes"

  # The referenced IPSets must exist before PVE validates the rules.
  depends_on = [
    proxmox_virtual_environment_firewall_ipset.operator,
    proxmox_virtual_environment_firewall_ipset.k8s_control_planes,
    proxmox_virtual_environment_firewall_ipset.k8s_workers,
  ]

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "22"
    source  = "+operator"
    comment = "SSH from operator"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "5000"
    source  = "+operator"
    comment = "Registry push from operator"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "5000"
    source  = "+k8s-control-planes"
    comment = "Registry pull from control planes"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "5000"
    source  = "+k8s-workers"
    comment = "Registry pull from Kubernetes workers"
  }
}

resource "proxmox_virtual_environment_cluster_firewall_security_group" "k8s" {
  name    = "k8s"
  comment = "Kubernetes nodes: inter-node traffic and operator access"

  # The referenced IPSets must exist before PVE validates the rules.
  depends_on = [
    proxmox_virtual_environment_firewall_ipset.operator,
    proxmox_virtual_environment_firewall_ipset.k8s_control_planes,
    proxmox_virtual_environment_firewall_ipset.k8s_workers,
  ]

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "22"
    source  = "+operator"
    comment = "SSH from operator"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "6443"
    source  = "+operator"
    comment = "Kubernetes API from operator"
  }

  # Calico uses IPIP (proto 4), BGP, and the kubelet/etcd ports between nodes.
  # Trust the node address sets rather than enumerating overlay ports.
  rule {
    type    = "in"
    action  = "ACCEPT"
    source  = "+k8s-control-planes"
    comment = "All traffic from control planes"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    source  = "+k8s-workers"
    comment = "All traffic from Kubernetes workers"
  }
}

resource "proxmox_virtual_environment_firewall_options" "vm" {
  for_each = local.firewall_vms

  node_name     = each.value.node_name
  vm_id         = each.value.vm_id
  enabled       = true
  dhcp          = false
  ndp           = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
  log_level_in  = "info"

  depends_on = [
    proxmox_virtual_environment_cluster_firewall.main,
    proxmox_virtual_environment_vm.database,
    proxmox_virtual_environment_vm.files,
    proxmox_virtual_environment_vm.registry,
    proxmox_virtual_environment_vm.k8s_control_planes,
    proxmox_virtual_environment_vm.k8s_workers,
  ]
}

resource "proxmox_virtual_environment_firewall_rules" "vm" {
  for_each = local.firewall_vms

  node_name = each.value.node_name
  vm_id     = each.value.vm_id

  rule {
    security_group = each.value.group
    iface          = "net0"
    comment        = "Managed by Terraform security group ${each.value.group}"
  }

  depends_on = [
    proxmox_virtual_environment_firewall_options.vm,
    proxmox_virtual_environment_cluster_firewall_security_group.db,
    proxmox_virtual_environment_cluster_firewall_security_group.files,
    proxmox_virtual_environment_cluster_firewall_security_group.registry,
    proxmox_virtual_environment_cluster_firewall_security_group.k8s,
  ]
}
