#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
vars_file="$repo_root/ansible/group_vars/all/versions.yml"
out_dir="$repo_root/rendered"

argocd_chart_version="$(grep -oE 'argocd_chart_version:\s*[0-9.]+' "$vars_file" | grep -oE '[0-9.]+')"
argocd_image_updater_chart_version="$(grep -oE 'argocd_image_updater_chart_version:\s*[0-9.]+' "$vars_file" | grep -oE '[0-9.]+')"
sealed_secrets_chart_version="$(grep -oE 'sealed_secrets_chart_version:\s*[0-9.]+' "$vars_file" | grep -oE '[0-9.]+')"
cilium_version="$(grep -oE 'cilium_version:\s*[0-9.]+' "$vars_file" | grep -oE '[0-9.]+')"

for name in argocd_chart_version argocd_image_updater_chart_version sealed_secrets_chart_version cilium_version; do
  test -n "${!name}" || {
    echo "could not extract $name from $vars_file" >&2
    exit 1
  }
done

rm -rf "$out_dir"
mkdir -p "$out_dir"

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo add sealed-secrets https://bitnami.github.io/sealed-secrets >/dev/null
helm repo add cilium https://helm.cilium.io/ >/dev/null
helm repo update >/dev/null

helm template cert-manager "$repo_root/argocd/apps/cert-manager" \
  --namespace cert-manager \
  --include-crds >"$out_dir/cert-manager.yaml"

helm template argocd argo/argo-cd \
  --version "$argocd_chart_version" \
  --namespace argocd \
  --set controller.metrics.enabled=true \
  --set server.metrics.enabled=true \
  --set notifications.metrics.enabled=true \
  --include-crds >"$out_dir/argocd.yaml"

helm template argocd-image-updater argo/argocd-image-updater \
  --version "$argocd_image_updater_chart_version" \
  --namespace argocd \
  --include-crds >"$out_dir/argocd-image-updater.yaml"

helm template cnpg "$repo_root/argocd/apps/cnpg" \
  --namespace cnpg-system \
  --include-crds >"$out_dir/cnpg.yaml"

helm template barman-cloud "$repo_root/argocd/apps/cnpg-barman-plugin" \
  --namespace cnpg-system \
  --include-crds >"$out_dir/cnpg-barman-plugin.yaml"

helm template sealed-secrets-controller sealed-secrets/sealed-secrets \
  --version "$sealed_secrets_chart_version" \
  --namespace kube-system \
  --include-crds >"$out_dir/sealed-secrets.yaml"

sed 's/{{ ansible_host }}/10.0.0.1/' "$repo_root/ansible/roles/cilium/templates/values.yaml.j2" >"$out_dir/.cilium-values.yaml"
helm template cilium cilium/cilium \
  --version "$cilium_version" \
  --namespace kube-system \
  --values "$out_dir/.cilium-values.yaml" \
  --include-crds >"$out_dir/cilium.yaml"
rm "$out_dir/.cilium-values.yaml"

echo "rendered 7 charts into $out_dir"
