locals {
  sdn            = local.network.proxmox_sdn
  sdn_dhcp_parts = split("-", local.sdn.dhcp_range)
}

data "proxmox_virtual_environment_nodes" "available" {}

resource "proxmox_sdn_zone_vlan" "main" {
  id     = local.sdn.zone
  bridge = "vmbr0"
  ipam   = "pve"
  nodes  = data.proxmox_virtual_environment_nodes.available.names
}

resource "proxmox_sdn_vnet" "main" {
  id   = local.sdn.vnet
  zone = proxmox_sdn_zone_vlan.main.id
  tag  = local.sdn.vlan_id
}

resource "proxmox_sdn_subnet" "main" {
  vnet    = proxmox_sdn_vnet.main.id
  cidr    = local.sdn.subnet
  gateway = local.sdn.gateway

  dhcp_range = {
    start_address = local.sdn_dhcp_parts[0]
    end_address   = local.sdn_dhcp_parts[1]
  }

  dhcp_dns_server = local.sdn.dns
  snat            = false
}

resource "proxmox_sdn_applier" "main" {
  depends_on = [proxmox_sdn_subnet.main]
}
