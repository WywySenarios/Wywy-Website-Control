#!/bin/bash
#
# Idempotent ansible installation and setup.
#
# Prerequisite: uv.
#
# Usage:
#   scripts/install/ansible.sh [--dry-run]
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ANSIBLE_DIR="$CONTROL_DIR/ansible"
COLLECTIONS_DIR="$ANSIBLE_DIR/.collections"

# shellcheck source=../lib/output.sh
source "$CONTROL_DIR/scripts/lib/output.sh"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

if "$DRY_RUN"; then
	header "Plan (dry run)"
	info "uv sync --directory $ANSIBLE_DIR --locked"
	info "uv run --project $ANSIBLE_DIR ansible-galaxy collection install -p $COLLECTIONS_DIR -r $ANSIBLE_DIR/requirements.yml"
	exit 0
fi

command -v uv >/dev/null 2>&1 || {
	error "ansible: 'uv' not found in PATH — install it (https://docs.astral.sh/uv/)"
	exit 1
}

header "Syncing the Ansible toolchain ($ANSIBLE_DIR)"
uv sync --directory "$ANSIBLE_DIR" --locked

header "Installing pinned Ansible collections"
export ANSIBLE_COLLECTIONS_PATH="$COLLECTIONS_DIR"
uv run --project "$ANSIBLE_DIR" ansible-galaxy collection install \
	-p "$COLLECTIONS_DIR" -r "$ANSIBLE_DIR/requirements.yml"

info "Ansible toolchain ready ($ANSIBLE_DIR/.venv)"
