terraform {
  required_version = "~> 1.12"

  required_providers {
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "4.5.0"
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
  root_ca_certificate = file("${path.module}/internal-ca.crt")
}
