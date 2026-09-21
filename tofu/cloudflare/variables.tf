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

variable "api_hostname" {
  type = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.api_hostname)) && !endswith(var.api_hostname, ".invalid")
    error_message = "api_hostname must be the real public hostname of the Laravel API, not a placeholder under .invalid."
  }
}

variable "admin_hostname" {
  type = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.admin_hostname)) && !endswith(var.admin_hostname, ".invalid")
    error_message = "admin_hostname must be the real public hostname of the Filament panel, not a placeholder under .invalid."
  }
}

variable "ops_hostname" {
  type = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.ops_hostname)) && !endswith(var.ops_hostname, ".invalid")
    error_message = "ops_hostname must be the real public hostname for operational traffic such as the GitHub webhook, not a placeholder under .invalid."
  }

  validation {
    condition     = var.ops_hostname != var.blog_hostname
    error_message = "ops_hostname must differ from blog_hostname, so operational endpoints never share a hostname with the public site."
  }
}

variable "auth_hostname" {
  type = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.auth_hostname)) && !endswith(var.auth_hostname, ".invalid")
    error_message = "auth_hostname must be the real public hostname of Keycloak, not a placeholder under .invalid."
  }

  validation {
    condition     = !contains([var.blog_hostname, var.ops_hostname], var.auth_hostname)
    error_message = "auth_hostname must differ from blog_hostname and ops_hostname, so the identity provider never shares a hostname with other traffic."
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
