#!/usr/bin/env bash
set -euo pipefail

mode="${1:---check}"
test "$mode" = "--check" || test "$mode" = "--write" || {
  echo "usage: $0 [--check|--write]" >&2
  exit 2
}
test "$#" -le 1 || {
  echo "usage: $0 [--check|--write]" >&2
  exit 2
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
vars_file="$repo_root/ansible/group_vars/all/versions.yml"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

read_version() {
  awk -v key="$1:" '$1 == key { print $2; exit }' "$vars_file"
}

update_checksum() {
  local key="$1"
  local expected="$2"
  local current
  current="$(read_version "$key")"
  test -n "$current" || {
    echo "could not find $key in $vars_file" >&2
    exit 1
  }
  if [ "$current" = "$expected" ]; then
    return
  fi
  if [ "$mode" = "--check" ]; then
    echo "$key does not match the artifact selected by its version" >&2
    echo "  declared: $current" >&2
    echo "  expected: $expected" >&2
    mismatches=1
    return
  fi
  sed -i -E "s|^${key}: [^[:space:]]+|${key}: ${expected}|" "$vars_file"
  echo "updated $key"
}

k3s_version="$(read_version k3s_version)"
cilium_version="$(read_version cilium_version)"
argocd_chart_version="$(read_version argocd_chart_version)"
for name in k3s_version cilium_version argocd_chart_version; do
  test -n "${!name}" || {
    echo "could not find $name in $vars_file" >&2
    exit 1
  }
done

k3s_install_script_sha256="$({
  curl --fail --silent --show-error --location --retry 4 --retry-all-errors \
    "https://raw.githubusercontent.com/k3s-io/k3s/${k3s_version}/install.sh"
} | sha256sum | awk '{ print $1 }')"

helm repo add argo https://argoproj.github.io/argo-helm --force-update >/dev/null
helm repo add cilium https://helm.cilium.io/ --force-update >/dev/null
helm repo update >/dev/null
helm pull argo/argo-cd --version "$argocd_chart_version" --destination "$temp_dir"
helm pull cilium/cilium --version "$cilium_version" --destination "$temp_dir"

argocd_chart_sha256="$(sha256sum "$temp_dir/argo-cd-${argocd_chart_version}.tgz" | awk '{ print $1 }')"
cilium_chart_sha256="$(sha256sum "$temp_dir/cilium-${cilium_version}.tgz" | awk '{ print $1 }')"
mismatches=0
update_checksum k3s_install_script_sha256 "$k3s_install_script_sha256"
update_checksum cilium_chart_sha256 "$cilium_chart_sha256"
update_checksum argocd_chart_sha256 "$argocd_chart_sha256"

if [ "$mode" = "--check" ] && [ "$mismatches" -ne 0 ]; then
  exit 1
fi

if [ "$mode" = "--check" ]; then
  echo "version checksums match their artifacts"
else
  echo "version checksums updated"
fi
