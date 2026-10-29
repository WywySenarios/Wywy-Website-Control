#!/bin/bash
set -euo pipefail

REPO_ROOT="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/../../..")"
cd "$REPO_ROOT"

echo "==> pytest (wywy_hosts)" >&2
uv run --project ansible pytest -c ansible/pyproject.toml ansible/tests "$@"
