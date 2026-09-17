locals {
  realm_settings = {
    ssl_required             = "external"
    registration_allowed     = false
    reset_password_allowed   = false
    remember_me              = false
    login_with_email_allowed = true
    duplicate_emails_allowed = false
    access_token_lifespan    = "5m"
    sso_session_idle_timeout = "8h"
    sso_session_max_lifespan = "24h"
  }
  realms = {
    homelab    = "homelab@auth.guesant.internal"
    management = "management@auth.guesant.internal"
  }
}

resource "keycloak_realm" "realms" {
  for_each = local.realms

  realm        = each.key
  display_name = each.value
  enabled      = true

  ssl_required             = local.realm_settings.ssl_required
  registration_allowed     = local.realm_settings.registration_allowed
  reset_password_allowed   = local.realm_settings.reset_password_allowed
  remember_me              = local.realm_settings.remember_me
  login_with_email_allowed = local.realm_settings.login_with_email_allowed
  duplicate_emails_allowed = local.realm_settings.duplicate_emails_allowed
  access_token_lifespan    = local.realm_settings.access_token_lifespan
  sso_session_idle_timeout = local.realm_settings.sso_session_idle_timeout
  sso_session_max_lifespan = local.realm_settings.sso_session_max_lifespan

  security_defenses {
    brute_force_detection {
      permanent_lockout          = false
      max_login_failures         = 10
      wait_increment_seconds     = 60
      max_failure_wait_seconds   = 900
      failure_reset_time_seconds = 43200
    }
  }

  web_authn_passwordless_policy {
    passwordless_passkeys_enabled = true
    discoverable_credential       = "required"
    user_verification_requirement = "required"
  }
}
