#!/usr/bin/env bash
#
# Source this file to look up external-host IPs from the encrypted internal hosts file.
#
# Two functions are exposed:
#   hosts_ip <hostname>    # prints the IP or exits 1
#   hosts_ip_real <name>   # like hosts_ip, but rejects RFC 5737 placeholders
#
# Environment: HOSTS_MODE=dev|prod selects the file (default: dev).
# Requires: sops (decrypts with the operator age key, hence sudo).
#
# This file is meant to be sourced. CONVENTION EXCETION: this script does not `set -euo pipefail`. We don't want to leak it into callees.

hosts_lib_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
hosts_control_dir="$(realpath "$hosts_lib_dir/../..")"
: "${HOSTS_MODE:=dev}"
HOSTS_FILE="$hosts_control_dir/secrets/$HOSTS_MODE/hosts.sops.yaml"

hosts_ip() {
	local name="${1:-}" plain ip
	[[ -n "$name" ]] || {
		echo "hosts_ip: missing name" >&2
		return 1
	}
	[[ -f "$HOSTS_FILE" ]] || {
		echo "hosts_ip: $HOSTS_FILE not found" >&2
		return 1
	}
	plain="$(sudo sops -d --output-type binary "$HOSTS_FILE")" || {
		echo "hosts_ip: sops decrypt failed for $HOSTS_FILE" >&2
		return 1
	}
	ip="$(awk -v n="$name" '$2==n{print $1; exit}' <<<"$plain")"
	[[ -n "$ip" ]] || {
		echo "hosts_ip: '$name' not found in $HOSTS_FILE" >&2
		return 1
	}
	printf '%s\n' "$ip"
}

# Like hosts_ip, but refuses RFC 5737 TEST-NET placeholders so a stale
# committed hosts file can never provision a real address.
hosts_ip_real() {
	local ip
	ip="$(hosts_ip "$1")" || return 1
	case "$ip" in
	192.0.2.* | 198.51.100.* | 203.0.113.*)
		echo "hosts_ip: '$1' resolves to placeholder $ip — re-encrypt $HOSTS_FILE with the real IP first" >&2
		return 1
		;;
	esac
	printf '%s\n' "$ip"
}
