resource "keycloak_realm" "homelab" {
  realm   = "homelab"
  enabled = true

  ssl_required             = "external"
  registration_allowed     = false
  reset_password_allowed   = false
  remember_me              = false
  login_with_email_allowed = true
  duplicate_emails_allowed = false

  access_token_lifespan    = "5m"
  sso_session_idle_timeout = "8h"
  sso_session_max_lifespan = "24h"

  security_defenses {
    brute_force_detection {
      permanent_lockout          = false
      max_login_failures         = 10
      wait_increment_seconds     = 60
      max_failure_wait_seconds   = 900
      failure_reset_time_seconds = 43200
    }
  }
}

resource "keycloak_group" "homelab_admins" {
  realm_id = keycloak_realm.homelab.id
  name     = "homelab-admins"
}

resource "keycloak_user" "operator" {
  realm_id       = keycloak_realm.homelab.id
  username       = var.admin_email
  email          = var.admin_email
  email_verified = true
  enabled        = true
}

resource "keycloak_user_groups" "operator" {
  realm_id = keycloak_realm.homelab.id
  user_id  = keycloak_user.operator.id
  group_ids = [
    keycloak_group.homelab_admins.id,
  ]
}
