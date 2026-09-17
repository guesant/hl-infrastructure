resource "cloudflare_ruleset" "ratelimit" {
  zone_id     = var.cloudflare_zone_id
  name        = "default"
  description = "Rate limits for interactive login flows"
  kind        = "zone"
  phase       = "http_ratelimit"

  rules = [
    {
      ref         = "limit_keycloak_login"
      description = "Slow down repeated login attempts against the Keycloak realm"
      action      = "block"
      expression  = "(starts_with(http.request.uri.path, \"/realms/homelab/login-actions/\") or starts_with(http.request.uri.path, \"/realms/homelab/broker/\"))"
      ratelimit = {
        characteristics     = ["ip.src", "cf.colo.id"]
        period              = 10
        requests_per_period = 20
        mitigation_timeout  = 10
      }
    },
  ]
}
