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
  }
}
