check "hostname_uniqueness" {
  assert {
    condition = length(toset([
      var.blog_hostname,
      var.links_hostname,
      var.ops_hostname,
      var.auth_hostname,
      var.atlas_hostname,
    ])) == 5

    error_message = "blog, links, ops, auth and atlas hostnames must all be distinct."
  }
}
