#!/bin/bash
set -euo pipefail

REPO_ROOT="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/../../..")"
cd "$REPO_ROOT/ansible"

echo "==> mypy (strict)" >&2
uv run mypy src plugins tests "$@"
