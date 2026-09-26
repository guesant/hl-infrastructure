#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

prose_paths=(README.md SECURITY.md SUPPORT.md CONTRIBUTING.md docs)
forbidden_pattern=$'[\u2014\u2013\u2192\u2190\u21d2\u21d0\u2194]'

if grep -rnE "$forbidden_pattern" "${prose_paths[@]}" --include='*.md'; then
  echo "found an em dash, en dash or Unicode arrow; rewrite with a comma, a new sentence, > or ->" >&2
  exit 1
fi

quote_exceptions_file=".config/prose-quote-exceptions"
quote_pattern=$'[\u201c\u201d\u201e\u201f\u00ab\u00bb\u2018\u2019\u201a\u201b\u2039\u203a\uff02\uff07]'
quote_violations="$(grep -rnE "$quote_pattern" "${prose_paths[@]}" --include='*.md' || true)"

if [[ -n "$quote_violations" ]]; then
  invalid_quote_violations=()
  while IFS= read -r violation; do
    [[ -z "$violation" ]] && continue
    path="${violation%%:*}"
    remainder="${violation#*:}"
    line="${remainder%%:*}"
    exception_prefix="$path|$line|"

    if [[ ! -f "$quote_exceptions_file" ]] || ! grep -Fq -- "$exception_prefix" "$quote_exceptions_file"; then
      invalid_quote_violations+=("$violation")
    fi
  done <<< "$quote_violations"

  if (( ${#invalid_quote_violations[@]} > 0 )); then
    printf '%s\n' "${invalid_quote_violations[@]}"
    echo "found typographic quotes; use straight keyboard quotes, or record a justified exception as path|line|reason in $quote_exceptions_file" >&2
    exit 1
  fi
fi

if [[ -f "$quote_exceptions_file" ]]; then
  invalid_quote_exceptions=()
  while IFS='|' read -r path line reason extra; do
    [[ -z "$path" && -z "$line" && -z "$reason" && -z "$extra" ]] && continue

    if [[ -z "$path" || ! "$line" =~ ^[0-9]+$ || -z "$reason" || -n "$extra" ]]; then
      invalid_quote_exceptions+=("$path|$line|$reason${extra:+|$extra}")
      continue
    fi

    if ! grep -Fq -- "$path:$line:" <<< "$quote_violations"; then
      invalid_quote_exceptions+=("$path|$line|$reason")
    fi
  done < "$quote_exceptions_file"

  if (( ${#invalid_quote_exceptions[@]} > 0 )); then
    printf '%s\n' "${invalid_quote_exceptions[@]}"
    echo "found invalid or stale entries in $quote_exceptions_file; every exception needs a current path, line and reason" >&2
    exit 1
  fi
fi

echo "no em dash, en dash, Unicode arrow or unjustified typographic quote in the prose"
