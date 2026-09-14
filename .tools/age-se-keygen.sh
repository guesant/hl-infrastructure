#!/usr/bin/env bash
set -euo pipefail

command -v age-plugin-se >/dev/null 2>&1 || {
  echo "age-plugin-se not found in PATH; run: brew install age age-plugin-se" >&2
  exit 1
}

force=false
if [ "${1:-}" = "--force" ]; then
  force=true
fi

identity_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hl-infrastructure/sops"
identity_file="$identity_dir/operator-se.txt"

if [ -f "$identity_file" ] && [ "$force" = false ]; then
  echo "$identity_file already exists; pass --force to overwrite it" >&2
  exit 1
fi

umask 077
mkdir -p "$identity_dir"
age-plugin-se keygen --access-control=any-biometry-or-passcode -o "$identity_file" 2>&1 \
  | grep '^# public key:'

echo "identity written to $identity_file; back up its contents in Bitwarden as a secure note"
