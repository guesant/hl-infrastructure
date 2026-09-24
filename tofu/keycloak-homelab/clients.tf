locals {
  admin_base_url = "https://admin.${var.blog_hostname}"

  clients = {
    blog = {
      name                = "${var.blog_hostname} admin"
      base_url            = local.admin_base_url
      redirect_uris       = ["${local.admin_base_url}/auth/keycloak/callback"]
      logout_redirect_uri = "${local.admin_base_url}/"
      secret              = var.blog_client_secret
    }
  }
}
