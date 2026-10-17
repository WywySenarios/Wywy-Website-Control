#!/usr/bin/env bash
#
# Create the Debian cloud-init template for the dedicated Postgres DB VM on
# the DB hypervisor.
#
# One template per environment (prod/dev), each on its own hypervisor. The
# template gets NO --cicustom and installs nothing beyond the base image:
# postgres is installed and configured on each clone by the Ansible `postgres`
# role (see vm/db/create-vm.sh), so nothing leaks into the k8s worker clones
# that share the VMID scheme.
#
# Usage:
#   scripts/proxmox/vm/db/create-template.sh --dev|--prod <image-url>
#
# --dev|--prod is REQUIRED and selects the .env.network group:
#   prod → DATABASE_TEMPLATE_VMID on DATABASE_PROXMOX_HOST
#   dev  → DEV_DATABASE_TEMPLATE_VMID on DEV_DATABASE_PROXMOX_HOST
#
# Example:
#   scripts/proxmox/vm/db/create-template.sh --dev \
#     https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ENV_NETWORK="$CONTROL_DIR/config/.env.network"
SYSUSER="wywy"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o BatchMode=yes"
STORAGE="data"
BRIDGE="vmbr0"
IMAGE_FILE="debian-13-generic-amd64.qcow2"

# ---- Parse mode: --dev|--prod (required) ----
MODE="${1:-}"
case "$MODE" in
--dev) MODE="dev" ;;
--prod) MODE="prod" ;;
*)
	echo "Error: first argument must be --dev or --prod (got '${MODE:-<none>}')" >&2
	echo "Usage: scripts/proxmox/vm/db/create-template.sh --dev|--prod <image-url>" >&2
	exit 1
	;;
esac
shift

# ---- Image URL is required ----
IMAGE_URL="${1:-}"
case "$IMAGE_URL" in
--* | '')
	echo "Usage: $0 --dev|--prod <image-url>" >&2
	echo "" >&2
	echo "  <image-url> should be a Debian cloud image URL, e.g.:" >&2
	echo "    https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2" >&2
	exit 1
	;;
esac

# ---- Source network config ----
[[ -f "$ENV_NETWORK" ]] || {
	echo "Error: $ENV_NETWORK not found" >&2
	echo "Copy config/.env.network.example to config/.env.network and fill in your values." >&2
	exit 1
}
# shellcheck disable=SC1090
source "$ENV_NETWORK"

# Variable group selected by mode (prod keeps the DATABASE_* names).
VP="DATABASE"
[ "$MODE" = "dev" ] && VP="DEV_DATABASE"

# ---- Guards: every required variable must be non-empty ----
for var in "${VP}_PROXMOX_HOST" "${VP}_TEMPLATE_VMID"; do
	: "${!var:?$var not set in config/.env.network}"
done

HOST_DEFAULT="${VP}_PROXMOX_HOST"
HOST_DEFAULT="${!HOST_DEFAULT}"
TEMPLATE_VMID="${VP}_TEMPLATE_VMID"
TEMPLATE_VMID="${!TEMPLATE_VMID}"
NAME="debian-13-db-template-${TEMPLATE_VMID}"

# ---- Create the template (remote) ----
echo "==> Creating DB template $TEMPLATE_VMID ($NAME) on $HOST_DEFAULT..."
# shellcheck disable=SC2087
ssh $SSH_OPTS "$SYSUSER@$HOST_DEFAULT" bash -s <<REMOTE
	set -euo pipefail

	step() { echo ""; echo "==> \$*"; }

	step "Download cloud image"
	if [ ! -f "$IMAGE_FILE" ]; then
		wget "$IMAGE_URL"
	else
		echo "  — already downloaded, reusing"
	fi

	step "Create VM $TEMPLATE_VMID"
	sudo qm create $TEMPLATE_VMID \
		--memory 4096 \
		--cores 2 \
		--cpu x86-64-v2-AES \
		--net0 virtio,bridge=$BRIDGE \
		--name $NAME

	step "Import disk"
	sudo qm importdisk $TEMPLATE_VMID "$IMAGE_FILE" $STORAGE

	step "Attach disk"
	sudo qm set $TEMPLATE_VMID --scsihw virtio-scsi-pci --scsi0 ${STORAGE}:vm-${TEMPLATE_VMID}-disk-0

	step "Resize disk to 64G"
	sudo qm resize $TEMPLATE_VMID scsi0 64G

	step "Attach cloud-init drive"
	sudo qm set $TEMPLATE_VMID --ide2 ${STORAGE}:cloudinit

	step "Set boot order"
	sudo qm set $TEMPLATE_VMID --boot order=scsi0

	step "Configure cloud-init defaults"
	sudo qm set $TEMPLATE_VMID \
		--ciuser wywy \
		--sshkeys /home/wywy/.ssh/authorized_keys \
		--ipconfig0 ip=dhcp

	step "Convert to template"
	sudo qm template $TEMPLATE_VMID

	echo ""
	echo "  ✓ DB template $TEMPLATE_VMID ready on $HOST_DEFAULT"
REMOTE

echo "  OK"
