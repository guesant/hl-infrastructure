#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

policy=".config/secret-max-age.conf"
fail_on_stale=0

case "${1:-}" in
  "") ;;
  --fail-on-stale) fail_on_stale=1 ;;
  *)
    echo "usage: $0 [--fail-on-stale]" >&2
    exit 2
    ;;
esac

to_epoch() {
  date -u -D '%Y-%m-%dT%H:%M:%SZ' -d "$1" +%s 2>/dev/null || date -u -d "$1" +%s 2>/dev/null
}

max_age_for() {
  local file="$1" pattern days
  while read -r pattern days; do
    [ -z "$pattern" ] && continue
    # shellcheck disable=SC2053
    if [[ "$file" == $pattern ]]; then
      echo "$days"
      return 0
    fi
  done <"$policy"
  return 1
}

last_modified() {
  case "$1" in
    *.sops.env) sed -nE 's/^sops_lastmodified=(.+)$/\1/p' "$1" ;;
    *) sed -nE 's/^[[:space:]]+lastmodified:[[:space:]]*"?([^"[:space:]]+)"?[[:space:]]*$/\1/p' "$1" ;;
  esac
}

warn() {
  local file="$1" message="$2"
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    echo "::warning file=$file::$message"
  fi
}

now="$(date -u +%s)"
stale=0
checked=0

printf '%-80s %-22s %6s %6s  %s\n' "file" "lastmodified" "age" "max" "status"
while IFS= read -r file; do
  checked=$((checked + 1))
  if ! max_days="$(max_age_for "$file")"; then
    echo "$file matches no rule in $policy; add a catch-all '* <days>' line" >&2
    exit 2
  fi
  stamp="$(last_modified "$file")"
  if [ -z "$stamp" ] || ! epoch="$(to_epoch "$stamp")"; then
    printf '%-80s %-22s %6s %6s  %s\n' "$file" "-" "-" "$max_days" "NO SOPS DATE"
    warn "$file" "no SOPS lastmodified date found; is this file encrypted?"
    stale=$((stale + 1))
    continue
  fi
  age_days=$(((now - epoch) / 86400))
  if [ "$age_days" -gt "$max_days" ]; then
    printf '%-80s %-22s %5sd %5sd  %s\n' "$file" "$stamp" "$age_days" "$max_days" "ROTATE"
    warn "$file" "last re-encrypted $age_days days ago, past its $max_days-day rotation deadline"
    stale=$((stale + 1))
  else
    printf '%-80s %-22s %5sd %5sd  %s\n' "$file" "$stamp" "$age_days" "$max_days" "ok, $((max_days - age_days))d left"
  fi
done < <(
  find argocd -type f -name '*.sops-secret.yaml'
  find tofu node -type f -name '*.sops.env' 2>/dev/null
)

if [ "$stale" -eq 0 ]; then
  echo "all $checked SOPS files are within their rotation deadline"
  exit 0
fi

echo "$stale of $checked SOPS files need rotation; see docs/operacional/rotacionar-credenciais.md"
if [ "$fail_on_stale" -eq 1 ]; then
  exit 1
fi
exit 0
