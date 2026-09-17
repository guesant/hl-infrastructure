#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mirror="$repo_root/.cache/tofu/mirror"
platforms=(linux_arm64 linux_amd64)

version="$(grep -hoE 'version = "[0-9.]+"' tofu/keycloak-master/versions.tf | grep -oE '[0-9.]+' | tail -1)"
test -n "$version" || {
  echo "could not read the keycloak provider version from tofu/keycloak-master/versions.tf" >&2
  exit 1
}

target="$mirror/registry.opentofu.org/keycloak/keycloak"
base="https://github.com/keycloak/terraform-provider-keycloak/releases/download/v$version"
mkdir -p "$target"
cd "$target"

if [ ! -f SHA256SUMS ]; then
  curl -fsSLo SHA256SUMS "$base/terraform-provider-keycloak_${version}_SHA256SUMS"
fi

for platform in "${platforms[@]}"; do
  zip="terraform-provider-keycloak_${version}_${platform}.zip"
  if [ ! -f "$zip" ]; then
    curl -fsSLo "$zip" "$base/$zip"
  fi
  grep -E " $zip$" SHA256SUMS | sha256sum -c --quiet - || {
    echo "$zip does not match the published SHA256SUMS; removing it" >&2
    rm -f "$zip"
    exit 1
  }
done

echo "keycloak/keycloak $version mirrored for ${platforms[*]} in .cache/tofu/mirror"
