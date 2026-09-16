data "keycloak_role" "master_admin" {
  realm_id = "master"
  name     = "admin"
}

resource "keycloak_user" "operator_admin" {
  realm_id = "master"
  username = var.operator_admin_user
  enabled  = true

  initial_password {
    value     = var.operator_admin_password
    temporary = false
  }
}

resource "keycloak_user_roles" "operator_admin" {
  realm_id = "master"
  user_id  = keycloak_user.operator_admin.id
  role_ids = [data.keycloak_role.master_admin.id]
}
