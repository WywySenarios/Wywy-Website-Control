output "network" {
  description = "Shared network contract loaded by the Proxmox module."
  value       = module.proxmox.network
}
