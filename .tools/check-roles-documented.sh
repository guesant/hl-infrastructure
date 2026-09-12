#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

status=0
for role_dir in ansible/roles/*/; do
  role="$(basename "$role_dir")"
  if ! grep -qE "\`$role\`" docs/arquitetura/ansible.md; then
    echo "role $role has no paragraph in docs/arquitetura/ansible.md" >&2
    status=1
  fi
done

for role in $(sed -nE 's/^    - ([a-z_]+)$/\1/p' ansible/site.yml); do
  [ -d "ansible/roles/$role" ] || {
    echo "site.yml lists role $role, which does not exist" >&2
    status=1
  }
done

if [ "$status" -eq 0 ]; then
  echo "every role is described in docs/arquitetura/ansible.md"
fi
exit "$status"
