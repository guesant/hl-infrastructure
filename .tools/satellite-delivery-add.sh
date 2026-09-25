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

values_file="argocd/apps/satellites/delivery/values.yaml"
image_tag_value="main@\${{ imageFrom(\"$image_repo\").Digest }}"

if yq -e ".satellites[] | select(.name == \"$name\")" "$values_file" >/dev/null 2>&1; then
  echo "$name already exists in $values_file; edit it directly or pick a different name" >&2
  exit 1
fi

new_entry="$(jq -n \
  --arg name "$name" \
  --arg imageRepo "$image_repo" \
  --arg childApp "$child_app" \
  --arg valuesPath "$values_path" \
  --arg imageTagValue "$image_tag_value" \
  '{
    name: $name,
    childApp: $childApp,
    images: [{
      imageRepo: $imageRepo,
      valuesPath: $valuesPath,
      imageTagValue: $imageTagValue
    }]
  }')"

yq -i ".satellites += [$new_entry]" "$values_file"

delivery_ns="${name}-delivery"

echo "added $name to $values_file" >&2
echo >&2
echo "one hand-reviewed edit still needed:" >&2
echo >&2
echo "1. add this annotation to the $child_app Application's metadata.annotations:" >&2
echo "   kargo.akuity.io/authorized-stage: ${delivery_ns}:prod" >&2
echo >&2
echo "then: just infra-render-charts (confirm the chart renders), git add, commit, push, just status" >&2
