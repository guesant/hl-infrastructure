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
  client_id           = "tofu-homelab"
  client_secret       = var.service_secret
  root_ca_certificate = file("${path.module}/internal-ca.crt")
}
