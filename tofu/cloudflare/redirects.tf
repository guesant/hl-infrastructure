resource "cloudflare_ruleset" "curriculum_alias_redirects" {
  zone_id     = var.cloudflare_zone_id
  name        = "curriculum aliases"
  description = "Redirect legacy curriculum hostnames to the canonical curriculum hostname"
  kind        = "zone"
  phase       = "http_request_dynamic_redirect"

  rules = [
    {
      ref         = "curriculum_aliases"
      description = "Redirect curriculo, resume, cv and portfolio to curriculum"
      expression  = "(http.host in {\"curriculo.guesant.net\" \"resume.guesant.net\" \"cv.guesant.net\" \"portfolio.guesant.net\"})"
      action      = "redirect"
      enabled     = true
      action_parameters = {
        from_value = {
          status_code           = 301
          preserve_query_string = true
          target_url = {
            expression = "concat(\"https://curriculum.guesant.net\", http.request.uri.path)"
          }
        }
      }
    },
  ]
}
