#!/usr/bin/env bash
#
# Create the Debian cloud-init template for the dedicated Postgres DB VM on
# the DB hypervisor, and push the DB cloud-init snippet to that host.
#
# One template + one snippet per environment (prod/dev), each on its own
# hypervisor. The template itself gets NO --cicustom: the DB template VMID is
# shared with the k8s worker flow (2501 + host index), so baking the DB
# snippet into the template would leak it into worker clones. The DB snippet
# is applied to each clone by vm/db/create-vm.sh.
#
# Usage:
#   scripts/proxmox/vm/db/create-template.sh [--dev|--prod] <image-url>
#
# --dev|--prod selects the .env.network group (default: --prod):
#   prod → DATABASE_TEMPLATE_VMID on DATABASE_PROXMOX_HOST
#   dev  → DEV_DATABASE_TEMPLATE_VMID on DEV_DATABASE_PROXMOX_HOST
#
# Example:
#   scripts/proxmox/vm/db/create-template.sh --dev \
#     https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2
#
# Requires config/.env.network with K8S_POD_CIDR and the DB VM group defined
# (see vm/db/create-vm.sh).
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CLOUD_INIT_DIR="$SCRIPT_DIR/../cloud-init"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ENV_NETWORK="$CONTROL_DIR/config/.env.network"
SYSUSER="wywy"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o BatchMode=yes"
STORAGE="data"
BRIDGE="vmbr0"
IMAGE_FILE="debian-13-generic-amd64.qcow2"
SNIPPET="database-vm.yaml"

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

# Variable group selected by mode (prod keeps the DATABASE_* names).
VP="DATABASE"
[ "$MODE" = "dev" ] && VP="DEV_DATABASE"

# ---- Image URL is required ----
IMAGE_URL="${1:-}"
case "$IMAGE_URL" in
--* | '')
	echo "Usage: $0 [--dev|--prod] <image-url>" >&2
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

# ---- Guards: every required variable must be non-empty ----
for var in K8S_POD_CIDR "${VP}_PROXMOX_HOST" "${VP}_TEMPLATE_VMID"; do
	: "${!var:?$var not set in config/.env.network}"
done

# ---- Load the selected .env.network group ----
HOST_DEFAULT="${VP}_PROXMOX_HOST"
HOST_DEFAULT="${!HOST_DEFAULT}"
TEMPLATE_VMID="${VP}_TEMPLATE_VMID"
TEMPLATE_VMID="${!TEMPLATE_VMID}"

NAME="debian-13-db-template-${TEMPLATE_VMID}"

# ---- Validate input files ----
DB_TEMPLATE="$CLOUD_INIT_DIR/database-vm.yaml.template"
DB_BOOTSTRAP="$CLOUD_INIT_DIR/db-bootstrap.sh"
for f in "$DB_TEMPLATE" "$DB_BOOTSTRAP"; do
	[[ -f "$f" ]] || {
		echo "Error: $f not found" >&2
		exit 1
	}
done

# ---- Fetch the PGDG signing key (pinned fingerprint, not the keyserver pool) ----
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# The keyserver pool has served a fake key colliding with the PGDG short ID
# ACCC4CF8 — fetch from postgresql.org and pin the full fingerprint instead
# (160-bit fingerprints cannot collide).
PGDG_KEY_URL="https://www.postgresql.org/media/keys/ACCC4CF8.asc"
PGDG_KEY_FPR="B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8"

for cmd in curl gpg; do
	command -v "$cmd" >/dev/null 2>&1 || {
		echo "Error: '$cmd' is required to fetch/validate the PGDG key" >&2
		exit 1
	}
done

curl -fsSL --retry 5 --retry-delay 5 "$PGDG_KEY_URL" -o "$TMP_DIR/pgdg.asc"
PGDG_KEY_ACTUAL_FPR="$(
	gpg --show-keys --with-colons "$TMP_DIR/pgdg.asc" 2>/dev/null |
		awk -F: '$1 == "fpr" { print $10; exit }'
)"
[[ -n "$PGDG_KEY_ACTUAL_FPR" && "$PGDG_KEY_ACTUAL_FPR" == "$PGDG_KEY_FPR" ]] || {
	echo "FATAL: PGDG key fingerprint mismatch" >&2
	echo "  got:  ${PGDG_KEY_ACTUAL_FPR:-<none>}" >&2
	echo "  want: $PGDG_KEY_FPR" >&2
	exit 1
}
echo "  -> PGDG key fetched and validated ($PGDG_KEY_FPR)"

# ---- Render the DB cloud-init snippet (pod CIDR → bootstrap → key → base64) ----
sed -e "s|{{K8S_POD_CIDR}}|$K8S_POD_CIDR|g" \
	"$DB_BOOTSTRAP" >"$TMP_DIR/db-bootstrap-rendered.sh"

BOOTSTRAP_B64=$(base64 -w0 <"$TMP_DIR/db-bootstrap-rendered.sh")
PGDG_KEY_B64="$(gpg --dearmor <"$TMP_DIR/pgdg.asc" | base64 -w0)"

sed -e "s|{{BOOTSTRAP_B64}}|$BOOTSTRAP_B64|g" \
	-e "s|{{PGDG_KEY_B64}}|$PGDG_KEY_B64|g" \
	"$DB_TEMPLATE" >"$TMP_DIR/$SNIPPET"

# Fail if any placeholder survived the render.
if grep -q "{{" "$TMP_DIR/$SNIPPET"; then
	echo "FATAL: leftover placeholder in rendered snippet:" >&2
	grep -n "{{" "$TMP_DIR/$SNIPPET" >&2
	exit 1
fi

echo "==> Pushing DB snippet to $SYSUSER@$HOST_DEFAULT..."
scp $SSH_OPTS "$TMP_DIR/$SNIPPET" "$SYSUSER@$HOST_DEFAULT:~/$SNIPPET"

# ---- Create template + install snippet (remote) ----
echo "==> Creating DB template $TEMPLATE_VMID ($NAME) on $HOST_DEFAULT..."
# shellcheck disable=SC2087
ssh $SSH_OPTS "$SYSUSER@$HOST_DEFAULT" bash -s <<REMOTE
	set -euo pipefail

	step() { echo ""; echo "==> \$*"; }

	step "Install DB snippet to /var/lib/vz/snippets/"
	sudo cp ~/$SNIPPET /var/lib/vz/snippets/$SNIPPET
	rm -f ~/$SNIPPET

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
