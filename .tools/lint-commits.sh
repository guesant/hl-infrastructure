#!/usr/bin/env bash
set -euo pipefail

from="${1:?usage: lint-commits.sh <from-ref> <to-ref>}"
to="${2:?usage: lint-commits.sh <from-ref> <to-ref>}"
commitlint_image="${COMMITLINT_IMAGE:-hl-infra/commitlint}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ "$from" =~ ^0+$ ]] || ! git cat-file -e "$from^{commit}" 2>/dev/null; then
  commits="$(git rev-list --no-merges -1 "$to")"
else
  commits="$(git rev-list --no-merges --reverse "$from..$to")"
fi

[ -n "$commits" ] || { echo "no commits to lint between $from and $to"; exit 0; }

status=0
for commit in $commits; do
  if ! git log -1 --format=%B "$commit" \
    | docker run --rm -i -v "$repo_root":/repo -w /repo "$commitlint_image" --config .config/commitlint.config.mjs; then
    echo "commit $(git log -1 --format='%h %s' "$commit") does not follow the convention" >&2
    status=1
  fi
done

if [ "$status" -eq 0 ]; then
  echo "every commit between $from and $to follows the convention"
fi
exit "$status"
