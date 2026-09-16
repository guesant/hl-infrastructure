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
    error_message = "service_secret still holds the placeholder; it is the secret of the tofu-management client declared by tofu/keycloak-master."
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

variable "argocd_client_secret" {
  type      = string
  sensitive = true
}

variable "grafana_client_secret" {
  type      = string
  sensitive = true
}

variable "portainer_client_secret" {
  type      = string
  sensitive = true
}

variable "oauth2_proxy_client_secret" {
  type      = string
  sensitive = true
}
