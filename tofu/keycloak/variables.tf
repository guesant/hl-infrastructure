variable "keycloak_url" {
  type = string

  validation {
    condition     = startswith(var.keycloak_url, "https://") && !endswith(var.keycloak_url, "/")
    error_message = "keycloak_url must be the https admin URL of the node, without a trailing slash."
  }
}

variable "internal_domain" {
  type = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.internal_domain)) && !endswith(var.internal_domain, ".invalid")
    error_message = "internal_domain must be the real internal DNS zone, not a placeholder under .invalid."
  }
}

variable "blog_hostname" {
  type = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.blog_hostname)) && !endswith(var.blog_hostname, ".invalid")
    error_message = "blog_hostname must be the public hostname of the blog, not a placeholder under .invalid."
  }
}

variable "keycloak_admin_user" {
  type      = string
  sensitive = true
}

variable "keycloak_admin_password" {
  type      = string
  sensitive = true

  validation {
    condition     = !startswith(var.keycloak_admin_password, "REPLACE_WITH_")
    error_message = "keycloak_admin_password still holds the placeholder; fill tofu/keycloak/keycloak.sops.env."
  }
}

variable "admin_email" {
  type      = string
  sensitive = true

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.admin_email))
    error_message = "admin_email must be the operator's e-mail, the only user allowed to log in."
  }
}

variable "google_client_id" {
  type      = string
  sensitive = true
}

variable "google_client_secret" {
  type      = string
  sensitive = true
}

variable "argocd_client_secret" {
  type      = string
  sensitive = true
}

variable "grafana_client_secret" {
  type      = string
  sensitive = true
}

variable "blog_client_secret" {
  type      = string
  sensitive = true
}

variable "state_passphrase" {
  type      = string
  sensitive = true

  validation {
    condition     = length(var.state_passphrase) >= 32
    error_message = "state_passphrase must have at least 32 characters."
  }

  validation {
    condition     = !startswith(var.state_passphrase, "REPLACE_WITH_")
    error_message = "state_passphrase still holds the placeholder; run just tofu-state-passphrase."
  }
}
