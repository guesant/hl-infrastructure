locals {
  clients = {
    blog = {
      name                = var.blog_hostname
      base_url            = "https://${var.blog_hostname}"
      redirect_uris       = ["https://${var.blog_hostname}/signin-oidc"]
      logout_redirect_uri = "https://${var.blog_hostname}/signout-callback-oidc"
      secret              = var.blog_client_secret
    }
  }
}
