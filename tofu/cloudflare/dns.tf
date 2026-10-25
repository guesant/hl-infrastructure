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

resource "cloudflare_dns_record" "links" {
  zone_id = var.cloudflare_zone_id
  name    = var.links_hostname
  type    = "CNAME"
  content = "guesant.github.io"
  proxied = true
  ttl     = 1

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_dns_record" "links_www" {
  zone_id = var.cloudflare_zone_id
  name    = "www.${var.links_hostname}"
  type    = "CNAME"
  content = "guesant.github.io"
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

resource "cloudflare_dns_record" "atlas" {
  zone_id = var.cloudflare_zone_id
  name    = var.atlas_hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.blog.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_dns_record" "curriculum" {
  zone_id = var.cloudflare_zone_id
  name    = "curriculum"
  type    = "CNAME"
  content = "guesant.github.io"
  proxied = false
  ttl     = 300
}

resource "cloudflare_dns_record" "curriculum_alias" {
  for_each = toset(["curriculo", "resume", "cv", "portfolio"])

  zone_id = var.cloudflare_zone_id
  name    = each.value
  type    = "CNAME"
  content = "guesant.github.io"
  proxied = true
  ttl     = 1
}
