#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

usage() {
  cat >&2 <<'EOF'
usage: satellite-delivery-add.sh <nome> <repo-da-imagem> <application-filha> <caminho-do-values>

  nome                nome do satélite, matches ^[a-z][a-z0-9-]*$; o projeto do
                       Kargo nasce como <nome>-delivery
  repo-da-imagem      repositório da imagem publicada, e.g. ghcr.io/guesant/nome
  application-filha   nome da Application do Argo que a promoção atualiza
  caminho-do-values   caminho do values Helm que recebe a tag, e.g.
                       application.deployment.image.tag
EOF
  exit 2
}

[ "$#" -ge 4 ] || usage

name="$1"
image_repo="$2"
child_app="$3"
values_path="$4"

if [[ ! "$name" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "nome must match ^[a-z][a-z0-9-]*\$, got: $name" >&2
  exit 2
fi

delivery_ns="${name}-delivery"
chart_dir="argocd/apps/satellites/$name/delivery"
app_file="argocd/applications/satellites/$name/delivery.yaml"

if [ -e "$chart_dir" ] || [ -e "$app_file" ]; then
  echo "$chart_dir or $app_file already exists; edit directly instead" >&2
  exit 1
fi

mkdir -p "$chart_dir/templates"

cat >"$chart_dir/Chart.yaml" <<EOF
apiVersion: v2
name: $delivery_ns
description: Kargo project that promotes the $name image into the Argo CD Application
version: 0.1.0
EOF

cat >"$chart_dir/values.yaml" <<EOF
imageTagValue: main@\${{ imageFrom("$image_repo").Digest }}
EOF

cat >"$chart_dir/templates/project.yaml" <<EOF
apiVersion: kargo.akuity.io/v1alpha1
kind: Project
metadata:
  name: $delivery_ns
  annotations:
    argocd.argoproj.io/sync-wave: "0"
EOF

cat >"$chart_dir/templates/project-config.yaml" <<EOF
apiVersion: kargo.akuity.io/v1alpha1
kind: ProjectConfig
metadata:
  name: $delivery_ns
  namespace: $delivery_ns
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  promotionPolicies:
    - stage: prod
      autoPromotionEnabled: true
EOF

cat >"$chart_dir/templates/warehouse.yaml" <<EOF
apiVersion: kargo.akuity.io/v1alpha1
kind: Warehouse
metadata:
  name: $name
  namespace: $delivery_ns
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  interval: 2m0s
  freightCreationPolicy: Automatic
  subscriptions:
    - image:
        repoURL: $image_repo
        imageSelectionStrategy: Digest
        constraint: main
        strictSemvers: true
        discoveryLimit: 5
EOF

cat >"$chart_dir/templates/stage.yaml" <<EOF
apiVersion: kargo.akuity.io/v1alpha1
kind: Stage
metadata:
  name: prod
  namespace: $delivery_ns
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  requestedFreight:
    - origin:
        kind: Warehouse
        name: $name
      sources:
        direct: true
  promotionTemplate:
    spec:
      steps:
        - uses: argocd-update
          config:
            apps:
              - name: $child_app
                namespace: argocd
                sources:
                  - repoURL: https://github.com/guesant/hl-infrastructure.git
                    helm:
                      images:
                        - key: $values_path
                          value: {{ .Values.imageTagValue | quote }}
EOF

mkdir -p "$(dirname "$app_file")"
cat >"$app_file" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $delivery_ns
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  project: satellites
  source:
    repoURL: https://github.com/guesant/hl-infrastructure.git
    targetRevision: main
    path: $chart_dir
  destination:
    server: https://kubernetes.default.svc
    namespace: $delivery_ns
  syncPolicy:
    managedNamespaceMetadata:
      labels:
        kargo.akuity.io/project: "true"
        pod-security.kubernetes.io/enforce: restricted
        pod-security.kubernetes.io/warn: restricted
        pod-security.kubernetes.io/audit: restricted
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
      - FailOnSharedResource=true
      - PruneLast=true
      - PrunePropagationPolicy=foreground
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF

echo "wrote $chart_dir/ and $app_file" >&2
echo >&2
echo "two hand-reviewed edits still needed:" >&2
echo >&2
echo "1. add this annotation to the $child_app Application's metadata.annotations:" >&2
echo "   kargo.akuity.io/authorized-stage: ${delivery_ns}:prod" >&2
echo >&2
echo "2. add an ignoreDifferences entry to argocd/root/application.yaml, alongside the existing ones:" >&2
cat >&2 <<EOF
   - group: argoproj.io
     kind: Application
     name: $child_app
     namespace: argocd
     jsonPointers:
       - /spec/source/helm/parameters
EOF
echo >&2
echo "then: just render-charts (confirm the chart renders), git add, commit, push, just status" >&2
