#!/usr/bin/env bash
#
# Destroy K8s worker VMs on one or more Proxmox hosts.
#
# Usage:
#   scripts/proxmox/vm/destroy-workers.sh --dev
#   scripts/proxmox/vm/destroy-workers.sh --prod
#   scripts/proxmox/vm/destroy-workers.sh <host> [host...]
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
SYSUSER="wywy"

# ---- Define callback ----
process_target() {
	local host="$1" worker="$2" idx="$3" prefix="$4"
	local vmid="${worker##*.}" # last octet → VMID

	echo "==> Destroying ${prefix} (VM $vmid) on ${host}..."

	ssh "$SYSUSER@$host" bash -s <<REMOTE
    set -euo pipefail

    if sudo qm status $vmid >/dev/null 2>&1; then
      sudo qm stop $vmid 2>/dev/null || true
      sudo qm destroy $vmid
      echo "  ✓ $vmid destroyed"
    else
      echo "  — VM $vmid does not exist on this host"
    fi
REMOTE

	echo "  OK"
	echo ""
}

# ---- Source helper (runs the loop) ----
source "$SCRIPT_DIR/../target-loop.sh"
