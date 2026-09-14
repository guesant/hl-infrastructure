#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

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

skipped=0

while IFS= read -r file; do
  if ! sops filestatus "$file" | grep -q '"encrypted": true'; then
    echo "$file: not encrypted yet, skipping"
    skipped=$((skipped + 1))
    continue
  fi
  sops --config .sops.yaml updatekeys --yes "$file"
done < <(find argocd -type f -name '*-sopssecret.yaml')

if [ "$skipped" -gt 0 ]; then
  echo "recipients synced on every already-encrypted SopsSecret; $skipped file(s) skipped, not encrypted yet"
else
  echo "recipients on every SopsSecret now match .sops.yaml"
fi
