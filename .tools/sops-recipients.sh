#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

tools_hash="$(shasum -a 256 .tools/docker/Dockerfile | cut -c1-12)"

node_public_key="$(
  kubectl --kubeconfig ansible/kubeconfig -n sops get secret sops-age-key-file \
    -o jsonpath='{.data.keys\.txt}' \
    | base64 -d \
    | docker run --rm -i "hl-infra/age:${tools_hash}" age-keygen -y
)"

echo "Node public key: ${node_public_key}"
echo "Paste this into .sops.yaml in place of REPLACE_WITH_NODE_PUBLIC_KEY, keep the backup recipient as-is, review the diff, then commit."
