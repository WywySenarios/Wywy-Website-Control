variable "environment" {
  description = "Environment name matching the env/<environment> directories in every module."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID."
  type        = string
  sensitive   = false

  validation {
    condition     = length(var.cloudflare_account_id) > 0
    error_message = "cloudflare_account_id must not be empty."
  }
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the public hostnames."
  type        = string
  sensitive   = false

  validation {
    condition     = length(var.cloudflare_zone_id) > 0
    error_message = "cloudflare_zone_id must not be empty."
  }
}
