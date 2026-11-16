#!/bin/bash
#
# Run OpenTofu with the environment's uapi token loaded from sops.
#
# Usage:
#   scripts/terraform.sh (--dev|--prod) [tofu arguments...]
#
# Examples:
#   scripts/terraform.sh --dev plan
#   scripts/terraform.sh --prod validate
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONTROL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/output.sh
source "$CONTROL_DIR/scripts/lib/output.sh"

case "${1:-}" in
--dev | --prod)
	WYWY_ENV="${1#--}"
	shift
	;;
*)
	error "usage: scripts/terraform.sh (--dev|--prod) [tofu arguments...]"
	exit 1
	;;
esac

secrets_dir="$CONTROL_DIR/secrets/$WYWY_ENV"
token_file="$secrets_dir/openwrt/uapi.sops"

uapi_token="$(
	sops -d --output-type binary "$token_file" |
		sed -n '1p' |
		tr -d '\r'
)"
if [ -z "$uapi_token" ]; then
	error "$token_file is empty"
	exit 1
fi
case "$uapi_token" in
*[[:space:]]*)
	error "$token_file token contains whitespace"
	exit 1
	;;
esac

# The router uses a self-signed certificate today. Set UAPI_INSECURE=0 once it
# has a trusted certificate.
UAPI_INSECURE="${UAPI_INSECURE:-1}"

export UAPI_TOKEN="$uapi_token"
export UAPI_INSECURE

header "OpenTofu ($WYWY_ENV)"
exec tofu -chdir="$CONTROL_DIR/terraform" "$@"
