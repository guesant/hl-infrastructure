data "keycloak_realm" "realm" {
  realm = "management"
}

resource "keycloak_group" "admins" {
  realm_id = data.keycloak_realm.realm.id
  name     = "admins"
}

resource "keycloak_user" "operator" {
  realm_id       = data.keycloak_realm.realm.id
  username       = var.admin_email
  email          = var.admin_email
  email_verified = true
  enabled        = true
}

resource "keycloak_user_groups" "operator" {
  realm_id  = data.keycloak_realm.realm.id
  user_id   = keycloak_user.operator.id
  group_ids = [keycloak_group.admins.id]
}

resource "keycloak_authentication_flow" "existing_users_only" {
  realm_id    = data.keycloak_realm.realm.id
  alias       = "existing-users-only"
  description = "Links a Google sign-in to a user that already exists in the realm and refuses everyone else"
  provider_id = "basic-flow"
}

resource "keycloak_authentication_execution" "detect_existing_user" {
  realm_id          = data.keycloak_realm.realm.id
  parent_flow_alias = keycloak_authentication_flow.existing_users_only.alias
  authenticator     = "idp-detect-existing-broker-user"
  requirement       = "REQUIRED"
}

resource "keycloak_authentication_execution" "auto_link" {
  realm_id          = data.keycloak_realm.realm.id
  parent_flow_alias = keycloak_authentication_flow.existing_users_only.alias
  authenticator     = "idp-auto-link"
  requirement       = "REQUIRED"

  depends_on = [keycloak_authentication_execution.detect_existing_user]
}

resource "keycloak_oidc_google_identity_provider" "google" {
  realm         = data.keycloak_realm.realm.id
  client_id     = var.google_client_id
  client_secret = var.google_client_secret
  enabled       = true
  trust_email   = true
  store_token   = false
  sync_mode     = "IMPORT"

  default_scopes                = "openid email profile"
  first_broker_login_flow_alias = keycloak_authentication_flow.existing_users_only.alias
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
