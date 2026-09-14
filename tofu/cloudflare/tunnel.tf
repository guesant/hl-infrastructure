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
        service  = "http://argocd-server.argocd.svc.cluster.local:80"
      },
      {
        hostname = var.blog_hostname
        service  = "http://app.blog.svc.cluster.local"
      },
      {
        service = "http_status:404"
      },
    ]
  }
}
