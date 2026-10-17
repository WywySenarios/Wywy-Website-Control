#!/usr/bin/env bash
#
# Provision a dedicated Postgres VM by cloning the DB template on a Proxmox
# host. The VM runs postgres directly (not in K8s), on the same LAN as the
# K8s workers so pods can reach it via the pod CIDR.
#
# Usage:
#   scripts/proxmox/vm/db/create-vm.sh --dev|--prod
#
# --dev|--prod is REQUIRED and selects the .env.network group:
#   prod → DATABASE_TEMPLATE_VMID, DATABASE_PROXMOX_HOST, DATABASE_VMID
#   dev  → DEV_DATABASE_*
#
# The DB VM IP, gateway and nameserver come from the encrypted hosts file; the
# pod CIDR and worker list are owned by the Ansible `postgres` role. No network
# topology lives in .env.network any more.
#
# The clone gets NO --cicustom: cloud-init only hands over the user/SSH key and
# the network from the template defaults. Postgres is installed and configured
# on the clone by the Ansible `postgres` role (see the post-bootstrap steps).
#
# Examples:
#   scripts/proxmox/vm/db/create-vm.sh --prod
#   scripts/proxmox/vm/db/create-vm.sh --dev
#
# Dependencies:
#   - DB template at VMID {DEV_,}DATABASE_TEMPLATE_VMID (vm/db/create-template.sh)
#   - SSH key-based auth to wywy@<proxmox-host>
#
# Post-bootstrap — run these in order once the VM is up:
#   1. scripts/proxmox/vm/db/set-db-password.sh --dev|--prod
#   2. ANSIBLE_CONFIG=ansible/ansible.cfg \
#        uv run --project ansible ansible-playbook \
#        -i ansible/inventory/<env> ansible/playbooks/db/db.yaml
#   Set the password first: the Ansible role must not race package installation.
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ENV_NETWORK="$CONTROL_DIR/config/.env.network"
SYSUSER="wywy"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o BatchMode=yes"

# ---- Source network config ----
[[ -f "$ENV_NETWORK" ]] || {
	echo "Error: $ENV_NETWORK not found" >&2
	echo "Copy config/.env.network.example to config/.env.network and fill in your values." >&2
	exit 1
}
# shellcheck disable=SC1090
source "$ENV_NETWORK"

# ---- Parse mode: --dev|--prod (required) ----
MODE="${1:-}"
case "$MODE" in
--dev) MODE="dev" ;;
--prod) MODE="prod" ;;
*)
	echo "Error: first argument must be --dev or --prod (got '${MODE:-<none>}')" >&2
	echo "Usage: scripts/proxmox/vm/db/create-vm.sh --dev|--prod" >&2
	exit 1
	;;
esac

# ---- DB VM IP + gateway/nameserver from the encrypted hosts file ----
HOSTS_MODE="$MODE"
# shellcheck source=../../../lib/hosts.sh
source "$CONTROL_DIR/scripts/lib/hosts.sh"
DB_IP="$(hosts_ip_real db.internal)"
GATEWAY="$(hosts_ip_real gateway.internal)"
NAMESERVER="$(hosts_ip_real nameserver.internal)"

# Variable group selected by mode (prod keeps the DATABASE_* names).
VP="DATABASE"
[ "$MODE" = "dev" ] && VP="DEV_DATABASE"

# ---- Guards: every required variable must be non-empty ----
# (The operator below expands $X then runs : which is a no-op, so if it
#  fails, the whole script stops.  This is the same as an || exit but
#  preserves set -e semantics for the rest of the script.)
for var in "${VP}_PROXMOX_HOST" "${VP}_TEMPLATE_VMID" "${VP}_VMID"; do
	: "${!var:?$var not set in config/.env.network}"
done

# ---- Load the selected .env.network group ----
HOST="${VP}_PROXMOX_HOST"
HOST="${!HOST}"
TEMPLATE_VMID="${VP}_TEMPLATE_VMID"
TEMPLATE_VMID="${!TEMPLATE_VMID}"
VMID="${VP}_VMID"
VMID="${!VMID}"

CIDR="${DB_IP}/24"
NAME="database-vm-${MODE}"

# ---- Provision VM ----
echo "==> Provisioning $NAME (VM $VMID → $DB_IP on $HOST)..."
ssh $SSH_OPTS "$SYSUSER@$HOST" bash -s <<REMOTE
	set -euo pipefail

	echo "  -> Cloning template $TEMPLATE_VMID → $VMID..."
	sudo qm clone $TEMPLATE_VMID $VMID --name "$NAME"

	echo "  -> Configuring VM..."
	sudo qm set $VMID \
		--ipconfig0 "ip=$CIDR,gw=$GATEWAY" \
		--nameserver "$NAMESERVER"

	echo "  -> Resizing disk (+50G)..."
	sudo qm resize $VMID scsi0 +50G

	echo "  -> Starting VM..."
	sudo qm start $VMID

	echo ""
	echo "  ✓ DB VM $NAME (VM $VMID) started at $DB_IP on $HOST"
REMOTE

# ---- Wait for the VM to be reachable and cloud-init to finish ----
echo "==> Waiting for $DB_IP to accept SSH..."
for _ in $(seq 1 60); do
	ssh $SSH_OPTS "$SYSUSER@$DB_IP" true >/dev/null 2>&1 && break
	sleep 5
done
ssh $SSH_OPTS "$SYSUSER@$DB_IP" true >/dev/null 2>&1 || {
	echo "Error: $DB_IP is not reachable over SSH (after ~5 min)" >&2
	exit 1
}

echo "==> Waiting for cloud-init on $DB_IP (installs postgresql/ufw)..."
ssh $SSH_OPTS "$SYSUSER@$DB_IP" "cloud-init status --wait" >/dev/null || {
	echo "Error: cloud-init did not complete cleanly on $DB_IP" >&2
	exit 1
}

echo ""
echo "==> Done. Next steps (in order):"
echo "    1. scripts/proxmox/vm/db/set-db-password.sh --$MODE"
echo "    2. ANSIBLE_CONFIG=ansible/ansible.cfg \\"
echo "         uv run --project ansible ansible-playbook \\"
echo "         -i ansible/inventory/$MODE ansible/playbooks/db/db.yaml"
