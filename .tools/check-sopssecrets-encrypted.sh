#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

status=0
expected_recipients="$(yq -o=json '.keys | sort' .sops.yaml)"

while IFS= read -r file; do
  if ! filestatus_output="$(sops filestatus "$file" 2>&1)"; then
    echo "$file: sops could not read this file: $filestatus_output" >&2
    status=1
    continue
  fi
  if ! echo "$filestatus_output" | grep -q '"encrypted":true'; then
    echo "$file: not encrypted" >&2
    status=1
    continue
  fi

  unencrypted="$(yq '.spec.secretTemplates[].stringData[]' "$file" | grep -vc '^ENC\[' || true)"
  if [ "$unencrypted" -gt 0 ]; then
    echo "$file: has a plaintext value under spec.secretTemplates[].stringData" >&2
    status=1
  fi

  file_recipients="$(yq -o=json '[.sops.age[].recipient] | sort' "$file")"
  if [ "$file_recipients" != "$expected_recipients" ]; then
    echo "$file: recipients ($file_recipients) do not match .sops.yaml ($expected_recipients)" >&2
    status=1
  fi
done < <(find argocd -type f -name '*-sopssecret.yaml')

if [ "$status" -eq 0 ]; then
  echo "every SopsSecret is encrypted with the current recipients"
fi
exit "$status"
