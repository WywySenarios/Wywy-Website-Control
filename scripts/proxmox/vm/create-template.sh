#!/usr/bin/env bash
#
# Create the Debian cloud-init template on every Proxmox host in a group.
#
# Usage:
#   scripts/proxmox/vm/create-template.sh <image-url> --dev
#   scripts/proxmox/vm/create-template.sh <image-url> --prod
#   scripts/proxmox/vm/create-template.sh <image-url> <host> [host...]
#
# Each host gets its own template. VMIDs start at 2501 and increment per host.
# After this completes, the recreate/destroy scripts know which template VMID
# lives on which host by matching index.
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
SYSUSER="wywy"

# ---- Consume image URL, shift rest for the helper ----
IMAGE_URL="${1:-}"
case "$IMAGE_URL" in
--* | '')
	echo "Usage: $0 <image-url> [--dev|--prod|<host>...]" >&2
	echo ""
	echo "  <image-url> should be a Debian cloud image URL, e.g.:" >&2
	echo "    https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2" >&2
	exit 1
	;;
esac
shift

IMAGE_FILE="debian-13-generic-amd64.qcow2"
STORAGE="data"
BRIDGE="vmbr0"

# ---- Define callback ----
process_target() {
	local host="$1" worker="$2" idx="$3" prefix="$4"
	local vmid=$((2501 + idx))
	local name="debian-13-k8s-template-${vmid}"

	echo "==> Creating template $vmid ($name) on $host..."

	# shellcheck disable=SC2087
	ssh "$SYSUSER@$host" bash -s <<REMOTE
    set -euo pipefail

    step() { echo ""; echo "==> \$*"; }

    step "Download cloud image"
    if [ ! -f "$IMAGE_FILE" ]; then
      wget "$IMAGE_URL"
    else
      echo "  — already downloaded, reusing"
    fi

    step "Create VM $vmid"
    sudo qm create $vmid \
      --memory 4096 \
      --cores 2 \
      --net0 virtio,bridge=$BRIDGE \
      --name $name

    step "Import disk"
    sudo qm importdisk $vmid "$IMAGE_FILE" $STORAGE

    step "Attach disk"
    sudo qm set $vmid --scsihw virtio-scsi-pci --scsi0 ${STORAGE}:vm-${vmid}-disk-0

    step "Resize disk to 32G"
    sudo qm resize $vmid scsi0 32G

    step "Attach cloud-init drive"
    sudo qm set $vmid --ide2 ${STORAGE}:cloudinit

    step "Set boot order"
    sudo qm set $vmid --boot order=scsi0

    step "Configure cloud-init defaults"
    sudo qm set $vmid \
      --ciuser wywy \
      --sshkeys /home/wywy/.ssh/authorized_keys \
      --ipconfig0 ip=dhcp

    step "Apply cloud-init snippet (if pushed)"
    if [ -f /var/lib/vz/snippets/k8s-worker-general.yaml ]; then
      sudo qm set $vmid --cicustom "vendor=local:snippets/k8s-worker-general.yaml"
      echo "  -> snippet applied"
    else
      echo "  — no snippet found — skipping --cicustom"
    fi

    step "Convert to template"
    sudo qm template $vmid

    echo ""
    echo "  ✓ Template $vmid ready on $host"
REMOTE

	echo "  OK"
	echo ""
}

# ---- Source helper (runs the loop) ----
source "$SCRIPT_DIR/../target-loop.sh"
