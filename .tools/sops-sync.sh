#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

target="${1:-}"

if [ -n "$target" ]; then
  if [[ "$target" != *-sopssecret.yaml ]]; then
    echo "usage: $0 [path/to/some-sopssecret.yaml]" >&2
    exit 2
  fi
  if [ ! -f "$target" ]; then
    echo "$target does not exist" >&2
    exit 1
  fi
fi

require_host_identity() {
  for tool in sops age-plugin-se; do
    command -v "$tool" >/dev/null 2>&1 || {
      echo "$tool not found in PATH; run: brew install sops age age-plugin-se" >&2
      exit 1
    }
  done
  if [ -z "${SOPS_AGE_KEY_FILE:-}" ]; then
    echo "SOPS_AGE_KEY_FILE must point at a decrypting identity (the operator SE identity or the DR key)" >&2
    exit 2
  fi
}

encrypted_now=0
synced_now=0

sync_one() {
  local file="$1"
  if ! sops filestatus "$file" | grep -q '"encrypted":true'; then
    local tmp
    tmp="$(mktemp "${file}.XXXXXX")"
    trap 'rm -f "$tmp"' EXIT
    sops --config .sops.yaml encrypt "$file" >"$tmp"
    mv "$tmp" "$file"
    trap - EXIT
    echo "$file: encrypted"
    encrypted_now=$((encrypted_now + 1))
    return
  fi
  require_host_identity
  sops --config .sops.yaml updatekeys --yes "$file"
  synced_now=$((synced_now + 1))
}

if [ -n "$target" ]; then
  sync_one "$target"
else
  while IFS= read -r file; do
    sync_one "$file"
  done < <(find argocd -type f -name '*-sopssecret.yaml')
fi

if [ "$encrypted_now" -gt 0 ] || [ "$synced_now" -gt 0 ]; then
  echo "every SopsSecret is now encrypted with the current recipients ($encrypted_now newly encrypted, $synced_now re-keyed)"
else
  echo "recipients on every SopsSecret already match .sops.yaml"
fi
