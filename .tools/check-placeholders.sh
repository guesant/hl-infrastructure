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
  done < <(printf '%s\n' "$plaintext" | sed -nE 's/^[[:space:]]*"?([A-Za-z0-9_.-]+)"?[:=][[:space:]]*"?REPLACE_WITH_[A-Z0-9_]+.*/\1/p')
done < <(
  find argocd -type f -name '*.sops-secret.yaml'
  find tofu ansible/recovery -type f -name '*.sops.env' 2>/dev/null
  find ansible/group_vars -type f -name '*.sops.yaml' 2>/dev/null
)

if ! .tools/lint-placeholders.sh; then
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "nothing pending: no placeholder in plaintext or inside encrypted files"
fi
exit "$status"
