#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
vars_file="$repo_root/ansible/group_vars/all/versions.yml"
out_dir="$repo_root/rendered"

argocd_chart_version="$(grep -oE 'argocd_chart_version:\s*[0-9.]+' "$vars_file" | grep -oE '[0-9.]+')"
argocd_chart_sha256="$(grep -oE 'argocd_chart_sha256:\s*[0-9a-f]+' "$vars_file" | grep -oE '[0-9a-f]{64}')"
cilium_version="$(grep -oE 'cilium_version:\s*[0-9.]+' "$vars_file" | grep -oE '[0-9.]+')"
cilium_chart_sha256="$(grep -oE 'cilium_chart_sha256:\s*[0-9a-f]+' "$vars_file" | grep -oE '[0-9a-f]{64}')"

for name in argocd_chart_version argocd_chart_sha256 cilium_version cilium_chart_sha256; do
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

charts_dir="$out_dir/.charts"
mkdir -p "$charts_dir"
helm pull argo/argo-cd --version "$argocd_chart_version" --destination "$charts_dir" >/dev/null
helm pull cilium/cilium --version "$cilium_version" --destination "$charts_dir" >/dev/null
test "$(sha256sum "$charts_dir/argo-cd-$argocd_chart_version.tgz" | cut -d' ' -f1)" = "$argocd_chart_sha256" || {
  echo "argo-cd-$argocd_chart_version.tgz does not match argocd_chart_sha256 in $vars_file; review the chart and update the digest" >&2
  exit 1
}
test "$(sha256sum "$charts_dir/cilium-$cilium_version.tgz" | cut -d' ' -f1)" = "$cilium_chart_sha256" || {
  echo "cilium-$cilium_version.tgz does not match cilium_chart_sha256 in $vars_file; review the chart and update the digest" >&2
  exit 1
}

helm template cert-manager "$repo_root/argocd/apps/operators/cert-manager" \
  --namespace cert-manager \
  --include-crds >"$out_dir/cert-manager.yaml"

helm template argocd "$charts_dir/argo-cd-$argocd_chart_version.tgz" \
  --namespace argocd \
  --values "$repo_root/ansible/roles/argocd/files/values.yaml" \
  --include-crds >"$out_dir/argocd.yaml"

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

helm template oauth2-proxy "$repo_root/argocd/apps/platform/oauth2-proxy" \
  --namespace oauth2-proxy >"$out_dir/oauth2-proxy.yaml"

helm template dashy "$repo_root/argocd/apps/platform/dashy" \
  --namespace dashy >"$out_dir/dashy.yaml"

helm template portainer "$repo_root/argocd/apps/platform/portainer" \
  --namespace portainer >"$out_dir/portainer.yaml"

helm template blog-delivery "$repo_root/argocd/apps/satellites/blog/delivery" \
  --values "$repo_root/argocd/apps/satellites/blog/delivery/values.yaml" \
  --namespace blog-delivery >"$out_dir/blog-delivery.yaml"

helm template satellites-launcher "$repo_root/argocd/apps/satellites/launcher" \
  --namespace argocd >"$out_dir/satellites-launcher.yaml"

helm template satellites-delivery "$repo_root/argocd/apps/satellites/delivery" \
  --namespace argocd >"$out_dir/satellites-delivery.yaml"

helm template storage "$repo_root/argocd/apps/platform/storage" \
  --namespace kube-system >"$out_dir/storage.yaml"

helm template kargo "$repo_root/argocd/apps/platform/kargo" \
  --namespace kargo \
  --values "$repo_root/argocd/apps/platform/kargo/values.yaml" \
  --api-versions monitoring.coreos.com/v1 \
  --include-crds >"$out_dir/kargo.yaml"

helm template ingress "$repo_root/argocd/apps/platform/ingress" \
  --namespace ingress \
  --api-versions monitoring.coreos.com/v1 \
  --include-crds >"$out_dir/ingress.yaml"

cp "$repo_root/ansible/roles/cilium/templates/values.yaml.j2" "$out_dir/.cilium-values.yaml"
helm template cilium "$charts_dir/cilium-$cilium_version.tgz" \
  --namespace kube-system \
  --values "$out_dir/.cilium-values.yaml" \
  --include-crds >"$out_dir/cilium.yaml"
rm "$out_dir/.cilium-values.yaml"
rm -rf "$charts_dir"

echo "rendered $(find "$out_dir" -name '*.yaml' | wc -l | tr -d ' ') charts into $out_dir"
