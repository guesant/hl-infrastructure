#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if grep -rnE '^\s*(-\s*)?image:\s*"?[^"[:space:]]+"?\s*$' "$repo_root/rendered" "$repo_root/argocd" | grep -v '@sha256:'; then
  echo "found an image without a digest; every image must be pinned by @sha256" >&2
  exit 1
fi

echo "every image in rendered/ and argocd/ is pinned by digest"
