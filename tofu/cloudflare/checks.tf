check "hostname_uniqueness" {
  assert {
    condition = length(toset([
      var.blog_hostname,
      var.api_hostname,
      var.admin_hostname,
      var.ops_hostname,
      var.auth_hostname,
    ])) == 5

    error_message = "blog, api, admin, ops and auth hostnames must all be distinct."
  }
}
