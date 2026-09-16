#!/usr/bin/env bash
set -euo pipefail

jq 'del(
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
