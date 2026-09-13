#!/usr/bin/env bash
#
# Re-IP existing worker VMs on one or more Proxmox hosts (in place, no rebuild).
#
# Updates each VM's cloud-init network config (ipconfig0) from config/.env.network
# and restarts it so the guest comes up on the new subnet.
#
# Usage:
#   scripts/proxmox/vm/reip-workers.sh --dev
#   scripts/proxmox/vm/reip-workers.sh --prod
#   scripts/proxmox/vm/reip-workers.sh <host> [host...]
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
SYSUSER="wywy"

process_target() {
	local host="$1" worker="$2" idx="$3" prefix="$4"
	local vmid="${worker##*.}" # last octet → VMID
	local cidr="${worker}/24"

	: "${GATEWAY:?GATEWAY not set in config/.env.network}"
	: "${NAMESERVER:?NAMESERVER not set in config/.env.network}"

	echo "==> ${prefix}-$((idx + 1)) (VM $vmid → $worker) on ${host}..."

	ssh "$SYSUSER@$host" bash -s <<REMOTE
    set -euo pipefail

    if ! sudo qm status $vmid >/dev/null 2>&1; then
      echo "  — VM $vmid does not exist on this host"
      exit 0
    fi

    sudo qm set $vmid --ipconfig0 "ip=$cidr,gw=$GATEWAY" --nameserver "$NAMESERVER"
    echo "  ✓ $vmid ipconfig0 set to $worker"

    if sudo qm status $vmid | grep -q running; then
      sudo qm stop $vmid
    fi
    sudo qm start $vmid

    echo "  ✓ $worker — VM $vmid restarted on new IP"
REMOTE

	echo "  OK"
	echo ""
}

source "$SCRIPT_DIR/../target-loop.sh"
