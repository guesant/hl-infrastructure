#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

target=node/k3s-token.sops.env
inventory=ansible/inventory.ini

command -v sops >/dev/null 2>&1 || { echo "sops not found in PATH" >&2; exit 1; }
[ -f "$inventory" ] || { echo "$inventory is missing" >&2; exit 1; }

host="$(grep -oE 'ansible_host=[^[:space:]]+' "$inventory" | head -1 | cut -d= -f2)"
user="$(grep -oE 'ansible_user=[^[:space:]]+' "$inventory" | head -1 | cut -d= -f2)"
key="$(grep -oE 'ansible_ssh_private_key_file=[^[:space:]]+' "$inventory" | head -1 | cut -d= -f2)"
key="${key/#\~/$HOME}"
[ -n "$host" ] && [ -n "$user" ] || { echo "could not read ansible_host and ansible_user from $inventory" >&2; exit 1; }

ssh_args=(-o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=ansible/known_hosts)
[ -n "$key" ] && ssh_args+=(-i "$key")

token="$(ssh "${ssh_args[@]}" "$user@$host" cat /var/lib/rancher/k3s/server/token)"
[[ "$token" =~ ^K10[0-9a-f]+::server:[0-9a-f]+$|^[0-9a-f]{32,}$ ]] || { echo "the node returned something that does not look like a k3s token" >&2; exit 1; }

mkdir -p "$(dirname "$target")"
printf 'K3S_TOKEN=%s\n' "$token" \
  | sops encrypt --filename-override "$target" --input-type dotenv --output-type dotenv /dev/stdin >"$target.tmp"
mv "$target.tmp" "$target"
unset token

echo "$target now holds the node's current k3s token, encrypted for the .sops.yaml recipients"
