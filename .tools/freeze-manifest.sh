#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <kind> <name> [-n <namespace>] [kubectl args...]" >&2
  exit 2
fi

kubectl get "$@" -o json | jq 'del(
  .metadata.uid,
  .metadata.resourceVersion,
  .metadata.generation,
  .metadata.creationTimestamp,
  .metadata.managedFields,
  .metadata.selfLink,
  .metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"],
  .metadata.annotations["deployment.kubernetes.io/revision"],
  .status
) | if .metadata.annotations == {} then del(.metadata.annotations) else . end' | yq -P
