#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <module> [tofu arguments...]" >&2
  exit 2
fi

module="$1"
shift

if [[ ! "$module" =~ ^[a-z0-9-]+$ ]]; then
  echo "module name must match ^[a-z0-9-]+$, got: $module" >&2
  exit 2
fi

module_dir="tofu/$module"
state_secrets="tofu/state.sops.env"
module_secrets="$module_dir/$module.sops.env"

if [ ! -d "$module_dir" ]; then
  echo "$module_dir does not exist" >&2
  exit 2
fi

"$repo_root/.tools/tofu-mirror.sh" >/dev/null
mkdir -p "$repo_root/.cache/tofu"
cat >"$repo_root/.cache/tofu/tofurc" <<'RC'
provider_installation {
  filesystem_mirror {
    path    = "/repo/.cache/tofu/mirror"
    include = ["registry.opentofu.org/keycloak/*"]
  }
  direct {
    exclude = ["registry.opentofu.org/keycloak/*"]
  }
}
RC

if [ -z "${TOFU_IMAGE:-}" ]; then
  echo "TOFU_IMAGE is not set; run this through: just tofu $module" >&2
  exit 2
fi

reexec_with() {
  local marker="$1" secrets="$2"
  shift 2
  exec env "$marker=1" sops exec-env "$secrets" "$(printf '%q ' "$repo_root/.tools/tofu-run.sh" "$@")"
}

if [ -z "${TOFU_STATE_SECRETS_LOADED:-}" ]; then
  reexec_with TOFU_STATE_SECRETS_LOADED "$state_secrets" "$module" "$@"
fi

if [ -f "$module_secrets" ] && [ -z "${TOFU_MODULE_SECRETS_LOADED:-}" ]; then
  reexec_with TOFU_MODULE_SECRETS_LOADED "$module_secrets" "$module" "$@"
fi

if [ -z "${TF_VAR_state_passphrase:-}" ]; then
  echo "$state_secrets did not provide TF_VAR_state_passphrase" >&2
  exit 1
fi

names=()
for secrets in "$state_secrets" "$module_secrets"; do
  [ -f "$secrets" ] || continue
  while IFS= read -r name; do
    names+=("$name")
  done < <(grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' "$secrets" | grep -v '^sops_' | tr -d '=')
done

secrets_map="$module_dir/secrets.map"
if [ -f "$secrets_map" ]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ ! "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=([^#]+)#(.+)$ ]]; then
      echo "$secrets_map: malformed line, expected NAME=path/to/file.sops#[\"json\"][\"path\"]: $line" >&2
      exit 2
    fi
    name="${BASH_REMATCH[1]}"
    source_file="${BASH_REMATCH[2]}"
    source_path="${BASH_REMATCH[3]}"
    if [ ! -f "$source_file" ]; then
      echo "$secrets_map: $source_file does not exist" >&2
      exit 2
    fi
    if ! value="$(sops --decrypt --extract "$source_path" "$source_file")"; then
      echo "$secrets_map: could not read $source_path from $source_file" >&2
      exit 1
    fi
    export "$name=$value"
    names+=("$name")
  done <"$secrets_map"
fi

placeholders=()
env_args=()
for name in "${names[@]}"; do
  if [[ "${!name:-}" == REPLACE_WITH_* ]]; then
    placeholders+=("$name")
  fi
  env_args+=(-e "$name")
done

if [ "${#placeholders[@]}" -gt 0 ]; then
  echo "refusing to run: these secrets still hold a placeholder: ${placeholders[*]}" >&2
  echo "fill them with just sops-edit (or just tofu-state-passphrase), and run just placeholders for the full list" >&2
  exit 1
fi

case "${1:-} ${2:-}" in
  "plan "* | "show "* | "output "* | "validate "* | "providers "* | "state list" | "state show")
    if [ -n "${CLOUDFLARE_API_TOKEN_READ:-}" ]; then
      export CLOUDFLARE_API_TOKEN="$CLOUDFLARE_API_TOKEN_READ"
    elif [ -n "${CLOUDFLARE_API_TOKEN:-}" ]; then
      echo "note: no CLOUDFLARE_API_TOKEN_READ in $module_secrets; this read-only command runs with the write token" >&2
    fi
    ;;
esac
unset CLOUDFLARE_API_TOKEN_READ

exec docker run --rm -i -v "$repo_root":/repo -w /repo -e TF_CLI_CONFIG_FILE=/repo/.cache/tofu/tofurc "${env_args[@]}" "$TOFU_IMAGE" -chdir="$module_dir" "$@"
