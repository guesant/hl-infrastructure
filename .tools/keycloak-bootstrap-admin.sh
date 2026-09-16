#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

env_file="tofu/keycloak-master/keycloak-master.sops.env"
ca_file="tofu/keycloak-master/internal-ca.crt"
keycloak_url="$(grep -oE 'keycloak_url += "[^"]+"' tofu/keycloak-master/terraform.tfvars | grep -oE 'https://[^"]+')"

for name in SOPS_AGE_KEY_FILE TOFU_IMAGE KUBECONFIG; do
  if [ -z "${!name:-}" ]; then
    echo "$name is not set; run this through: just keycloak-bootstrap-admin" >&2
    exit 2
  fi
done

read_env() {
  sops --decrypt --extract "[\"$1\"]" "$env_file"
}

module_user="$(read_env TF_VAR_keycloak_admin_user)"
operator_user="$(read_env TF_VAR_operator_admin_user)"
operator_password="$(read_env TF_VAR_operator_admin_password)"

token_for() {
  curl -fsS --cacert "$ca_file" -X POST "$keycloak_url/realms/master/protocol/openid-connect/token" \
    -d client_id=admin-cli -d grant_type=password -d "username=$1" --data-urlencode "password=$2" |
    python3 -c 'import json, sys; print(json.load(sys.stdin)["access_token"])'
}

if [ "$module_user" != "$operator_user" ]; then
  echo "applying tofu/keycloak-master with the bootstrap administrator, so the permanent one exists"
  "$repo_root/.tools/tofu-run.sh" keycloak-master apply -auto-approve
fi

echo "logging in as the permanent administrator"
token="$(token_for "$operator_user" "$operator_password")"

temp_user="$(kubectl -n keycloak get secret keycloak-initial-admin -o jsonpath='{.data.username}' 2>/dev/null | base64 -d || true)"
if [ -z "$temp_user" ]; then
  temp_user="temp-admin"
  echo "kubectl could not read keycloak-initial-admin; assuming the operator's default bootstrap user, $temp_user"
fi
if [ "$temp_user" != "$operator_user" ]; then
  temp_id="$(curl -fsS --cacert "$ca_file" -H "Authorization: Bearer $token" \
    "$keycloak_url/admin/realms/master/users?username=$temp_user&exact=true" |
    python3 -c 'import json, sys; users = json.load(sys.stdin); print(users[0]["id"] if users else "")')"
  if [ -n "$temp_id" ]; then
    curl -fsS --cacert "$ca_file" -H "Authorization: Bearer $token" -X DELETE "$keycloak_url/admin/realms/master/users/$temp_id"
    echo "deleted the bootstrap administrator $temp_user from the master realm"
  else
    echo "the bootstrap administrator $temp_user is already gone"
  fi
fi

if [ "$module_user" != "$operator_user" ]; then
  printf '"%s"' "$operator_user" | sops --config .sops.yaml set --idempotent --value-stdin "$env_file" '["TF_VAR_keycloak_admin_user"]'
  printf '"%s"' "$operator_password" | sops --config .sops.yaml set --idempotent --value-stdin "$env_file" '["TF_VAR_keycloak_admin_password"]'
  echo "tofu/keycloak-master now logs in as the permanent administrator; commit $env_file"
else
  echo "tofu/keycloak-master already logs in as the permanent administrator"
fi

echo "checking that the module sees no drift with the new credential"
if "$repo_root/.tools/tofu-run.sh" keycloak-master plan -detailed-exitcode >/dev/null; then
  echo "no drift"
else
  echo "the plan is not empty; run just tofu keycloak-master plan and review it" >&2
  exit 1
fi
