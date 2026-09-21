resource "cloudflare_dns_record" "blog" {
  zone_id = var.cloudflare_zone_id
  name    = var.blog_hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.blog.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_dns_record" "blog_www" {
  zone_id = var.cloudflare_zone_id
  name    = "www.${var.blog_hostname}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.blog.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_dns_record" "api" {
  zone_id = var.cloudflare_zone_id
  name    = var.api_hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.blog.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "admin" {
  zone_id = var.cloudflare_zone_id
  name    = var.admin_hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.blog.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "ops" {
  zone_id = var.cloudflare_zone_id
  name    = var.ops_hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.blog.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "auth" {
  zone_id = var.cloudflare_zone_id
  name    = var.auth_hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.blog.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}
