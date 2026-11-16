#!/bin/bash
set -euo pipefail

REPO_ROOT="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/../../..")"
cd "$REPO_ROOT"

# shellcheck source=../lib/output.sh
source scripts/lib/output.sh

header "tofu fmt -check"
tofu fmt -check -recursive -diff terraform/
