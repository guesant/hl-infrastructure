output "cloudflare_account_id" {
  value = var.cloudflare_account_id
}

output "tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.blog.id
}
