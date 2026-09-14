#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

sops_file=".sops.yaml"
print_only=false
operator_public_key=""
dr_public_key=""

while [ "$#" -gt 0 ]; do
  case "$1" in
  --print)
    print_only=true
    shift
    ;;
  --operator)
    operator_public_key="$2"
    shift 2
    ;;
  --dr)
    dr_public_key="$2"
    shift 2
    ;;
  *)
    echo "usage: $0 [--print] [--operator <public key>] [--dr <public key>]" >&2
    exit 2
    ;;
  esac
done

x25519_re='^age1[a-z0-9]{58}$'
se_re='^age1se1[a-z0-9]+$'

if [ -n "$operator_public_key" ] && ! [[ "$operator_public_key" =~ $se_re ]]; then
  echo "the operator key must be an age-plugin-se recipient (age1se1...), got: $operator_public_key" >&2
  exit 1
fi

if [ -n "$dr_public_key" ] && ! [[ "$dr_public_key" =~ $x25519_re ]]; then
  echo "the DR key must be a plain age recipient (age1...), got: $dr_public_key" >&2
  exit 1
fi

node_public_key="$(
  kubectl --kubeconfig ansible/kubeconfig -n sops get secret sops-age-key-file \
    -o jsonpath='{.data.keys\.txt}' \
    | base64 -d \
    | grep '^# public key:' \
    | tail -n1 \
    | sed 's/^# public key: //'
)"

if ! [[ "$node_public_key" =~ $x25519_re ]]; then
  echo "could not read a valid node public key from the cluster" >&2
  exit 1
fi

if [ "$print_only" = true ]; then
  operator_current="$(sed -nE 's/^\s*- &operator (.+)$/\1/p' "$sops_file")"
  dr_current="$(sed -nE 's/^\s*- &dr (.+)$/\1/p' "$sops_file")"
  echo "node: ${node_public_key}"
  echo "operator: ${operator_current}"
  echo "dr: ${dr_current}"
  exit 0
fi

changed=false

update_anchor() {
  local anchor="$1" value="$2"
  local current
  current="$(sed -nE "s/^\s*- &${anchor} (.+)\$/\1/p" "$sops_file")"
  if [ "$current" = "$value" ]; then
    return
  fi
  sed -i.bak -E "s/^(\s*- &${anchor} ).+\$/\1${value}/" "$sops_file"
  rm -f "${sops_file}.bak"
  changed=true
  echo "${anchor}: ${current} -> ${value}"
}

update_anchor node "$node_public_key"

if [ -n "$operator_public_key" ]; then
  update_anchor operator "$operator_public_key"
fi

if [ -n "$dr_public_key" ]; then
  update_anchor dr "$dr_public_key"
fi

if [ "$changed" = false ]; then
  echo ".sops.yaml already lists the current recipients"
fi

if grep -q 'REPLACE_WITH_' "$sops_file"; then
  echo "REPLACE_WITH_ placeholders remain in .sops.yaml; pass --operator and --dr to fill them" >&2
fi
