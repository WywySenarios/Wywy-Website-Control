#!/usr/bin/env bash
#
# Provision a dedicated Postgres VM by cloning the DB template on a Proxmox
# host. The VM runs postgres directly (not in K8s), on the same LAN as the
# K8s workers so pods can reach it via the pod CIDR.
#
# Usage:
#   scripts/proxmox/vm/db/create-vm.sh [--dev|--prod]
#
# --dev|--prod selects the .env.network group (default: --prod):
#   prod → DATABASE_*       (requires GATEWAY, NAMESERVER, K8S_POD_CIDR,
#                             DATABASE_TEMPLATE_VMID, DATABASE_PROXMOX_HOST,
#                             DATABASE_IP, DATABASE_VMID)
#   dev  → DEV_DATABASE_*
# The K8s pod CIDR (ufw allow on 5432/tcp) is baked into the cloud-init
# snippet by vm/db/create-template.sh from K8S_POD_CIDR — the same variable
# kubeadm init uses (scripts/install/k8s/k8s-base.sh).
# The proxmox host and static IP always come from .env.network — no CLI
# overrides, so there is a single source of truth and nothing to mismatch.
#
# The cloud-init snippet (database-vm.yaml) is rendered and pushed to the host
# by vm/db/create-template.sh — run it first. This script verifies the snippet
# is on the host before cloning.
#
# Examples:
#   scripts/proxmox/vm/db/create-vm.sh --prod                          # prod VM via .env.network
#   scripts/proxmox/vm/db/create-vm.sh --dev                           # dev VM via .env.network
#
# Dependencies:
#   - DB template at VMID specified by {DEV,}DATABASE_TEMPLATE_VMID (vm/db/create-template.sh)
#   - SSH key-based auth to wywy@<proxmox-host>
#
# Post-bootstrap:
#   The VM comes up with postgres running but no password set.
#   After the VM boots, set the password and encrypt it into the sops file
#   with scripts/proxmox/vm/db/set-db-password.sh --dev|--prod — it prompts
#   for the password interactively (read -rs) and never puts it on a command
#   line, so it can't leak into bash_history or process listings.
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ENV_NETWORK="$CONTROL_DIR/config/.env.network"
SYSUSER="wywy"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o BatchMode=yes"
SNIPPET="database-vm.yaml"

# ---- Source network config ----
[[ -f "$ENV_NETWORK" ]] || {
	echo "Error: $ENV_NETWORK not found" >&2
	echo "Copy config/.env.network.example to config/.env.network and fill in your values." >&2
	exit 1
}
# shellcheck disable=SC1090
source "$ENV_NETWORK"

# ---- Parse mode: --dev|--prod (default prod) ----
MODE="prod"
case "${1:-}" in
--dev)
	MODE="dev"
	shift
	;;
--prod)
	MODE="prod"
	shift
	;;
*) ;;
esac

# ---- Sops file per environment (dev and prod passwords differ) ----
PASSWORD_SOPS_REL="secrets/prod/postgres-password.sops"
[ "$MODE" = "dev" ] && PASSWORD_SOPS_REL="secrets/dev/postgres-password.sops"

# Variable group selected by mode (prod keeps the DATABASE_* names).
VP="DATABASE"
[ "$MODE" = "dev" ] && VP="DEV_DATABASE"

# ---- Guards: every required variable must be non-empty ----
# (The operator below expands $X then runs : which is a no-op, so if it
#  fails, the whole script stops.  This is the same as an || exit but
#  preserves set -e semantics for the rest of the script.)
for var in GATEWAY NAMESERVER K8S_POD_CIDR \
	"${VP}_PROXMOX_HOST" "${VP}_IP" \
	"${VP}_TEMPLATE_VMID" "${VP}_VMID"; do
	: "${!var:?$var not set in config/.env.network}"
done

# ---- Load the selected .env.network group (single source of truth) ----
HOST="${VP}_PROXMOX_HOST"
HOST="${!HOST}"
IP="${VP}_IP"
IP="${!IP}"
TEMPLATE_VMID="${VP}_TEMPLATE_VMID"
TEMPLATE_VMID="${!TEMPLATE_VMID}"
VMID="${VP}_VMID"
VMID="${!VMID}"

CIDR="${IP}/24"
NAME="database-vm-${MODE}"

# ---- Verify the cloud-init snippet is on the host (create-template.sh pushed it) ----
if ! ssh $SSH_OPTS "$SYSUSER@$HOST" "test -f /var/lib/vz/snippets/$SNIPPET"; then
	echo "Error: $SNIPPET not found on $HOST" >&2
	echo "Run scripts/proxmox/vm/db/create-template.sh --$MODE <image-url> first to push it." >&2
	exit 1
fi

# ---- Provision VM ----
echo "==> Provisioning $NAME (VM $VMID → $IP on $HOST)..."
ssh $SSH_OPTS "$SYSUSER@$HOST" bash -s <<REMOTE
	set -euo pipefail

	echo "  -> Cloning template $TEMPLATE_VMID → $VMID..."
	sudo qm clone $TEMPLATE_VMID $VMID --name "$NAME"

	echo "  -> Configuring VM..."
	sudo qm set $VMID \
		--ipconfig0 "ip=$CIDR,gw=$GATEWAY" \
		--nameserver "$NAMESERVER" \
		--cicustom "vendor=local:snippets/$SNIPPET"

	echo "  -> Resizing disk (+50G)..."
	sudo qm resize $VMID scsi0 +50G

	echo "  -> Starting VM..."
	sudo qm start $VMID

	echo ""
	echo "  ✓ DB VM $NAME (VM $VMID) started at $IP on $HOST"
REMOTE

echo ""
echo "==> Done."
