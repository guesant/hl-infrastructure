#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

file="${1:-}"

if [ -z "$file" ] || [[ "$file" != *-sopssecret.yaml ]]; then
  echo "usage: $0 <path/to/some-sopssecret.yaml>" >&2
  exit 2
fi

if [ ! -f "$file" ]; then
  echo "$file does not exist" >&2
  exit 1
fi

if sops filestatus "$file" | grep -q '"encrypted": true'; then
  echo "$file is already encrypted"
  exit 0
fi

tmp="$(mktemp "${file}.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

sops encrypt "$file" >"$tmp"
mv "$tmp" "$file"
trap - EXIT

echo "encrypted $file"
