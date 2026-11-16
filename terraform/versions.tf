terraform {
  required_version = ">= 1.11.0"

  required_providers {
    uapi = {
      source  = "openwrt-iac/uapi"
      version = "3.3.0"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.122.0"
    }
  }
}
