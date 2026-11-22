module "proxmox" {
  source      = "./proxmox"
  environment = var.environment
}

module "cloudflare" {
  source = "./cloudflare"

  environment = var.environment
  account_id  = var.cloudflare_account_id
  zone_id     = var.cloudflare_zone_id
}
