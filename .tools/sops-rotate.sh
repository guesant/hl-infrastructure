#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

target="${1:-}"

if [ -n "$target" ]; then
  if [[ "$target" != *.sops-secret.yaml && "$target" != *.sops.env && "$target" != *.sops.yaml ]]; then
    echo "usage: $0 [path/to/some.sops-secret.yaml | path/to/some.sops.env | path/to/some.sops.yaml]" >&2
    exit 2
  fi
  if [ ! -f "$target" ]; then
    echo "$target does not exist" >&2
    exit 1
  fi
fi

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

rotated=0
skipped=0

rotate_one() {
  local file="$1"
  if ! sops filestatus "$file" | grep -q '"encrypted":true'; then
    echo "$file: not encrypted yet, skipping"
    skipped=$((skipped + 1))
    return
  fi
  sops --config .sops.yaml rotate --in-place "$file"
  echo "$file: data key rotated"
  rotated=$((rotated + 1))
}

if [ -n "$target" ]; then
  rotate_one "$target"
else
  while IFS= read -r file; do
    rotate_one "$file"
  done < <(
    find argocd -type f -name '*.sops-secret.yaml'
    find tofu -type f -name '*.sops.env' 2>/dev/null
    find ansible/group_vars -type f -name '*.sops.yaml' 2>/dev/null
  )
fi

echo "rotated the data key on $rotated file(s), skipped $skipped not-yet-encrypted file(s)"
