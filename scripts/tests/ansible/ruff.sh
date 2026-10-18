#!/bin/bash
set -euo pipefail

REPO_ROOT="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/../../..")"
cd "$REPO_ROOT"

echo "==> ruff (strict)" >&2
uv run --project ansible ruff check ansible/
