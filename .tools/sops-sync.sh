#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

target="${1:-}"

if [ -n "$target" ]; then
  if [[ "$target" != *.sops-secret.yaml ]]; then
    echo "usage: $0 [path/to/some.sops-secret.yaml]" >&2
    exit 2
  fi
  if [ ! -f "$target" ]; then
    echo "$target does not exist" >&2
    exit 1
  fi
fi

encrypted_now=0
checked_now=0

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
  if ! sops --config .sops.yaml updatekeys --yes "$file"; then
    echo "$file: could not re-key; SOPS_AGE_KEY_FILE must point at a decrypting identity (the operator SE identity or the DR key)" >&2
    exit 1
  fi
  checked_now=$((checked_now + 1))
}

if [ -n "$target" ]; then
  sync_one "$target"
else
  while IFS= read -r file; do
    sync_one "$file"
  done < <(find argocd -type f -name '*.sops-secret.yaml')
fi

echo "every SopsSecret is now encrypted with the current recipients ($encrypted_now newly encrypted, $checked_now already-encrypted file(s) checked)"
