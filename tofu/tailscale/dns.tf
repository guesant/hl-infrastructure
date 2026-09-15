data "tailscale_device" "node" {
  hostname = var.device_hostname
  wait_for = "60s"
}

locals {
  node_ipv4 = [for address in data.tailscale_device.node.addresses : address if can(cidrnetmask("${address}/32"))]
}

resource "tailscale_dns_split_nameservers" "internal" {
  domain      = var.internal_domain
  nameservers = local.node_ipv4
}

resource "tailscale_dns_search_paths" "internal" {
  search_paths = [var.internal_domain]
}
