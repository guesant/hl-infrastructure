check "hostname_uniqueness" {
  assert {
    condition = length(toset([
      var.blog_hostname,
      var.links_hostname,
      var.api_hostname,
      var.admin_hostname,
      var.ops_hostname,
      var.auth_hostname,
      var.atlas_hostname,
    ])) == 7

    error_message = "blog, links, api, admin, ops, auth and atlas hostnames must all be distinct."
  }
}
