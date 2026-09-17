#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

usage() {
  cat >&2 <<'EOF'
usage: satellite-add.sh <nome> <repo-url> <path> [sync-wave]

  nome       lowercase name for the satellite, matches ^[a-z][a-z0-9-]*$
  repo-url   git URL of the other repository, e.g. https://github.com/org/repo.git
  path       path inside that repository holding its Argo control objects
  sync-wave  optional, defaults to 10 (same as every existing satellite)
EOF
  exit 2
}

[ "$#" -ge 3 ] || usage

name="$1"
repo_url="$2"
source_path="$3"
sync_wave="${4:-10}"

if [[ ! "$name" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "nome must match ^[a-z][a-z0-9-]*\$, got: $name" >&2
  exit 2
fi

values_file="argocd/apps/satellites/launcher/values.yaml"

if yq -e ".satellites[] | select(.name == \"$name\")" "$values_file" >/dev/null 2>&1; then
  echo "$name already exists in $values_file; edit it directly or pick a different name" >&2
  exit 1
fi

new_entry="$(jq -n --arg name "$name" --arg repoURL "$repo_url" --arg path "$source_path" --arg syncWave "$sync_wave" \
  '{name: $name, repoURL: $repoURL, path: $path, syncWave: $syncWave}')"

yq -i ".satellites += [$new_entry]" "$values_file"

echo "added $name to $values_file" >&2
echo >&2
echo "next:" >&2
echo "  1. confirm the other repository's own Application objects repeat the same syncPolicy block" >&2
echo "  2. just infra-render-charts, to see the new Application rendered" >&2
echo "  3. git add $values_file && git commit && git push" >&2
echo "  4. just status, to confirm the application appears and syncs" >&2
