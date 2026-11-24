output "network" {
  description = "Shared network contract loaded by the Proxmox module."
  value       = module.proxmox.network
}

output "k8s_api_vip" {
  description = "Kubernetes API VIP from config/base/network.yaml."
  value       = module.proxmox.k8s_api_vip
}

output "cloudflare" {
  description = "Cloudflare tunnel contract loaded by the Cloudflare module."
  value       = module.cloudflare.contract
}
