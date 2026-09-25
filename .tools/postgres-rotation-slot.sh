#!/usr/bin/env bash
set -euo pipefail

action="${1:-}"
app="${2:-}"
slot="${3:-}"
values_file="argocd/apps/data/shared-postgres/values.yaml"

case "$app" in
portfolio|keycloak)
  ;;
*)
  echo "usage: $0 <status|activate|retire> <portfolio|keycloak> [slot]" >&2
  exit 2
  ;;
esac

active_slot="$(yq -r ".rotation.${app}.activeSlot" "$values_file")"
retired_slot="$(yq -r ".rotation.${app}.retiredSlot // \"\"" "$values_file")"

case "$action" in
status)
  printf '%s active=%s retired=%s\n' "$app" "$active_slot" "$retired_slot"
  ;;
activate)
  case "$slot" in
  a|b)
    ;;
  *)
    echo "activate requires slot a or b" >&2
    exit 2
    ;;
  esac
  test "$active_slot" != "$slot" || {
    echo "$app slot $slot is already active" >&2
    exit 1
  }
  test -f "argocd/apps/data/shared-postgres/templates/${app}-postgres-app-${slot}.sops-secret.yaml" || {
    echo "slot Secret is missing for $app/$slot" >&2
    exit 1
  }
  yq -i ".rotation.${app}.activeSlot = \"${slot}\" | .rotation.${app}.retiredSlot = \"\"" "$values_file"
  printf '%s slot %s activated\n' "$app" "$slot"
  ;;
retire)
  case "$slot" in
  a|b)
    ;;
  *)
    echo "retire requires slot a or b" >&2
    exit 2
    ;;
  esac
  test "$active_slot" != "$slot" || {
    echo "cannot retire the active slot $app/$slot" >&2
    exit 1
  }
  yq -i ".rotation.${app}.retiredSlot = \"${slot}\"" "$values_file"
  printf '%s slot %s retired\n' "$app" "$slot"
  ;;
*)
  echo "usage: $0 <status|activate|retire> <portfolio|keycloak> [slot]" >&2
  exit 2
  ;;
esac
