output "network" {
  description = "Shared network contract loaded from config/base/network.yaml."
  value       = local.network
}

output "k8s_api_vip" {
  description = "Kubernetes API VIP from config/base/network.yaml."
  value       = local.network.kubernetes.api_vip
}
