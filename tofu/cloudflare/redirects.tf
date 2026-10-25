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
    {
      ref         = "legacy_blog_paths"
      description = "Move legacy blog routes from the root domain to the blog hostname"
      expression  = "(http.host in {\"guesant.net\" \"www.guesant.net\"} and http.request.uri.path matches \"^/(about|now|resume|portfolio|cases|projects|writing|findings|topics|collections|snippets|follow|feed|feed\\.xml|sitemap\\.xml|robots\\.txt)(/|$)\")"
      action      = "redirect"
      enabled     = true
      action_parameters = {
        from_value = {
          status_code           = 301
          preserve_query_string = true
          target_url = {
            expression = "concat(\"https://blog.guesant.net\", http.request.uri.path)"
          }
        }
      }
    },
    {
      ref         = "www_links"
      description = "Redirect the www links alias to the apex links hostname"
      expression  = "(http.host eq \"www.guesant.net\")"
      action      = "redirect"
      enabled     = true
      action_parameters = {
        from_value = {
          status_code           = 301
          preserve_query_string = true
          target_url = {
            expression = "concat(\"https://guesant.net\", http.request.uri.path)"
          }
        }
      }
    },
  ]
}
