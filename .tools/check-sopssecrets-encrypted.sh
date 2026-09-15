#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

status=0
expected_recipients="$(yq -o=json -I=0 '.keys | sort' .sops.yaml)"

check_encrypted() {
  local file="$1" filestatus_output
  if ! filestatus_output="$(sops filestatus "$file" 2>&1)"; then
    echo "$file: sops could not read this file: $filestatus_output" >&2
    return 1
  fi
  if ! echo "$filestatus_output" | grep -q '"encrypted":true'; then
    echo "$file: not encrypted" >&2
    return 1
  fi
}

check_recipients() {
  local file="$1" file_recipients="$2"
  if [ "$file_recipients" != "$expected_recipients" ]; then
    echo "$file: recipients ($file_recipients) do not match .sops.yaml ($expected_recipients)" >&2
    return 1
  fi
}

while IFS= read -r file; do
  check_encrypted "$file" || {
    status=1
    continue
  }
  unencrypted="$(yq '.spec.secretTemplates[].stringData[]' "$file" | grep -vc '^ENC\[' || true)"
  if [ "$unencrypted" -gt 0 ]; then
    echo "$file: has a plaintext value under spec.secretTemplates[].stringData" >&2
    status=1
  fi
  check_recipients "$file" "$(yq -o=json -I=0 '[.sops.age[].recipient] | sort' "$file")" || status=1
done < <(find argocd -type f -name '*.sops-secret.yaml')

while IFS= read -r file; do
  check_encrypted "$file" || {
    status=1
    continue
  }
  unencrypted="$(grep -vE '^(sops_|#|$)' "$file" | grep -vcE '^[A-Za-z_][A-Za-z0-9_]*=ENC\[' || true)"
  if [ "$unencrypted" -gt 0 ]; then
    echo "$file: has a plaintext value" >&2
    status=1
  fi
  check_recipients "$file" "$(grep -E '^sops_age__list_[0-9]+__map_recipient=' "$file" | cut -d= -f2- | jq -R . | jq -sc sort)" || status=1
done < <(find tofu ansible/recovery -type f -name '*.sops.env' 2>/dev/null)

while IFS= read -r file; do
  check_encrypted "$file" || {
    status=1
    continue
  }
  unencrypted="$(yq 'del(.sops) | .. | select(kind == "scalar")' "$file" | grep -vc '^ENC\[' || true)"
  if [ "$unencrypted" -gt 0 ]; then
    echo "$file: has a plaintext value" >&2
    status=1
  fi
  check_recipients "$file" "$(yq -o=json -I=0 '[.sops.age[].recipient] | sort' "$file")" || status=1
done < <(find ansible/group_vars -type f -name '*.sops.yaml' 2>/dev/null)

if [ "$status" -eq 0 ]; then
  echo "every SOPS file is encrypted with the current recipients"
fi
exit "$status"
