#!/usr/bin/env bash
#
# Clone worker VMs from template on one or more Proxmox hosts.
#
# Usage:
#   scripts/proxmox/vm/recreate-workers.sh --dev
#   scripts/proxmox/vm/recreate-workers.sh --prod
#   scripts/proxmox/vm/recreate-workers.sh <host> [host...]
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
SYSUSER="wywy"
GATEWAY="192.168.2.1"
NAMESERVER="192.168.2.1"

# ---- Define callback ----
process_target() {
	local host="$1" worker="$2" idx="$3" prefix="$4"
	local template_vmid=$((2501 + idx))
	local vmid="${worker##*.}" # last octet → VMID
	local name="${prefix}-$((idx + 1))"
	local cidr="${worker}/24"

	echo "==> $name (VM $vmid → $worker) on ${host}..."

	ssh "$SYSUSER@$host" bash -s <<REMOTE
    set -euo pipefail

    sudo qm clone $template_vmid $vmid --name "$name"
    sudo qm set $vmid --ipconfig0 "ip=$cidr,gw=$GATEWAY" --nameserver "$NAMESERVER"
    sudo qm start $vmid

    echo "  ✓ $worker — $name started"
REMOTE

	echo "  OK"
	echo ""
}

# ---- Source helper (runs the loop) ----
source "$SCRIPT_DIR/../target-loop.sh"
