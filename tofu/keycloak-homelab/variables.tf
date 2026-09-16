variable "keycloak_url" {
  type = string

  validation {
    condition     = startswith(var.keycloak_url, "https://") && !endswith(var.keycloak_url, "/")
    error_message = "keycloak_url must be the https admin URL of the node, without a trailing slash."
  }
}

variable "internal_domain" {
  type = string
}

variable "blog_hostname" {
  type = string
}

variable "service_secret" {
  type      = string
  sensitive = true

  validation {
    condition     = !startswith(var.service_secret, "REPLACE_WITH_")
    error_message = "service_secret still holds the placeholder; it is the secret of the tofu-homelab client declared by tofu/keycloak-master."
  }
}

variable "operator_username" {
  type = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9._-]{1,30}$", var.operator_username))
    error_message = "operator_username must be a short lowercase login name."
  }
}

variable "operator_initial_password" {
  type      = string
  sensitive = true

  validation {
    condition     = length(var.operator_initial_password) >= 20
    error_message = "operator_initial_password must have at least 20 characters; it is temporary and replaced on the first login."
  }
}

variable "state_passphrase" {
  type      = string
  sensitive = true

  validation {
    condition     = length(var.state_passphrase) >= 32 && !startswith(var.state_passphrase, "REPLACE_WITH_")
    error_message = "state_passphrase must have at least 32 characters and not be the placeholder; run just tofu-state-passphrase."
  }
}

variable "blog_client_secret" {
  type      = string
  sensitive = true
}
