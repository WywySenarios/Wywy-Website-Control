variable "environment" {
  description = "Environment name matching terraform/cloudflare/env/<environment>/cloudflare.yaml."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "account_id" {
  description = "Cloudflare account ID."
  type        = string

  validation {
    condition     = length(var.account_id) > 0
    error_message = "account_id must not be empty."
  }
}

variable "zone_id" {
  description = "Cloudflare zone ID for the public hostnames."
  type        = string

  validation {
    condition     = length(var.zone_id) > 0
    error_message = "zone_id must not be empty."
  }
}
