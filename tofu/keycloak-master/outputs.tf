output "realms" {
  value = keys(keycloak_realm.realms)
}

output "service_account_client_ids" {
  value = { for name, client in keycloak_openid_client.service_accounts : name => client.client_id }
}
