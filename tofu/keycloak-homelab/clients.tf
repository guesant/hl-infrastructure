locals {
  clients = {
    blog = {
      name                = var.blog_hostname
      base_url            = "https://${var.blog_hostname}"
      redirect_uris       = ["https://${var.blog_hostname}/signin-oidc"]
      logout_redirect_uri = "https://${var.blog_hostname}/signout-callback-oidc"
      secret              = var.blog_client_secret
    }
    argocd = {
      name                = "Argo CD (moved to the management realm)"
      enabled             = false
      base_url            = "https://argocd.${var.internal_domain}"
      redirect_uris       = ["https://argocd.${var.internal_domain}/auth/callback"]
      logout_redirect_uri = "https://argocd.${var.internal_domain}/*"
      secret              = "disabled-client-moved-to-management-realm"
    }
    grafana = {
      name                = "Grafana (moved to the management realm)"
      enabled             = false
      base_url            = "https://grafana.${var.internal_domain}"
      redirect_uris       = ["https://grafana.${var.internal_domain}/login/generic_oauth"]
      logout_redirect_uri = "https://grafana.${var.internal_domain}/*"
      secret              = "disabled-client-moved-to-management-realm"
    }
  }
}
