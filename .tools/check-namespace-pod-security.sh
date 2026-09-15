#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

declare -A created=()
declare -A enforced=()

while IFS= read -r app; do
  grep -q 'CreateNamespace=true' "$app" || continue
  namespace="$(awk '/^  destination:/ {d=1; next} d && /^    namespace:/ {print $2; exit} /^  [a-z]/ {d=0}' "$app")"
  [ -n "$namespace" ] || continue
  created["$namespace"]+="$app "
  if grep -qE '^ +pod-security\.kubernetes\.io/enforce: (restricted|baseline|privileged)$' "$app"; then
    enforced["$namespace"]=1
  fi
done < <(find argocd/applications -name '*.yaml' | sort)

while IFS= read -r manifest; do
  grep -qE '^kind: Namespace$' "$manifest" || continue
  grep -qE '^ +pod-security\.kubernetes\.io/enforce: (restricted|baseline|privileged)$' "$manifest" || continue
  namespace="$(awk '/^metadata:/ {m=1; next} m && /^  name:/ {print $2; exit}' "$manifest")"
  [ -n "$namespace" ] && enforced["$namespace"]=1
done < <(find argocd/apps -path '*/templates/*.yaml' | sort)

if grep -q 'pod-security.kubernetes.io/enforce=restricted' ansible/roles/argocd/tasks/main.yml; then
  enforced[argocd]=1
fi

status=0
for namespace in "${!created[@]}"; do
  if [ -z "${enforced[$namespace]:-}" ]; then
    echo "namespace $namespace is created by ${created[$namespace]}but no Application declares pod-security.kubernetes.io/enforce for it" >&2
    status=1
  fi
done

if [ "$status" -eq 0 ]; then
  echo "every namespace created by an Application declares a Pod Security enforce level"
fi
exit "$status"
