resource "keycloak_authentication_flow" "existing_users_only" {
  realm_id    = keycloak_realm.homelab.id
  alias       = "existing-users-only"
  description = "Links a Google sign-in to a user that already exists in the realm and refuses everyone else"
  provider_id = "basic-flow"
}

resource "keycloak_authentication_execution" "detect_existing_user" {
  realm_id          = keycloak_realm.homelab.id
  parent_flow_alias = keycloak_authentication_flow.existing_users_only.alias
  authenticator     = "idp-detect-existing-broker-user"
  requirement       = "REQUIRED"
}

resource "keycloak_authentication_execution" "auto_link" {
  realm_id          = keycloak_realm.homelab.id
  parent_flow_alias = keycloak_authentication_flow.existing_users_only.alias
  authenticator     = "idp-auto-link"
  requirement       = "REQUIRED"

  depends_on = [keycloak_authentication_execution.detect_existing_user]
}

resource "keycloak_oidc_google_identity_provider" "google" {
  realm         = keycloak_realm.homelab.id
  client_id     = var.google_client_id
  client_secret = var.google_client_secret
  enabled       = true
  trust_email   = true
  store_token   = false
  sync_mode     = "IMPORT"

  default_scopes                = "openid email profile"
  first_broker_login_flow_alias = keycloak_authentication_flow.existing_users_only.alias
}
