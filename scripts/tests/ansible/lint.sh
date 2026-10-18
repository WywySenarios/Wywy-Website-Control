#!/bin/bash
set -euo pipefail

REPO_ROOT="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/../../..")"
cd "$REPO_ROOT"

export ANSIBLE_CONFIG="ansible/ansible.cfg"
export ANSIBLE_COLLECTIONS_PATH="ansible/.collections"

echo "==> ansible-lint (production profile)" >&2
uv run --project ansible ansible-lint -c ansible/.ansible-lint ansible/
