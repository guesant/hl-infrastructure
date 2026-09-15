#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

config=.config/security-review.conf
fail_on_stale=false
[ "${1:-}" = "--fail-on-stale" ] && fail_on_stale=true

last_review="$(sed -nE 's/^last_review=([0-9]{4}-[0-9]{2}-[0-9]{2})$/\1/p' "$config")"
max_age_days="$(sed -nE 's/^max_age_days=([0-9]+)$/\1/p' "$config")"
[ -n "$last_review" ] && [ -n "$max_age_days" ] || { echo "$config must set last_review=YYYY-MM-DD and max_age_days=N" >&2; exit 2; }

reviewed_at="$(date -u -D '%Y-%m-%d' -d "$last_review" +%s 2>/dev/null || date -u -d "$last_review" +%s)"
age_days=$(( ($(date -u +%s) - reviewed_at) / 86400 ))

message="the last permission and exposure review was on $last_review, $age_days days ago (deadline $max_age_days days)"
if [ "$age_days" -gt "$max_age_days" ]; then
  if [ "${GITHUB_ACTIONS:-}" = true ]; then echo "::warning::$message"; fi
  echo "$message; run the review in docs/operacional/revisao-periodica.md and update $config" >&2
  if "$fail_on_stale"; then exit 1; fi
else
  echo "$message"
fi
