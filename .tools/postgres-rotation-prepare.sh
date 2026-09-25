#!/usr/bin/env bash
set -euo pipefail

app="${1:-}"
slot="${2:-}"
values_file="argocd/apps/secrets/data/postgres/values.yaml"

case "$app" in
portfolio)
  source_prefix="portfolio-postgres-app"
  database="portfolio"
  user_prefix="portfolio"
  ;;
keycloak)
  source_prefix="keycloak-postgres-app"
  database="keycloak"
  user_prefix="keycloak"
  ;;
*)
  echo "usage: $0 <portfolio|keycloak> <a|b>" >&2
  exit 2
  ;;
esac

case "$slot" in
a|b)
  ;;
*)
  echo "usage: $0 <portfolio|keycloak> <a|b>" >&2
  exit 2
  ;;
esac

active_slot="$(yq -r ".rotation.${app}.activeSlot" "$values_file")"
test "$active_slot" != "$slot" || {
  echo "$app slot $slot is already active" >&2
  exit 1
}

user="${user_prefix}_${slot}"
output="argocd/apps/secrets/data/postgres/templates/${source_prefix}-${slot}.sops-secret.yaml"
secret_name="${source_prefix}-${slot}"
password="$(head -c 48 /dev/urandom | base64 | tr -d '\n')"
temporary="$(mktemp "${output}.XXXXXX")"
trap 'rm -f "$temporary"; unset password' EXIT

{
  printf '%s\n' \
    'apiVersion: isindir.github.com/v1alpha3' \
    'kind: SopsSecret' \
    'metadata:' \
    "    name: ${secret_name}" \
    '    annotations:' \
    '        argocd.argoproj.io/sync-wave: "-1"' \
    'spec:' \
    '    secretTemplates:' \
    "        - name: ${secret_name}" \
    '          type: kubernetes.io/basic-auth' \
    '          labels:' \
    '              cnpg.io/reload: "true"' \
    '          stringData:' \
    '            host: postgres-rw.data.svc.cluster.local' \
    "            dbname: ${database}" \
    "            user: ${user}" \
    "            username: ${user}" \
    "            password: ${password}"
} | sops --config .sops.yaml \
  --filename-override "$output" \
  --encrypted-suffix Templates \
  --input-type yaml \
  --output-type yaml \
  --encrypt /dev/stdin >"$temporary"

mv "$temporary" "$output"
trap - EXIT
unset password
yq -i ".rotation.${app}.retiredSlot = \"\"" "$values_file"
printf '%s slot %s prepared\n' "$app" "$slot"
