moved {
  from = cloudflare_dns_record.blog
  to   = cloudflare_dns_record.links
}

moved {
  from = cloudflare_dns_record.blog_www
  to   = cloudflare_dns_record.links_www
}
