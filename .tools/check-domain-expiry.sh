#!/usr/bin/env bash
set -euo pipefail

domain="${DOMAIN:-guesant.net}"
warn_days="${WARN_DAYS:-60}"
fail_days="${FAIL_DAYS:-30}"
fail_on_near=false
[ "${1:-}" = "--fail-on-near" ] && fail_on_near=true

tld="${domain##*.}"
bootstrap="$(curl -fsSL --max-time 20 https://data.iana.org/rdap/dns.json)"
base="$(jq -r --arg tld "$tld" '.services[] | select(.[0] | index($tld)) | .[1][0]' <<<"$bootstrap" | head -1)"
[ -n "$base" ] || { echo "no RDAP server for .$tld" >&2; exit 2; }

expiration="$(curl -fsSL --max-time 20 "${base%/}/domain/$domain" | jq -r '.events[] | select(.eventAction == "expiration") | .eventDate')"
[ -n "$expiration" ] || { echo "RDAP returned no expiration date for $domain" >&2; exit 2; }

timestamp="${expiration%%.*}"
timestamp="${timestamp%Z}"
expires_at="$(date -u -D '%Y-%m-%dT%H:%M:%S' -d "$timestamp" +%s 2>/dev/null || date -u -d "${timestamp}Z" +%s)"
days_left=$(( (expires_at - $(date -u +%s)) / 86400 ))

message="$domain expires on ${expiration%%T*}, in $days_left days"
if [ "$days_left" -le "$fail_days" ]; then
  if [ "${GITHUB_ACTIONS:-}" = true ]; then echo "::error::$message"; fi
  echo "$message; renew it now" >&2
  if "$fail_on_near"; then exit 1; fi
elif [ "$days_left" -le "$warn_days" ]; then
  if [ "${GITHUB_ACTIONS:-}" = true ]; then echo "::warning::$message"; fi
  echo "$message; renew it soon"
else
  echo "$message"
fi
