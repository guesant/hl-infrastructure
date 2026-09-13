#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

while IFS= read -r chart_yaml; do
  helm lint "$(dirname "$chart_yaml")"
done < <(find argocd/apps -mindepth 1 -name Chart.yaml | sort)
