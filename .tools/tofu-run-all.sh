#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <tofu arguments...>" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for dir in tofu/*/; do
  module="$(basename "$dir")"
  echo "=== $module ==="
  "$repo_root/.tools/tofu-run.sh" "$module" "$@"
done
