variable "cloudflare_account_id" {
  type      = string
  sensitive = true

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.cloudflare_account_id))
    error_message = "cloudflare_account_id must be the 32-character hex account ID; set TF_VAR_cloudflare_account_id in tofu/cloudflare/cloudflare.sops.env."
  }
}

variable "cloudflare_zone_id" {
  type      = string
  sensitive = true

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.cloudflare_zone_id))
    error_message = "cloudflare_zone_id must be the 32-character hex zone ID; set TF_VAR_cloudflare_zone_id in tofu/cloudflare/cloudflare.sops.env."
  }
}

variable "blog_hostname" {
  type = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.blog_hostname)) && !endswith(var.blog_hostname, ".invalid")
    error_message = "blog_hostname must be the real public hostname of the blog, not a placeholder under .invalid."
  }
}

variable "state_passphrase" {
  type      = string
  sensitive = true

  validation {
    condition     = length(var.state_passphrase) >= 32
    error_message = "state_passphrase must be at least 32 characters."
  }

  validation {
    condition     = !startswith(var.state_passphrase, "REPLACE_WITH_")
    error_message = "state_passphrase is still the placeholder; run just tofu-state-passphrase."
  }
}
