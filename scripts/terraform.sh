#!/bin/bash
#
# Run OpenTofu with the environment's uapi and Proxmox tokens loaded from sops.
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

# Proxmox is required. The file contains one API token in the form
# user@realm!tokenid=secret. This is not the root password and not an SSH key.
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

export PROXMOX_VE_ENDPOINT="${PROXMOX_VE_ENDPOINT:-https://proxmox-1.internal:8006/}"
export PROXMOX_VE_INSECURE="${PROXMOX_VE_INSECURE:-true}"

header "OpenTofu ($WYWY_ENV)"
exec tofu -chdir="$CONTROL_DIR/terraform" "$@"
