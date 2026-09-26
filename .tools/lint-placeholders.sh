#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

value_pattern='REPLACE_WITH_[A-Z0-9_]+|[a-z0-9-]+(\.[a-z0-9-]+)*\.invalid([^a-z0-9-]|$)|changeme[-_@]|sha-0{40}'
status=0

if ! files="$(git ls-files -z --cached --others --exclude-standard | tr '\0' '\n')" || [ -z "$files" ]; then
  echo "could not list the repository files with git; refusing to report a clean result without scanning anything" >&2
  exit 2
fi

matches="$(
  git ls-files -z --cached --others --exclude-standard |
    xargs -0 grep -nIHE -- "$value_pattern" 2>/dev/null |
    grep -vE '^[^:]*\.example\.[^/:]*:' |
    grep -v 'placeholder-lint: ignore' || true
)"
if [ -n "$matches" ]; then
  echo "placeholder values left in the codebase:"
  echo "$matches"
  status=1
fi

tofu_hostname="$(sed -nE 's/^blog_hostname[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' tofu/cloudflare/terraform.tfvars)"
site_url="$(sed -nE 's/^[[:space:]]{2}PUBLIC_SITE_BASE_URL:[[:space:]]*"?([^"[:space:]]+).*/\1/p' argocd/apps/secrets/satellites/blog/laravel-configmap.yaml)"
site_hostname="${site_url#https://}"
site_hostname="${site_hostname%%/*}"
if [ -z "$tofu_hostname" ] || [ "$tofu_hostname" != "$site_hostname" ]; then
  echo "hostname mismatch: blog_hostname in tofu/cloudflare/terraform.tfvars is '$tofu_hostname', PUBLIC_SITE_BASE_URL in the blog secrets values.yaml is '$site_url'"
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "no placeholder value left in the codebase, and the blog hostname matches in OpenTofu and in the blog"
fi
exit "$status"
