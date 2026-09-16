#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
vars_file="$repo_root/ansible/group_vars/all/versions.yml"
out_dir="$repo_root/rendered"

argocd_chart_version="$(grep -oE 'argocd_chart_version:\s*[0-9.]+' "$vars_file" | grep -oE '[0-9.]+')"
cilium_version="$(grep -oE 'cilium_version:\s*[0-9.]+' "$vars_file" | grep -oE '[0-9.]+')"

for name in argocd_chart_version cilium_version; do
  test -n "${!name}" || {
    echo "could not extract $name from $vars_file" >&2
    exit 1
  }
done

rm -rf "$out_dir"
mkdir -p "$out_dir"

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo add cilium https://helm.cilium.io/ >/dev/null
helm repo update >/dev/null

helm template cert-manager "$repo_root/argocd/apps/operators/cert-manager" \
  --namespace cert-manager \
  --include-crds >"$out_dir/cert-manager.yaml"

helm template argocd argo/argo-cd \
  --version "$argocd_chart_version" \
  --namespace argocd \
  --set controller.metrics.enabled=true \
  --set server.metrics.enabled=true \
  --set notifications.metrics.enabled=true \
  --include-crds >"$out_dir/argocd.yaml"

helm template argocd-image-updater "$repo_root/argocd/apps/platform/argocd-image-updater" \
  --namespace argocd \
  --include-crds >"$out_dir/argocd-image-updater.yaml"

helm template cnpg "$repo_root/argocd/apps/operators/cnpg" \
  --namespace cnpg-system \
  --include-crds >"$out_dir/cnpg.yaml"

helm template sops-secrets-operator "$repo_root/argocd/apps/operators/sops-secrets-operator" \
  --namespace sops \
  --values "$repo_root/argocd/apps/operators/sops-secrets-operator/values.yaml" \
  --include-crds >"$out_dir/sops-secrets-operator.yaml"

helm template monitoring "$repo_root/argocd/apps/platform/monitoring" \
  --namespace monitoring \
  --include-crds >"$out_dir/monitoring.yaml"

helm template keycloak-operator "$repo_root/argocd/apps/operators/keycloak-operator" \
  --namespace keycloak \
  --include-crds >"$out_dir/keycloak-operator.yaml"

helm template keycloak-postgres "$repo_root/argocd/apps/data/keycloak-postgres" \
  --namespace keycloak >"$out_dir/keycloak-postgres.yaml"

helm template keycloak "$repo_root/argocd/apps/platform/keycloak" \
  --namespace keycloak >"$out_dir/keycloak.yaml"

helm template reloader "$repo_root/argocd/apps/platform/reloader" \
  --namespace reloader \
  --api-versions monitoring.coreos.com/v1 >"$out_dir/reloader.yaml"

helm template sso "$repo_root/argocd/apps/platform/sso" \
  --namespace argocd >"$out_dir/sso.yaml"

helm template dashy "$repo_root/argocd/apps/platform/dashy" \
  --namespace dashy >"$out_dir/dashy.yaml"

helm template portainer "$repo_root/argocd/apps/platform/portainer" \
  --namespace portainer >"$out_dir/portainer.yaml"

helm template ingress "$repo_root/argocd/apps/platform/ingress" \
  --namespace ingress \
  --api-versions monitoring.coreos.com/v1 \
  --include-crds >"$out_dir/ingress.yaml"

sed 's/{{ ansible_host }}/10.0.0.1/' "$repo_root/ansible/roles/cilium/templates/values.yaml.j2" >"$out_dir/.cilium-values.yaml"
helm template cilium cilium/cilium \
  --version "$cilium_version" \
  --namespace kube-system \
  --values "$out_dir/.cilium-values.yaml" \
  --include-crds >"$out_dir/cilium.yaml"
rm "$out_dir/.cilium-values.yaml"

echo "rendered $(find "$out_dir" -name '*.yaml' | wc -l | tr -d ' ') charts into $out_dir"
