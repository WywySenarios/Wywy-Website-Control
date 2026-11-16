#!/bin/bash
set -euo pipefail

REPO_ROOT="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/../../..")"
cd "$REPO_ROOT"

# shellcheck source=../lib/output.sh
source scripts/lib/output.sh

mapfile -t MODULES < <(find terraform -type f -name '*.tf' -printf '%h\n' | sort -u)
if [ "${#MODULES[@]}" -eq 0 ]; then
	error "no Terraform modules found under terraform/"
	exit 1
fi

STATUS=0
for module in "${MODULES[@]}"; do
	header "tofu init + validate ($module)"
	if ! (
		cd "$module"
		tofu init -backend=false -input=false -no-color
		tofu validate -no-color
	); then
		STATUS=1
	fi
done

exit "$STATUS"
