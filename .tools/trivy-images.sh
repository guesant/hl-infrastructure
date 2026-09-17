#!/usr/bin/env bash
set -euo pipefail

images_file="${1:?usage: trivy-images.sh <images-file> <sbom-dir>}"
sbom_dir="${2:?usage: trivy-images.sh <images-file> <sbom-dir>}"
trivy_image="${TRIVY_IMAGE:-hl-infra/trivy}"
platform="${TRIVY_PLATFORM:-linux/arm64}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
mkdir -p "$sbom_dir"

[ -s "$images_file" ] || { echo "$images_file is empty; nothing to scan" >&2; exit 2; }

run_trivy() {
  docker run --rm -v "$repo_root":/repo -w /repo -v trivy-cache:/root/.cache/trivy "$trivy_image" "$@"
}

# A FATAL trivy error (a truncated layer left behind by an interrupted
# cross-platform pull into the shared cache volume) is an infra flake, not
# a scan result; wipe the cache and retry once, so exit code 1 always means
# a real finding, never a corrupted blob.
run_trivy_retrying() {
  local output rc
  output="$(run_trivy "$@" 2>&1)" && { printf '%s\n' "$output"; return 0; }
  rc=$?
  printf '%s\n' "$output"
  if grep -qw FATAL <<<"$output"; then
    echo "trivy hit a fatal error, likely a truncated layer in the shared cache; clearing it and retrying once" >&2
    docker volume rm -f trivy-cache >/dev/null 2>&1 || true
    run_trivy "$@"
    return $?
  fi
  return "$rc"
}

status=0
while IFS= read -r image; do
  [ -n "$image" ] || continue
  name="$(tr '/:@' '___' <<<"$image")"
  echo "== $image"
  run_trivy_retrying image --quiet --platform "$platform" --format cyclonedx --output "$sbom_dir/$name.cdx.json" "$image"
  if ! run_trivy_retrying image --quiet --platform "$platform" --severity CRITICAL --ignore-unfixed --ignorefile .trivyignore.yaml --exit-code 1 "$image"; then
    status=1
  fi
done <"$images_file"

if [ "$status" -eq 0 ]; then
  echo "no deployed image has a fixable critical vulnerability outside .trivyignore.yaml"
fi
exit "$status"
