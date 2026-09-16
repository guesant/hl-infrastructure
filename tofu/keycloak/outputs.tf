output "realm" {
  value = keycloak_realm.homelab.realm
}

output "client_ids" {
  value = { for name, client in keycloak_openid_client.clients : name => client.client_id }
}

output "issuer" {
  value = "https://auth.${var.blog_hostname}/realms/${keycloak_realm.homelab.realm}"
}
