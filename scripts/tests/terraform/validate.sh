#!/bin/bash
set -euo pipefail

REPO_ROOT="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/../../..")"
cd "$REPO_ROOT"

# shellcheck source=../lib/output.sh
source scripts/lib/output.sh

# The root composes every domain module, so validating the root validates the
# modules as well.
header "tofu init + validate (terraform)"
if ! (
	cd terraform
	tofu init -backend=false -input=false -no-color
	tofu validate -no-color
); then
	error "terraform validation failed"
	exit 1
fi

echo "==> terraform validation passed" >&2
