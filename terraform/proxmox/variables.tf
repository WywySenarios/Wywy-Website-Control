variable "environment" {
  description = "Environment name matching terraform/proxmox/env/<environment>/proxmox.yaml."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}
