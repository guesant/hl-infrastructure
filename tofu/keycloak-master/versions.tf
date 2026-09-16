terraform {
  required_version = "~> 1.12"

  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "5.9.0"
    }
  }
}

provider "keycloak" {
  url                 = var.keycloak_url
  base_path           = ""
  realm               = "master"
  client_id           = "admin-cli"
  username            = var.keycloak_admin_user
  password            = var.keycloak_admin_password
  client_timeout      = 120
  keycloak_version    = "26.7.3"
  root_ca_certificate = file("${path.module}/internal-ca.crt")
}
