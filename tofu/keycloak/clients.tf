locals {
  clients = {
    argocd = {
      name                = "Argo CD"
      base_url            = "https://argocd.${var.internal_domain}"
      redirect_uris       = ["https://argocd.${var.internal_domain}/auth/callback"]
      logout_redirect_uri = "https://argocd.${var.internal_domain}/*"
      secret              = var.argocd_client_secret
    }
    grafana = {
      name                = "Grafana"
      base_url            = "https://grafana.${var.internal_domain}"
      redirect_uris       = ["https://grafana.${var.internal_domain}/login/generic_oauth"]
      logout_redirect_uri = "https://grafana.${var.internal_domain}/*"
      secret              = var.grafana_client_secret
    }
    oauth2-proxy = {
      name                = "oauth2-proxy"
      base_url            = "https://auth.${var.internal_domain}"
      redirect_uris       = ["https://auth.${var.internal_domain}/oauth2/callback"]
      logout_redirect_uri = "https://auth.${var.internal_domain}/*"
      secret              = var.oauth2_proxy_client_secret
    }
    blog = {
      name                = var.blog_hostname
      base_url            = "https://${var.blog_hostname}"
      redirect_uris       = ["https://${var.blog_hostname}/signin-oidc"]
      logout_redirect_uri = "https://${var.blog_hostname}/signout-callback-oidc"
      secret              = var.blog_client_secret
    }
  }
}

resource "keycloak_openid_client" "clients" {
  for_each = local.clients

  realm_id  = keycloak_realm.homelab.id
  client_id = each.key
  name      = each.value.name
  enabled   = true

  access_type                  = "CONFIDENTIAL"
  client_secret                = each.value.secret
  standard_flow_enabled        = true
  implicit_flow_enabled        = false
  direct_access_grants_enabled = false
  service_accounts_enabled     = false
  pkce_code_challenge_method   = "S256"

  valid_redirect_uris             = each.value.redirect_uris
  valid_post_logout_redirect_uris = [each.value.logout_redirect_uri]
  web_origins                     = [each.value.base_url]
}

resource "keycloak_openid_client_default_scopes" "clients" {
  for_each = keycloak_openid_client.clients

  realm_id       = keycloak_realm.homelab.id
  client_id      = each.value.id
  default_scopes = local.default_client_scopes
}
