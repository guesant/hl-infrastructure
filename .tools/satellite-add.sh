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

target="argocd/applications/satellites/$name.yaml"
if [ -e "$target" ]; then
  echo "$target already exists; edit it directly or pick a different name" >&2
  exit 1
fi

cat >"$target" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $name
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "$sync_wave"
spec:
  project: satellites
  source:
    repoURL: $repo_url
    targetRevision: main
    path: $source_path
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  revisionHistoryLimit: 3
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
      allowEmpty: false
    syncOptions:
      - ServerSideApply=true
      - FailOnSharedResource=true
      - PruneLast=true
      - PrunePropagationPolicy=foreground
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF

echo "wrote $target" >&2
echo >&2
echo "next:" >&2
echo "  1. confirm the other repository's own Application objects repeat the same syncPolicy block" >&2
echo "  2. git add $target && git commit && git push" >&2
echo "  3. just status, to confirm the application appears and syncs" >&2
