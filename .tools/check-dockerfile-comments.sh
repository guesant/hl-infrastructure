#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

status=0
while IFS= read -r file; do
  while IFS= read -r hit; do
    line="${hit%%:*}"
    text="${hit#*:}"
    if ! grep -qE '^[[:space:]]*#[[:space:]]*(IMPORTANT:|syntax=|escape=|check=|hadolint)' <<<"$text"; then
      echo "$file:$line: narrative comment not allowed; only tool directives and an IMPORTANT: marker are permitted" >&2
      status=1
    fi
  done < <(grep -nE '^[[:space:]]*#' "$file" || true)
done < <(git ls-files -- '*Dockerfile*' '*Containerfile*')

if [ "$status" -eq 0 ]; then
  echo "every Dockerfile comment is a tool directive or an IMPORTANT: marker"
fi
exit "$status"
