data "keycloak_realm" "realm" {
  realm = "homelab"
}

resource "keycloak_group" "admins" {
  realm_id = data.keycloak_realm.realm.id
  name     = "admins"
}

resource "keycloak_user" "operator" {
  realm_id = data.keycloak_realm.realm.id
  username = var.operator_username
  email    = "${var.operator_username}@${var.internal_domain}"
  enabled  = true

  initial_password {
    value     = var.operator_initial_password
    temporary = true
  }
}

resource "keycloak_user_groups" "operator" {
  realm_id  = data.keycloak_realm.realm.id
  user_id   = keycloak_user.operator.id
  group_ids = [keycloak_group.admins.id]
}

resource "keycloak_required_action" "configure_totp" {
  realm_id       = data.keycloak_realm.realm.id
  alias          = "CONFIGURE_TOTP"
  name           = "Configure OTP"
  enabled        = true
  default_action = true
}

resource "keycloak_openid_client_scope" "groups" {
  realm_id               = data.keycloak_realm.realm.id
  name                   = "groups"
  include_in_token_scope = true
}

resource "keycloak_openid_group_membership_protocol_mapper" "groups" {
  realm_id        = data.keycloak_realm.realm.id
  client_scope_id = keycloak_openid_client_scope.groups.id
  name            = "groups"
  claim_name      = "groups"
  full_path       = false

  add_to_id_token     = true
  add_to_access_token = true
  add_to_userinfo     = true
}

locals {
  default_client_scopes = [
    "profile",
    "email",
    "roles",
    "web-origins",
    "acr",
    "basic",
    keycloak_openid_client_scope.groups.name,
  ]
}

resource "keycloak_openid_client" "clients" {
  for_each = local.clients

  realm_id  = data.keycloak_realm.realm.id
  client_id = each.key
  name      = each.value.name
  enabled   = lookup(each.value, "enabled", true)

  access_type                  = "CONFIDENTIAL"
  client_secret                = each.value.secret
  standard_flow_enabled        = true
  implicit_flow_enabled        = false
  direct_access_grants_enabled = false
  service_accounts_enabled     = false
  pkce_code_challenge_method   = "S256"

  valid_redirect_uris             = each.value.redirect_uris
  valid_post_logout_redirect_uris = [each.value.logout_redirect_uri]
  web_origins                     = [each.value.base_url]
}

resource "keycloak_openid_client_default_scopes" "clients" {
  for_each = keycloak_openid_client.clients

  realm_id       = data.keycloak_realm.realm.id
  client_id      = each.value.id
  default_scopes = local.default_client_scopes
}
