#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

sops_file=".sops.yaml"
key_re='^age1[a-z0-9]+$'
label_re='^[a-z][a-z0-9-]*$'

usage() {
  cat >&2 <<'EOF'
usage: sops-recipients.sh list
       sops-recipients.sh sync-node [label]
       sops-recipients.sh add <label> <public key>
       sops-recipients.sh update <label> <public key>
       sops-recipients.sh remove <label>
EOF
  exit 2
}

has_label() {
  grep -qE "# $1\$" "$sops_file"
}

current_key_for_label() {
  grep -E "# $1\$" "$sops_file" | sed -E 's/^\s*- (age1[a-z0-9]+).*/\1/'
}

require_valid_label() {
  [[ "$1" =~ $label_re ]] || {
    echo "invalid label: $1 (lowercase letters, digits and dashes, starting with a letter)" >&2
    exit 1
  }
}

require_valid_key() {
  [[ "$1" =~ $key_re ]] || {
    echo "invalid age public key: $1" >&2
    exit 1
  }
}

add_or_update() {
  local label="$1" key="$2"
  if has_label "$label"; then
    local current
    current="$(current_key_for_label "$label")"
    if [ "$current" = "$key" ]; then
      echo "${label} already up to date: ${key}"
    else
      sed -i.bak -E "s@^(\s*- )age1[a-z0-9]+(\s*# ${label})\$@\1${key}\2@" "$sops_file"
      rm -f "${sops_file}.bak"
      echo "${label}: ${current} -> ${key}"
    fi
  else
    awk -v new="  - ${key} # ${label}" '
      { print }
      /^keys:/ && !done { print new; done=1 }
    ' "$sops_file" >"${sops_file}.tmp"
    mv "${sops_file}.tmp" "$sops_file"
    echo "added ${label}: ${key}"
  fi
}

cmd="${1:-}"
[ -n "$cmd" ] || usage
shift

case "$cmd" in
list)
  grep -E '^\s*- age1' "$sops_file" | sed -E 's/^\s*- (age1[a-z0-9]+)\s*#\s*(.*)$/\2: \1/' || true
  ;;

sync-node)
  label="${1:-node}"
  require_valid_label "$label"
  node_public_key="$(
    kubectl --kubeconfig ansible/kubeconfig -n sops get secret sops-age-key-file \
      -o jsonpath='{.data.keys\.txt}' \
      | base64 -d \
      | grep '^# public key:' \
      | tail -n1 \
      | sed 's/^# public key: //'
  )"
  require_valid_key "$node_public_key"
  add_or_update "$label" "$node_public_key"
  ;;

add)
  label="${1:?label required}"
  key="${2:?public key required}"
  require_valid_label "$label"
  require_valid_key "$key"
  if has_label "$label"; then
    echo "label $label already exists; use update or remove first" >&2
    exit 1
  fi
  if grep -qF "$key" "$sops_file"; then
    echo "that public key is already in .sops.yaml" >&2
    exit 1
  fi
  add_or_update "$label" "$key"
  ;;

update)
  label="${1:?label required}"
  key="${2:?public key required}"
  require_valid_key "$key"
  if ! has_label "$label"; then
    echo "no recipient labeled $label" >&2
    exit 1
  fi
  add_or_update "$label" "$key"
  ;;

remove)
  label="${1:?label required}"
  if ! has_label "$label"; then
    echo "no recipient labeled $label" >&2
    exit 1
  fi
  sed -i.bak -E "/# ${label}\$/d" "$sops_file"
  rm -f "${sops_file}.bak"
  echo "removed ${label}"
  ;;

*)
  usage
  ;;
esac
