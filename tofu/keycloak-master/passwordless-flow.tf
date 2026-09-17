resource "keycloak_authentication_flow" "browser_passwordless" {
  for_each = local.realms

  realm_id = keycloak_realm.realms[each.key].id
  alias    = "browser passwordless"
}

resource "keycloak_authentication_execution" "browser_passwordless_cookie" {
  for_each = local.realms

  realm_id          = keycloak_realm.realms[each.key].id
  parent_flow_alias = keycloak_authentication_flow.browser_passwordless[each.key].alias
  authenticator     = "auth-cookie"
  requirement       = "ALTERNATIVE"
  priority          = 10
}

resource "keycloak_authentication_execution" "browser_passwordless_idp_redirect" {
  for_each = local.realms

  realm_id          = keycloak_realm.realms[each.key].id
  parent_flow_alias = keycloak_authentication_flow.browser_passwordless[each.key].alias
  authenticator     = "identity-provider-redirector"
  requirement       = "ALTERNATIVE"
  priority          = 20
}

resource "keycloak_authentication_execution" "browser_passwordless_webauthn" {
  for_each = local.realms

  realm_id          = keycloak_realm.realms[each.key].id
  parent_flow_alias = keycloak_authentication_flow.browser_passwordless[each.key].alias
  authenticator     = "webauthn-authenticator-passwordless"
  requirement       = "ALTERNATIVE"
  priority          = 30
}

resource "keycloak_authentication_subflow" "browser_passwordless_forms" {
  for_each = local.realms

  realm_id          = keycloak_realm.realms[each.key].id
  alias             = "browser passwordless forms"
  parent_flow_alias = keycloak_authentication_flow.browser_passwordless[each.key].alias
  provider_id       = "basic-flow"
  requirement       = "ALTERNATIVE"
  priority          = 40
}

resource "keycloak_authentication_execution" "browser_passwordless_username_password" {
  for_each = local.realms

  realm_id          = keycloak_realm.realms[each.key].id
  parent_flow_alias = keycloak_authentication_subflow.browser_passwordless_forms[each.key].alias
  authenticator     = "auth-username-password-form"
  requirement       = "REQUIRED"
  priority          = 10
}

resource "keycloak_authentication_subflow" "browser_passwordless_otp" {
  for_each = local.realms

  realm_id          = keycloak_realm.realms[each.key].id
  alias             = "browser passwordless conditional otp"
  parent_flow_alias = keycloak_authentication_subflow.browser_passwordless_forms[each.key].alias
  provider_id       = "basic-flow"
  requirement       = "CONDITIONAL"
  priority          = 20
}

resource "keycloak_authentication_execution" "browser_passwordless_otp_condition" {
  for_each = local.realms

  realm_id          = keycloak_realm.realms[each.key].id
  parent_flow_alias = keycloak_authentication_subflow.browser_passwordless_otp[each.key].alias
  authenticator     = "conditional-user-configured"
  requirement       = "REQUIRED"
  priority          = 10
}

resource "keycloak_authentication_execution" "browser_passwordless_otp_form" {
  for_each = local.realms

  realm_id          = keycloak_realm.realms[each.key].id
  parent_flow_alias = keycloak_authentication_subflow.browser_passwordless_otp[each.key].alias
  authenticator     = "auth-otp-form"
  requirement       = "REQUIRED"
  priority          = 20
}

resource "keycloak_authentication_bindings" "browser_passwordless" {
  for_each = local.realms

  realm_id     = keycloak_realm.realms[each.key].id
  browser_flow = keycloak_authentication_flow.browser_passwordless[each.key].alias
}
