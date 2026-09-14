#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ -z "${SOPS_AGE_KEY_FILE:-}" ]; then
  echo "SOPS_AGE_KEY_FILE must point at a decrypting identity; run this through: just placeholders" >&2
  exit 2
fi

status=0

report() {
  echo "$1"
  status=1
}

while IFS= read -r file; do
  if ! plaintext="$(sops --config .sops.yaml decrypt "$file" 2>/dev/null)"; then
    report "$file: could not decrypt with SOPS_AGE_KEY_FILE"
    continue
  fi
  while IFS= read -r key; do
    report "$file: $key still holds a placeholder"
  done < <(printf '%s\n' "$plaintext" | sed -nE 's/^[[:space:]]*"?([A-Za-z0-9_.-]+)"?[:=][[:space:]]*"?REPLACE_WITH_.*/\1/p')
done < <(
  find argocd -type f -name '*.sops-secret.yaml'
  find tofu -type f -name '*.sops.env'
)

while IFS= read -r match; do
  report "$match"
done < <(grep -rnE 'REPLACE_WITH_|example\.invalid' argocd tofu --include='*.yaml' --include='*.yml' --include='*.tfvars' | grep -v 'ENC\[' || true)

tofu_hostname="$(sed -nE 's/^blog_hostname[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' tofu/cloudflare/terraform.tfvars)"
site_url="$(sed -nE 's/^[[:space:]]*PUBLIC_SITE_BASE_URL:[[:space:]]*"?([^"[:space:]]+).*/\1/p' argocd/apps/satellites/blog/blog/values.yaml)"
site_hostname="${site_url#https://}"
site_hostname="${site_hostname%%/*}"
if [ "$tofu_hostname" != "$site_hostname" ]; then
  report "hostname mismatch: blog_hostname in tofu/cloudflare/terraform.tfvars is $tofu_hostname, PUBLIC_SITE_BASE_URL in the blog values.yaml is $site_url"
fi

if [ "$status" -eq 0 ]; then
  echo "nothing pending: no placeholder left and the blog hostname matches in OpenTofu and in the blog"
fi
exit "$status"
