#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ -z "${SOPS_AGE_KEY_FILE:-}" ]; then
  echo "SOPS_AGE_KEY_FILE must point at a decrypting identity" >&2
  exit 2
fi

status=0

while IFS= read -r file; do
  if sops --config .sops.yaml -d "$file" >/dev/null 2>/tmp/sops-drill-err; then
    echo "$file: OK"
  else
    echo "$file: FAIL"
    sed 's/^/  /' /tmp/sops-drill-err >&2
    status=1
  fi
  rm -f /tmp/sops-drill-err
done < <(find argocd -type f -name '*.sops-secret.yaml')

exit "$status"
