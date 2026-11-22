terraform {
  required_version = ">= 1.11.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.8.2"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.122.0"
    }
  }
}
