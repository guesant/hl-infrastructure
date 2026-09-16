#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

env_file="tofu/keycloak-master/keycloak-master.sops.env"
ca_file="tofu/keycloak-master/internal-ca.crt"
keycloak_url="$(grep -oE 'keycloak_url += "[^"]+"' tofu/keycloak-master/terraform.tfvars | grep -oE 'https://[^"]+')"
: "${SOPS_AGE_KEY_FILE:?run this through: just keycloak-rotate-admin}"
: "${TOFU_IMAGE:?run this through: just keycloak-rotate-admin}"

admin_user="$(sops --decrypt --extract '["TF_VAR_keycloak_admin_user"]' "$env_file")"
operator_user="$(sops --decrypt --extract '["TF_VAR_operator_admin_user"]' "$env_file")"
[ "$admin_user" = "$operator_user" ] || {
  echo "the module still logs in as $admin_user, not as the permanent administrator; run just keycloak-bootstrap-admin first" >&2
  exit 1
}
current_password="$(sops --decrypt --extract '["TF_VAR_keycloak_admin_password"]' "$env_file")"
new_password="$(openssl rand -base64 48 | tr -d '\n=' | tr '+/' '-_')"

token_for() {
  curl -fsS --cacert "$ca_file" -X POST "$keycloak_url/realms/master/protocol/openid-connect/token" \
    -d client_id=admin-cli -d grant_type=password -d "username=$admin_user" --data-urlencode "password=$1" |
    python3 -c 'import json, sys; print(json.load(sys.stdin)["access_token"])'
}

token="$(token_for "$current_password")"
user_id="$(curl -fsS --cacert "$ca_file" -H "Authorization: Bearer $token" "$keycloak_url/admin/realms/master/users?username=$admin_user&exact=true" |
  python3 -c 'import json, sys; print(json.load(sys.stdin)[0]["id"])')"
printf '{"type":"password","temporary":false,"value":"%s"}' "$new_password" |
  curl -fsS --cacert "$ca_file" -H "Authorization: Bearer $token" -H "Content-Type: application/json" \
    -X PUT "$keycloak_url/admin/realms/master/users/$user_id/reset-password" --data-binary @- >/dev/null

token_for "$new_password" >/dev/null
echo "the permanent administrator now has a new password and it works"

for key in TF_VAR_keycloak_admin_password TF_VAR_operator_admin_password; do
  printf '"%s"' "$new_password" | sops --config .sops.yaml set --idempotent --value-stdin "$env_file" "[\"$key\"]"
done
unset new_password current_password
echo "$env_file updated; commit it"

if "$repo_root/.tools/tofu-run.sh" keycloak-master plan -detailed-exitcode >/dev/null; then
  echo "tofu/keycloak-master sees no drift"
else
  echo "the plan is not empty; run just tofu keycloak-master plan and review it" >&2
  exit 1
fi
