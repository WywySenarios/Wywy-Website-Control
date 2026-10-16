#!/bin/bash
#
# resolve-hosts.sh — run a command (default: a shell) in a private mount
# namespace with the merged hosts file overlaid on /etc/hosts.
#
# The command and everything it starts resolve *.internal names from the
# repo's hosts file; nothing outside the namespace sees the overlay. When the
# command exits, the namespace and its mounts vanish. The on-disk /etc/hosts
# and the host namespace are never touched.
#
# Usage:
#   scripts/lib/resolve-hosts.sh --dev|--prod              # interactive shell
#   scripts/lib/resolve-hosts.sh --dev|--prod -- <cmd...>  # run a command
#
# Requires: unshare with user+mount namespaces (Debian 13 default), sudo
#           sops (operator age key).
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

usage() {
	echo "Usage: $0 --dev|--prod [-- command [args...]]" >&2
	exit 1
}

# ---- Parse mode: --dev|--prod (required); anything after an optional `--`
# ---- is a command to run inside the namespace. ----
case "${1:-}" in
--dev | --prod)
	HOSTS_MODE="${1#--}"
	shift
	;;
*) usage ;;
esac
[ "${1:-}" = "--" ] && shift

# shellcheck source=hosts.sh
source "$SCRIPT_DIR/hosts.sh"

MERGED="$(mktemp)"
chmod 644 "$MERGED" # the overlay must stay world-readable in the namespace
cat /etc/hosts >"$MERGED"
sudo sops -d --output-type binary "$HOSTS_FILE" >>"$MERGED" || {
	echo "resolve-hosts: failed to decrypt $HOSTS_FILE" >&2
	rm -f "$MERGED"
	exit 1
}

unshare --user --map-root-user --mount --propagation private \
	bash -c '
		mount --bind "$1" /etc/hosts
		rm -f "$1"   # the mount keeps the inode alive
		shift
		[ "$#" -eq 0 ] && exec bash
		exec "$@"
	' bash "$MERGED" "$@"
