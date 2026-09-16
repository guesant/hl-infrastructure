import {
  to = keycloak_group.admins
  id = "homelab/17676ec3-f942-42f8-af4d-20dc24cf8f30"
}

import {
  to = keycloak_user.operator
  id = "homelab/4bab652d-2764-4bee-8a95-ea5b872622b5"
}

import {
  to = keycloak_openid_client_scope.groups
  id = "homelab/b0e81896-b536-4dd2-8c9d-edb8cb326cbe"
}

import {
  to = keycloak_openid_group_membership_protocol_mapper.groups
  id = "homelab/client-scope/b0e81896-b536-4dd2-8c9d-edb8cb326cbe/d608cc6a-3cb4-49a3-894f-0f0738ff69c5"
}

import {
  to = keycloak_openid_client.clients["blog"]
  id = "homelab/ebb38900-1214-4936-9ac0-6e0b09b9ee46"
}

import {
  to = keycloak_openid_client.clients["argocd"]
  id = "homelab/bf35f0f7-5e86-4ac6-bd37-3beba5fa77fd"
}

import {
  to = keycloak_openid_client.clients["grafana"]
  id = "homelab/78599700-f6bc-46f5-aaac-24855edc0188"
}

import {
  to = keycloak_authentication_flow.existing_users_only
  id = "homelab/697df7bb-4a1a-4723-a799-64d18fa75471"
}

import {
  to = keycloak_authentication_execution.detect_existing_user
  id = "homelab/697df7bb-4a1a-4723-a799-64d18fa75471/0e53bf05-5c99-447c-9244-4cebce9cc058"
}

import {
  to = keycloak_authentication_execution.auto_link
  id = "homelab/697df7bb-4a1a-4723-a799-64d18fa75471/c0df5801-2484-4e8c-a239-7b68b43596be"
}

import {
  to = keycloak_oidc_google_identity_provider.google
  id = "homelab/google"
}
