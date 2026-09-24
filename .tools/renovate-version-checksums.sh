#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="hl-infra/helm:renovate"

docker build --target helm -t "$image" "$repo_root/.tools/docker"
docker run --rm -v "$repo_root":/repo -w /repo --entrypoint bash \
  "$image" .tools/update-version-checksums.sh --write
