#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

secret_file="argocd/apps/satellites/blog/cloudflared/templates/tunnel-token.sops-secret.yaml"
token_path='["spec"]["secretTemplates"][0]["stringData"]["token"]'

for name in CLOUDFLARE_API_TOKEN TF_VAR_state_passphrase TOFU_IMAGE OPS_IMAGE SOPS_AGE_KEY_FILE; do
  if [ -z "${!name:-}" ]; then
    echo "$name is not set; run this through: just cloudflare-tunnel-token" >&2
    exit 2
  fi
done

tofu_output() {
  docker run --rm -v "$repo_root":/repo -w /repo -e TF_VAR_state_passphrase \
    "$TOFU_IMAGE" -chdir=tofu/cloudflare output -raw "$1"
}

account_id="$(tofu_output cloudflare_account_id)"
tunnel_id="$(tofu_output tunnel_id)"

token="$(
  docker run --rm -e CLOUDFLARE_API_TOKEN -e ACCOUNT_ID="$account_id" -e TUNNEL_ID="$tunnel_id" \
    --entrypoint bash "$OPS_IMAGE" -c \
    'curl -fsS -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/token" | jq -er .result'
)"

if [[ ! "$token" =~ ^[A-Za-z0-9_=-]+$ ]]; then
  echo "the Cloudflare API returned something that does not look like a tunnel token" >&2
  exit 1
fi

before="$(shasum -a 256 "$secret_file")"
printf '"%s"' "$token" | sops --config .sops.yaml set --idempotent --value-stdin "$secret_file" "$token_path"
after="$(shasum -a 256 "$secret_file")"

if [ "$before" = "$after" ]; then
  echo "$secret_file already holds the current tunnel token"
else
  echo "$secret_file now holds the current tunnel token; review the diff, commit and push"
fi
