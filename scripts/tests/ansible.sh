#!/bin/bash
# scripts/tests/ansible.sh — ansible suite: lint + syntax-check for ansible/.
# Independent of the (pre-existing-broken) deployment suite, so
# ./test.sh ansible is a clean gate.
#
# Installs its own toolchain via scripts/install/ansible.sh, so it works on a
# clean checkout. Tooling is invoked through `uv run`, never via a hardcoded
# .venv/bin path.
#
# ANSIBLE_INVENTORY=/dev/null keeps --syntax-check from loading the inventory.
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$CONTROL_DIR"

"$CONTROL_DIR/scripts/install/ansible.sh"

export ANSIBLE_CONFIG="$CONTROL_DIR/ansible/ansible.cfg"
export ANSIBLE_COLLECTIONS_PATH="$CONTROL_DIR/ansible/.collections"
export ANSIBLE_INVENTORY=/dev/null

echo "==> ruff (strict)" >&2
uv run --project ansible ruff check ansible/

echo "==> ansible-lint (production profile)" >&2
uv run --project ansible ansible-lint -c ansible/.ansible-lint ansible/

echo "==> ansible-playbook --syntax-check" >&2
shopt -s nullglob globstar
playbooks=(ansible/playbooks/**/*.yaml)
if [ "${#playbooks[@]}" -eq 0 ]; then
	echo "==> no playbooks under ansible/playbooks/ yet — lint only" >&2
	exit 0
fi
for playbook in "${playbooks[@]}"; do
	uv run --project ansible ansible-playbook "$playbook" --syntax-check
done
