resource "cloudflare_zero_trust_tunnel_cloudflared" "blog" {
  account_id = var.cloudflare_account_id
  name       = "blog"
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "blog" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.blog.id

  config = {
    ingress = [
      {
        hostname = var.ops_hostname
        path     = "^/api/webhook$"
        service  = "https://argocd-server.argocd.svc.cluster.local:443"
        origin_request = {
          no_tls_verify = true
        }
      },
      {
        hostname = var.auth_hostname
        path     = "^/(realms|resources)/"
        service  = "http://keycloak-service.keycloak.svc.cluster.local:8080"
      },
      {
        hostname = var.api_hostname
        path     = "^/api/v1(/|$)"
        service  = "http://app.blog.svc.cluster.local:8080"
      },
      {
        hostname = var.api_hostname
        path     = "^/docs(/|$)"
        service  = "http://app.blog.svc.cluster.local:8080"
      },
      {
        hostname = var.admin_hostname
        service  = "http://app.blog.svc.cluster.local:8080"
      },
      {
        hostname = var.blog_hostname
        path     = "^/(api/v1|admin)(/|$)"
        service  = "http://app.blog.svc.cluster.local:8080"
      },
      {
        hostname = "www.${var.blog_hostname}"
        path     = "^/(api/v1|admin)(/|$)"
        service  = "http://app.blog.svc.cluster.local:8080"
      },
      {
        hostname = var.blog_hostname
        service  = "http://frontend.blog.svc.cluster.local"
      },
      {
        hostname = "www.${var.blog_hostname}"
        service  = "http://frontend.blog.svc.cluster.local"
      },
      {
        service = "http_status:404"
      },
    ]
  }
}
