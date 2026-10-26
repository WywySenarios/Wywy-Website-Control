#!/bin/bash
set -euo pipefail

REPO_ROOT="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/../../..")"
cd "$REPO_ROOT"

export ANSIBLE_CONFIG="ansible/ansible.cfg"
export ANSIBLE_COLLECTIONS_PATH="ansible/.collections"
export ANSIBLE_INVENTORY=/dev/null
export SOPS_ANSIBLE_AWX_DISABLE_VARS_PLUGIN_TEMPORARILY=true

echo "==> ansible-playbook --syntax-check" >&2
shopt -s nullglob globstar
playbooks=(ansible/playbooks/**/*.yaml)
[ "${#playbooks[@]}" -gt 0 ] || {
	echo "no playbooks matched ansible/playbooks/**/*.yaml" >&2
	exit 1
}
for playbook in "${playbooks[@]}"; do
	uv run --project ansible ansible-playbook "$playbook" --syntax-check
done
