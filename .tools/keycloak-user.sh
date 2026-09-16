#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

realm="${1:-}"
username="${2:-}"
email="${3:-}"
if [ -z "$realm" ] || [ -z "$username" ]; then
  echo "usage: $0 <realm> <username> [email]" >&2
  exit 2
fi

env_file="tofu/keycloak-master/keycloak-master.sops.env"
ca_file="tofu/keycloak-master/internal-ca.crt"
keycloak_url="$(grep -oE 'keycloak_url += "[^"]+"' tofu/keycloak-master/terraform.tfvars | grep -oE 'https://[^"]+')"
: "${SOPS_AGE_KEY_FILE:?run this through: just keycloak-user}"

admin_user="$(sops --decrypt --extract '["TF_VAR_keycloak_admin_user"]' "$env_file")"
admin_password="$(sops --decrypt --extract '["TF_VAR_keycloak_admin_password"]' "$env_file")"

token="$(curl -fsS --cacert "$ca_file" -X POST "$keycloak_url/realms/master/protocol/openid-connect/token" \
  -d client_id=admin-cli -d grant_type=password -d "username=$admin_user" --data-urlencode "password=$admin_password" |
  python3 -c 'import json, sys; print(json.load(sys.stdin)["access_token"])')"
api="$keycloak_url/admin/realms/$realm"
auth=(-H "Authorization: Bearer $token" -H "Content-Type: application/json")

read -r -s -p "Temporary password for $username in $realm (it must be changed on first login): " password
echo
read -r -s -p "Repeat it: " password_again
echo
[ "$password" = "$password_again" ] || {
  echo "the passwords do not match" >&2
  exit 1
}
[ "${#password}" -ge 12 ] || {
  echo "use at least 12 characters" >&2
  exit 1
}

existing="$(curl -fsS --cacert "$ca_file" "${auth[@]}" "$api/users?username=$username&exact=true" |
  python3 -c 'import json, sys; users = json.load(sys.stdin); print(users[0]["id"] if users else "")')"
if [ -n "$existing" ]; then
  echo "$username already exists in $realm; only its password and memberships are (re)applied"
  user_id="$existing"
else
  body="$(python3 -c 'import json, sys; print(json.dumps({"username": sys.argv[1], "email": sys.argv[2] or None, "emailVerified": bool(sys.argv[2]), "enabled": True, "requiredActions": ["UPDATE_PASSWORD", "CONFIGURE_TOTP"]}))' "$username" "$email")"
  curl -fsS --cacert "$ca_file" "${auth[@]}" -X POST "$api/users" --data "$body" >/dev/null
  user_id="$(curl -fsS --cacert "$ca_file" "${auth[@]}" "$api/users?username=$username&exact=true" |
    python3 -c 'import json, sys; print(json.load(sys.stdin)[0]["id"])')"
  echo "created $username in $realm"
fi

printf '{"type":"password","temporary":true,"value":%s}' "$(python3 -c 'import json, sys; print(json.dumps(sys.argv[1]))' "$password")" |
  curl -fsS --cacert "$ca_file" "${auth[@]}" -X PUT "$api/users/$user_id/reset-password" --data-binary @- >/dev/null
unset password password_again

if [ "$realm" = "master" ]; then
  role="$(curl -fsS --cacert "$ca_file" "${auth[@]}" "$api/roles/admin")"
  printf '[%s]' "$role" | curl -fsS --cacert "$ca_file" "${auth[@]}" -X POST "$api/users/$user_id/role-mappings/realm" --data-binary @- >/dev/null
  echo "$username holds the realm role admin in master"
else
  group_id="$(curl -fsS --cacert "$ca_file" "${auth[@]}" "$api/groups?search=admins&exact=true" |
    python3 -c 'import json, sys; groups = [g for g in json.load(sys.stdin) if g["name"] == "admins"]; print(groups[0]["id"] if groups else "")')"
  [ -n "$group_id" ] || {
    echo "the group admins does not exist in $realm; apply tofu/keycloak-$realm first" >&2
    exit 1
  }
  curl -fsS --cacert "$ca_file" "${auth[@]}" -X PUT "$api/users/$user_id/groups/$group_id" >/dev/null
  echo "$username is in the group admins of $realm"
fi
echo "on the first login the Keycloak asks for a new password and a TOTP; nothing about this user is stored in the repository"
