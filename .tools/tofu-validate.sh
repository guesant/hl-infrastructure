#!/usr/bin/env bash
set -euo pipefail

: "${TOFU_IMAGE:?TOFU_IMAGE must name the OpenTofu image}"

export TF_VAR_state_passphrase=validate-only-passphrase-never-used-for-real-state

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# IMPORTANT: validate a copy without terraform.tfstate; init reads the committed encrypted state even with -backend=false and fails on the fake passphrase.
for dir in tofu/*/; do
    name=$(basename "$dir")
    mkdir -p "$work/$name"
    find "$dir" -maxdepth 1 -type f \( -name '*.tf' -o -name '*.tfvars' -o -name '.terraform.lock.hcl' \) -exec cp {} "$work/$name/" \;
    docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -v "$work":/work -w /work -e TF_VAR_state_passphrase "$TOFU_IMAGE" -chdir="$name" init -backend=false -input=false
    docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -v "$work":/work -w /work -e TF_VAR_state_passphrase "$TOFU_IMAGE" -chdir="$name" validate
done
