resource "cloudflare_ruleset" "firewall_custom" {
  zone_id     = var.cloudflare_zone_id
  name        = "default"
  description = "Custom firewall rules for the blog, ops and auth hostnames"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules = [
    {
      ref         = "block_scanner_paths"
      description = "Block probes for software this zone does not run"
      action      = "block"
      expression  = "(ends_with(http.request.uri.path, \".php\") or starts_with(http.request.uri.path, \"/wp-\") or starts_with(http.request.uri.path, \"/.env\") or starts_with(http.request.uri.path, \"/.git\") or http.request.uri.path contains \"phpmyadmin\")"
    },
    {
      ref         = "ops_webhook_only"
      description = "Allow only the GitHub webhook POST on the operational hostname"
      action      = "block"
      expression  = "(http.host eq \"${var.ops_hostname}\" and not (http.request.method eq \"POST\" and http.request.uri.path eq \"/api/webhook\"))"
    },
  ]
}

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
      expression  = "(http.host eq \"${var.auth_hostname}\" and (starts_with(http.request.uri.path, \"/realms/homelab/login-actions/\") or starts_with(http.request.uri.path, \"/realms/homelab/broker/\")))"
      ratelimit = {
        characteristics     = ["ip.src", "cf.colo.id"]
        period              = 10
        requests_per_period = 20
        mitigation_timeout  = 10
      }
    },
  ]
}
