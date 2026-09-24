#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

status=0
while IFS= read -r file; do
  while IFS= read -r line; do
    paths="$(sed -nE 's/.*paths="([^"]+)".*/\1/p' <<<"$line")"
    if [ -z "$paths" ]; then
      echo "$file: malformed source-of-trust marker: $line" >&2
      status=1
      continue
    fi
    # shellcheck disable=SC2086
    source_commit="$(git log --no-merges -1 --format=%H -- $paths)"
    page_commit="$(git log -1 --format=%H -- "$file")"
    if [ -n "$source_commit" ] && [ -n "$page_commit" ] && ! git merge-base --is-ancestor "$source_commit" "$page_commit"; then
      echo "$file: its sources ($paths) changed in $(git rev-parse --short "$source_commit") after the page was last reviewed in $(git rev-parse --short "$page_commit"); review the page and commit it" >&2
      status=1
    fi
    # shellcheck disable=SC2086
    if [ -n "$(git status --porcelain -- $paths)" ] && [ -z "$(git status --porcelain -- "$file")" ]; then
      echo "$file: its sources ($paths) have uncommitted changes but the page does not; review it before committing" >&2
      status=1
    fi
  done < <(grep -hE '<!-- source-of-trust ' "$file" || true)
done < <(grep -rlE '<!-- source-of-trust ' docs --include='*.md' || true)

if [ "$status" -eq 0 ]; then
  echo "every page with a source-of-trust marker was reviewed after its sources last changed"
fi
exit "$status"
