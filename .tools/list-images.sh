#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

[ -d rendered ] || { echo "rendered/ is missing; render the charts first" >&2; exit 2; }

{
  grep -rhoE '^[[:space:]]*(-[[:space:]]*)?(image|imageName):[[:space:]]*"?[^"{}[:space:]]+' rendered argocd \
    | sed -E 's/^[[:space:]]*(-[[:space:]]*)?(image|imageName):[[:space:]]*"?//'

  while IFS= read -r values; do
    awk '
      /^[[:space:]]*image:[[:space:]]*$/ { in_image = 1; repo = ""; tag = ""; digest = ""; next }
      in_image && /^[[:space:]]*repository:/ { repo = $2 }
      in_image && /^[[:space:]]*tag:/ { tag = $2 }
      in_image && /^[[:space:]]*digest:/ { digest = $2 }
      in_image && repo != "" && tag != "" && (digest != "" || /^[[:space:]]*[a-z]+:[[:space:]]*$/) {
        print repo ":" tag (digest != "" ? "@" digest : ""); in_image = 0
      }
    ' "$values" | tr -d '"'
  done < <(find argocd/apps -name 'values*.yaml' -not -path '*/charts/*')

  grep -rhE -A1 'name: application.deployment.image.tag' argocd/applications \
    | grep -oE 'value: [^[:space:]]+' | awk '{print "ghcr.io/guesant/blog:" $2}'
} | grep -E '^[a-z0-9.-]+(/[a-z0-9._-]+)+(:[A-Za-z0-9._-]+)?(@sha256:[0-9a-f]{64})?$' | grep -E '[:@]' | sort -u
