#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

secrets_file="tofu/state.sops.env"
mode="${1:-generate}"

usage() {
  echo "usage: $0 [--rotate | --finish-rotation]" >&2
  exit 2
}

refuse() {
  echo "$1" >&2
  exit 1
}

command -v openssl >/dev/null 2>&1 || refuse "openssl not found in PATH"

new_passphrase() {
  local value
  value="$(openssl rand -base64 48 | tr -d '\n')"
  [ "${#value}" -ge 32 ] || refuse "openssl returned a passphrase shorter than 32 characters"
  printf '%s' "$value"
}

current_passphrase() {
  sops --config .sops.yaml decrypt --extract '["TF_VAR_state_passphrase"]' "$secrets_file"
}

write_encrypted() {
  local tmp
  tmp="$(mktemp "${secrets_file}.XXXXXX")"
  trap 'rm -f "$tmp"' EXIT
  sops --config .sops.yaml encrypt --filename-override "$secrets_file" \
    --input-type dotenv --output-type dotenv /dev/stdin >"$tmp"
  mv "$tmp" "$secrets_file"
  trap - EXIT
}

rotation_in_progress() {
  [ -f "$secrets_file" ] && grep -q '^TF_VAR_state_passphrase_previous=' "$secrets_file"
}

case "$mode" in
  generate)
    existing_states="$(find tofu -type f -name terraform.tfstate)"
    if [ -n "$existing_states" ]; then
      refuse "refusing to replace the passphrase: these states are already encrypted with it and would become unreadable:
$existing_states
use --rotate instead"
    fi
    passphrase="$(new_passphrase)"
    printf 'TF_VAR_state_passphrase=%s\n' "$passphrase" | write_encrypted
    echo "$secrets_file now holds a new random passphrase; review the diff and commit"
    ;;
  --rotate)
    rotation_in_progress && refuse "a rotation is already in progress; apply every module, then run --finish-rotation"
    current="$(current_passphrase)"
    [[ "$current" == REPLACE_WITH_* ]] && refuse "there is no real passphrase to rotate yet; run without arguments"
    passphrase="$(new_passphrase)"
    printf 'TF_VAR_state_passphrase=%s\nTF_VAR_state_passphrase_previous=%s\n' "$passphrase" "$current" | write_encrypted
    echo "$secrets_file now holds a new passphrase and the old one as TF_VAR_state_passphrase_previous"
    echo "next: add the fallback to every module, run just tofu-apply <module> for each, then --finish-rotation"
    ;;
  --finish-rotation)
    rotation_in_progress || refuse "no rotation in progress"
    current="$(current_passphrase)"
    printf 'TF_VAR_state_passphrase=%s\n' "$current" | write_encrypted
    echo "$secrets_file no longer holds the previous passphrase; remove the fallback from every module and commit"
    ;;
  *)
    usage
    ;;
esac
