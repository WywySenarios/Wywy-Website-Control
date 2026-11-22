#!/bin/bash
#
# Run OpenTofu with the environment's credentials loaded from sops.
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

# The file contains one API token in the form user@realm!tokenid=secret. This
# is not the root password and not an SSH key.
proxmox_token_file="$secrets_dir/proxmox/terraform.sops"
if [ ! -f "$proxmox_token_file" ]; then
	error "$proxmox_token_file is missing; create a terraform@pve API token and store it there"
	exit 1
fi

proxmox_token="$(
	sops -d --output-type binary "$proxmox_token_file" |
		sed -n '1p' |
		tr -d '\r'
)"
if [ -z "$proxmox_token" ]; then
	error "$proxmox_token_file is empty"
	exit 1
fi
case "$proxmox_token" in
*[[:space:]]*)
	error "$proxmox_token_file token contains whitespace"
	exit 1
	;;
*'!'*'='*) ;;
*)
	error "$proxmox_token_file must contain user@realm!tokenid=secret"
	exit 1
	;;
esac
export PROXMOX_VE_API_TOKEN="$proxmox_token"

cloudflare_secrets="$CONTROL_DIR/secrets/$WYWY_ENV/cloudflare.sops.yaml"
if [ ! -f "$cloudflare_secrets" ]; then
	error "$cloudflare_secrets is missing; store the Cloudflare API token and IDs there"
	exit 1
fi

read_cloudflare_secret() {
	local key="$1"
	local value
	if ! value="$(sops -d --extract "[\"$key\"]" "$cloudflare_secrets" 2>/dev/null | tr -d '\r')"; then
		error "$cloudflare_secrets is missing $key"
		exit 1
	fi
	if [ -z "$value" ]; then
		error "$cloudflare_secrets has an empty $key"
		exit 1
	fi
	printf '%s' "$value"
}

cloudflare_api_token="$(read_cloudflare_secret cloudflare_api_token)"
cloudflare_account_id="$(read_cloudflare_secret cloudflare_account_id)"
cloudflare_zone_id="$(read_cloudflare_secret cloudflare_zone_id)"

case "$cloudflare_api_token" in
*[[:space:]]*)
	error "$cloudflare_secrets cloudflare_api_token contains whitespace"
	exit 1
	;;
esac

export CLOUDFLARE_API_TOKEN="$cloudflare_api_token"
export TF_VAR_cloudflare_account_id="$cloudflare_account_id"
export TF_VAR_cloudflare_zone_id="$cloudflare_zone_id"

export PROXMOX_VE_ENDPOINT="${PROXMOX_VE_ENDPOINT:-https://proxmox-1.internal:8006/}"
export PROXMOX_VE_INSECURE="${PROXMOX_VE_INSECURE:-true}"
export TF_VAR_environment="$WYWY_ENV"

header "OpenTofu ($WYWY_ENV)"
exec tofu -chdir="$CONTROL_DIR/terraform" "$@"
