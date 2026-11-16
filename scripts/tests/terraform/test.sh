#!/bin/bash
set -euo pipefail

REPO_ROOT="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/../../..")"
cd "$REPO_ROOT"

# shellcheck source=../lib/output.sh
source scripts/lib/output.sh

mapfile -t ROOTS < <(find terraform -type d -name tests -printf '%h\n' | sort -u)
if [ "${#ROOTS[@]}" -eq 0 ]; then
	error "no OpenTofu test directories found under terraform/"
	exit 1
fi

STATUS=0
for root in "${ROOTS[@]}"; do
	header "tofu test ($root)"
	if ! (
		cd "$root"
		tofu init -backend=false -input=false -no-color
		tofu test -no-color
	); then
		STATUS=1
	fi
done

exit "$STATUS"
