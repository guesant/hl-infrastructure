#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

value_pattern='REPLACE_WITH_[A-Z0-9_]+|[a-z0-9-]+(\.[a-z0-9-]+)*\.invalid([^a-z0-9-]|$)|changeme[-_@]|sha-0{40}'
status=0

if ! files="$(git ls-files -z --cached --others --exclude-standard | tr '\0' '\n')" || [ -z "$files" ]; then
  echo "could not list the repository files with git; refusing to report a clean result without scanning anything" >&2
  exit 2
fi

matches="$(
  git ls-files -z --cached --others --exclude-standard |
    xargs -0 grep -nIHE -- "$value_pattern" 2>/dev/null |
    grep -vE '^[^:]*\.example\.[^/:]*:' |
    grep -v 'placeholder-lint: ignore' || true
)"
if [ -n "$matches" ]; then
  echo "placeholder values left in the codebase:"
  echo "$matches"
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "no placeholder value left in the codebase"
fi
exit "$status"
