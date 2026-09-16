locals {
  realm_management_roles = [
    "view-realm",
    "manage-realm",
    "manage-clients",
    "manage-users",
    "query-users",
    "query-groups",
    "manage-identity-providers",
    "manage-authorization",
  ]
  service_accounts = {
    homelab    = var.homelab_service_secret
    management = var.management_service_secret
  }
  service_account_roles = merge([
    for realm in keys(local.service_accounts) : {
      for role in local.realm_management_roles : "${realm}/${role}" => { realm = realm, role = role }
    }
  ]...)
}

data "keycloak_openid_client" "realm_management" {
  for_each = keycloak_realm.realms

  realm_id  = "master"
  client_id = "${each.key}-realm"
}

resource "keycloak_openid_client" "service_accounts" {
  for_each = local.service_accounts

  realm_id  = "master"
  client_id = "tofu-${each.key}"
  name      = "OpenTofu, realm ${each.key}"
  enabled   = true

  access_type                  = "CONFIDENTIAL"
  client_secret                = each.value
  service_accounts_enabled     = true
  standard_flow_enabled        = false
  implicit_flow_enabled        = false
  direct_access_grants_enabled = false
}

resource "keycloak_openid_client_service_account_role" "service_accounts" {
  for_each = local.service_account_roles

  realm_id                = "master"
  service_account_user_id = keycloak_openid_client.service_accounts[each.value.realm].service_account_user_id
  client_id               = data.keycloak_openid_client.realm_management[each.value.realm].id
  role                    = each.value.role
}
