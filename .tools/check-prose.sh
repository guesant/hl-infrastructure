#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if grep -rnE '—|–|→|←|⇒|⇐|↔' README.md SECURITY.md SUPPORT.md CONTRIBUTING.md docs --include='*.md'; then
  echo "found an em dash, en dash or Unicode arrow; rewrite with a comma, a new sentence, > or ->" >&2
  exit 1
fi

echo "no em dash, en dash or Unicode arrow in the prose"
