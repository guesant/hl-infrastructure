data "keycloak_realm" "realm" {
  realm = "management"
}

resource "keycloak_group" "admins" {
  realm_id = data.keycloak_realm.realm.id
  name     = "admins"
}

resource "keycloak_required_action" "configure_totp" {
  realm_id       = data.keycloak_realm.realm.id
  alias          = "CONFIGURE_TOTP"
  name           = "Configure OTP"
  enabled        = true
  default_action = true
}

resource "keycloak_required_action" "webauthn_register_passwordless" {
  realm_id       = data.keycloak_realm.realm.id
  alias          = "webauthn-register-passwordless"
  name           = "Webauthn Register Passwordless"
  enabled        = true
  default_action = false
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

  access_type                  = lookup(each.value, "access_type", "CONFIDENTIAL")
  client_secret                = lookup(each.value, "secret", null)
  standard_flow_enabled        = true
  implicit_flow_enabled        = false
  direct_access_grants_enabled = false
  service_accounts_enabled     = false
  pkce_code_challenge_method   = lookup(each.value, "pkce", "S256")

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
