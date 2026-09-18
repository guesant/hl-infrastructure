resource "cloudflare_ruleset" "cache" {
  zone_id     = var.cloudflare_zone_id
  name        = "default"
  description = "Cache the fingerprinted Blazor framework assets at the edge"
  kind        = "zone"
  phase       = "http_request_cache_settings"

  rules = [
    {
      ref         = "cache_blazor_framework"
      description = "The runtime under /_framework/ is immutable per fingerprint, so honour the origin TTL instead of treating .wasm as dynamic"
      action      = "set_cache_settings"
      expression  = "(http.host eq \"${var.blog_hostname}\" or http.host eq \"www.${var.blog_hostname}\") and starts_with(http.request.uri.path, \"/_framework/\")"
      action_parameters = {
        cache = true
        edge_ttl = {
          mode = "respect_origin"
        }
        browser_ttl = {
          mode = "respect_origin"
        }
      }
    },
  ]
}
