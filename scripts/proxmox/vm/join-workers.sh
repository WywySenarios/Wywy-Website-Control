#!/usr/bin/env bash
#
# Run a kubeadm join command on all relevant worker VMs.
#
# Usage:
#   scripts/proxmox/vm/join-workers.sh <join-command> --dev
#   scripts/proxmox/vm/join-workers.sh <join-command> --prod
#   scripts/proxmox/vm/join-workers.sh <join-command> <host> [host...]
#   scripts/proxmox/vm/join-workers.sh --dry-run <join-command> --dev
#
# The join command is the first positional argument.  Generate it with:
#   "$(kubeadm token create --print-join-command)"
#
# Example:
#   scripts/proxmox/vm/join-workers.sh \
#     "$(sudo kubeadm token create --print-join-command)" --dev
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
SYSUSER="wywy"
DRY_RUN=false

# ---- Consume join command, shift rest for the helper ----
case "${1:-}" in
--dry-run)
	DRY_RUN=true
	shift
	;;
esac

JOIN_CMD="$1"
[ -z "$JOIN_CMD" ] && {
	echo "Usage: $0 <join-command> [--dev|--prod|<host>...]" >&2
	echo ""
	echo "  Generate the join command with:" >&2
	echo "    \"\$(sudo kubeadm token create --print-join-command)\"" >&2
	echo ""
	echo "  Example:" >&2
	echo "    $0 \"\$(sudo kubeadm token create --print-join-command)\" --dev" >&2
	exit 1
}
shift

# ---- Define callback ----
process_target() {
	local host="$1" worker="$2" idx="$3" prefix="$4"

	if [ "$DRY_RUN" = true ]; then
		echo "==> Would run on worker $idx ($worker):"
		echo "    ssh $SYSUSER@$worker sudo $JOIN_CMD"
		echo ""
		return
	fi

	echo "==> Joining worker $idx ($worker)..."

	if ssh "$SYSUSER@$worker" "sudo $JOIN_CMD"; then
		echo "  ✓ Worker $idx joined"
	else
		echo "  ✗ Worker $idx join failed" >&2
	fi
	echo ""
}

# ---- Source helper (runs the loop) ----
source "$SCRIPT_DIR/../target-loop.sh"
