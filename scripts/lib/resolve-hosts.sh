#!/usr/bin/env bash
#
# resolve-hosts.sh — start a shell in a private mount namespace with the
# merged hosts file overlaid on /etc/hosts.
#
# The shell and everything you start from it resolve *.internal names from
# the repo's hosts file; nothing outside the namespace sees the overlay.
# When the shell exits, the namespace and its mounts vanish. The on-disk
# /etc/hosts and the host namespace are never touched.
#
# Usage:
#   scripts/lib/resolve-hosts.sh [--dev|--prod]
#
# Requires: unshare with user+mount namespaces (Debian 13 default), sudo
#           sops (operator age key).
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# ---- Parse mode: --dev|--prod (default dev) ----
[[ $# -le 1 ]] || {
	echo "Usage: $0 [--dev|--prod]" >&2
	exit 1
}
HOSTS_MODE="dev"
case "${1:-}" in
--dev | --prod)
	HOSTS_MODE="${1#--}"
	;;
"") ;;
*)
	echo "Usage: $0 [--dev|--prod]" >&2
	exit 1
	;;
esac

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
		exec bash
	' bash "$MERGED"
