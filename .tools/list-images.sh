#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

[ -d .build/rendered ] || { echo ".build/rendered/ is missing; render the charts first" >&2; exit 2; }

{
  grep -rhoE '^[[:space:]]*(-[[:space:]]*)?(image|imageName):[[:space:]]*"?[^"{}[:space:]]+' .build/rendered argocd \
    | sed -E 's/^[[:space:]]*(-[[:space:]]*)?(image|imageName):[[:space:]]*"?//'

  while IFS= read -r values; do
    awk '
      /^[[:space:]]*image:[[:space:]]*$/ { in_image = 1; registry = ""; repo = ""; tag = ""; digest = ""; next }
      in_image && /^[[:space:]]*registry:/ { registry = $2 "/" }
      in_image && /^[[:space:]]*repository:/ { repo = $2 }
      in_image && /^[[:space:]]*tag:/ { tag = $2 }
      in_image && /^[[:space:]]*digest:/ { digest = $2 }
      in_image && repo != "" && tag != "" && (digest != "" || /^[[:space:]]*[a-z]+:[[:space:]]*$/) {
        print registry repo ":" tag (digest != "" ? "@" digest : ""); in_image = 0
      }
    ' "$values" | tr -d '"'
  done < <(find argocd/apps -name 'values*.yaml' -not -path '*/charts/*')

} | grep -E '^[a-z0-9.-]+(/[a-z0-9._-]+)+(:[A-Za-z0-9._-]+)?(@sha256:[0-9a-f]{64})?$' | grep -E '[:@]' | sort -u
