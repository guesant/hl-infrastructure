#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

backup_public_key="${1:-}"

tools_hash="$(shasum -a 256 .tools/docker/Dockerfile | cut -c1-12)"

node_public_key="$(
  kubectl --kubeconfig ansible/kubeconfig -n sops get secret sops-age-key-file \
    -o jsonpath='{.data.keys\.txt}' \
    | base64 -d \
    | docker run --rm -i "hl-infra/age:${tools_hash}" age-keygen -y
)"

sed -i.bak "s/REPLACE_WITH_NODE_PUBLIC_KEY/${node_public_key}/" .sops.yaml
rm -f .sops.yaml.bak

if [ -n "$backup_public_key" ]; then
  sed -i.bak "s/REPLACE_WITH_BACKUP_PUBLIC_KEY/${backup_public_key}/" .sops.yaml
  rm -f .sops.yaml.bak
else
  echo "No backup public key given; .sops.yaml still has REPLACE_WITH_BACKUP_PUBLIC_KEY." >&2
  echo "Run: just age-keygen, then: just sops-recipients <public key from its output>" >&2
fi

echo "Node public key: ${node_public_key}"
echo "Review the diff in .sops.yaml before committing."
