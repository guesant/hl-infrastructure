#!/usr/bin/env bash
set -euo pipefail

before="${1:?usage: render-diff.sh <base-tree> <head-tree>}"
after="${2:?usage: render-diff.sh <base-tree> <head-tree>}"
out="$(mktemp)"
trap 'rm -f "$out"' EXIT

status=0
for part in rendered argocd; do
  diff -ruN --label "base/$part" --label "head/$part" "$before/$part" "$after/$part" >>"$out" || status=$?
  [ "$status" -le 1 ] || exit "$status"
done

if [ ! -s "$out" ]; then
  echo "no change in the rendered manifests or in argocd/"
  exit 0
fi

echo "rendered manifests and argocd/ changed: $(grep -cE '^[-+]([^-+]|$)' "$out") lines"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo '## Rendered manifest diff'
    echo
    echo '```diff'
    head -c 900000 "$out"
    echo '```'
  } >>"$GITHUB_STEP_SUMMARY"
else
  cat "$out"
fi
