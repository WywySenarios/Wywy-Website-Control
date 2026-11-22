output "network" {
  description = "Shared network contract loaded by the Proxmox module."
  value       = module.proxmox.network
}

output "cloudflare" {
  description = "Cloudflare tunnel contract loaded by the Cloudflare module."
  value       = module.cloudflare.contract
}
