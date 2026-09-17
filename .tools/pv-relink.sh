#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

usage() {
  cat >&2 <<'EOF'
usage: pv-relink.sh <pv> <namespace> <pvc-name> <size> [cnpg-cluster]

  pv           name of the Released PersistentVolume to reattach
  namespace    namespace the new PVC belongs to
  pvc-name     name the consumer expects (e.g. <cluster>-1 for a first CNPG instance)
  size         storage request, equal to or smaller than the PV's own capacity
  cnpg-cluster optional; when given, the PVC gets the three labels the CNPG
               operator requires to adopt an existing volume as PG_DATA for
               that cluster's first instance
EOF
  exit 2
}

[ "$#" -ge 4 ] || usage

pv="$1"
namespace="$2"
pvc_name="$3"
size="$4"
cnpg_cluster="${5:-}"

echo "removing claimRef from $pv, so it returns to Available" >&2
just kubectl patch pv "$pv" --type json -p '[{"op":"remove","path":"/spec/claimRef"}]'

labels=""
if [ -n "$cnpg_cluster" ]; then
  labels="  labels:
    cnpg.io/cluster: $cnpg_cluster
    cnpg.io/instanceName: ${cnpg_cluster}-1
    cnpg.io/pvcRole: PG_DATA
"
fi

pvc_yaml="apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $pvc_name
  namespace: $namespace
${labels}spec:
  accessModes: [ReadWriteOnce]
  storageClassName: local-path
  volumeName: $pv
  resources:
    requests:
      storage: $size
"

echo >&2
echo "$pvc_yaml"
echo >&2
echo "applying the PVC above" >&2
printf '%s' "$pvc_yaml" | just kubectl apply -f -

echo >&2
echo "next: confirm the PV went back to Bound with just kubectl get pv $pv" >&2
if [ -n "$cnpg_cluster" ]; then
  echo "then apply the Cluster manifest for $cnpg_cluster so the operator adopts this PVC; do not delete the PV before it reports healthy" >&2
fi
