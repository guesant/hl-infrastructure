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

variable "keycloak_admin_user" {
  type      = string
  sensitive = true
}

variable "keycloak_admin_password" {
  type      = string
  sensitive = true

  validation {
    condition     = !startswith(var.keycloak_admin_password, "REPLACE_WITH_")
    error_message = "keycloak_admin_password still holds the placeholder; fill tofu/keycloak-master/keycloak-master.sops.env."
  }
}

variable "operator_admin_user" {
  type      = string
  sensitive = true
}

variable "operator_admin_password" {
  type      = string
  sensitive = true

  validation {
    condition     = length(var.operator_admin_password) >= 32
    error_message = "operator_admin_password must have at least 32 characters; it is the break-glass login of the whole instance."
  }
}

variable "homelab_service_secret" {
  type      = string
  sensitive = true
}

variable "management_service_secret" {
  type      = string
  sensitive = true
}

variable "state_passphrase" {
  type      = string
  sensitive = true

  validation {
    condition     = length(var.state_passphrase) >= 32 && !startswith(var.state_passphrase, "REPLACE_WITH_")
    error_message = "state_passphrase must have at least 32 characters and not be the placeholder; run just tofu-state-passphrase."
  }
}
