#!/usr/bin/env bash
# Idempotent database bootstrap script. This script is a wrapper for init-rbac.sql.
#
# This script can ONLY be run manually. This script is not continuously delivered. This script is not run by cloud-init.
#
# Idempotent
#
# Usage:
#   scripts/proxmox/vm/db/init-rbac.sh --dev|--prod
#
# Secrets:
#  * k8s/{dev,prod}/master-database/secrets/migrator-password.sops.yaml
#  * k8s/{dev,prod}/master-database/secrets/app-password.sops.yaml
#
# The k8s-side Secret manifests are the single source of truth (ksops renders
# them into the cluster); this script decrypts the same files for the VM
# bootstrap. There is no separate bare-secrets copy.
#
# Prerequisites:
#   - the two aforementioned secrets
#   - sops + the age key on the operator host
#   - SSH key auth to wywy@<db-vm>
#   - database DNS (i.e. you already installed the other parts of the database)
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
SQL_FILE="$SCRIPT_DIR/init-rbac.sql"
SYSUSER="wywy"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o BatchMode=yes"
REMOTE_DIR="/tmp/init-rbac.$$"

# ---- Output helpers ----
# shellcheck source=../../../lib/output.sh
source "$CONTROL_DIR/scripts/lib/output.sh"

die() {
	error "Error: $*"
	exit 1
}

log() {
	header "$*"
}

MODE="${1:-}"
case "$MODE" in
--dev | --prod) ;;
*)
	error "Usage: scripts/proxmox/vm/db/init-rbac.sh --dev|--prod"
	exit 1
	;;
esac

HOSTS_MODE="${MODE#--}"
source "$CONTROL_DIR/scripts/lib/hosts.sh"
DB_IP="$(hosts_ip_real db.internal)"

DB_LABEL="production database"
MIGRATOR_SOPS="$CONTROL_DIR/k8s/prod/master-database/secrets/migrator-password.sops.yaml"
APP_SOPS="$CONTROL_DIR/k8s/prod/master-database/secrets/app-password.sops.yaml"
if [ "$MODE" = "--dev" ]; then
	DB_LABEL="development database"
	MIGRATOR_SOPS="$CONTROL_DIR/k8s/dev/master-database/secrets/migrator-password.sops.yaml"
	APP_SOPS="$CONTROL_DIR/k8s/dev/master-database/secrets/app-password.sops.yaml"
fi

# ---- Preflight ----
[ -f "$SQL_FILE" ] || die "missing $SQL_FILE (the bootstrap SQL lives next to this script)"
command -v sops >/dev/null 2>&1 || die "sops is not installed"
command -v sudo >/dev/null 2>&1 || die "sudo is required"
[ -f "$MIGRATOR_SOPS" ] || die "missing $MIGRATOR_SOPS. encrypt the migrator password first"
[ -f "$APP_SOPS" ] || die "missing $APP_SOPS. encrypt the app password first"

decrypt_password() {
	sudo sops -d --extract '["stringData"]["password"]' "$1"
}

cleanup() {
	if ! ssh $SSH_OPTS "$SYSUSER@$DB_IP" "rm -rf '$REMOTE_DIR'" 2>&1; then
		error "ERROR: cleanup failed. WARNING: plaintext passwords may remain in $REMOTE_DIR on $DB_IP"
	fi
}
trap cleanup EXIT

# ---- Push the passwords to the VM as files ----
log "Copying passwords to $DB_LABEL ($DB_IP)"
ssh $SSH_OPTS "$SYSUSER@$DB_IP" "rm -rf '$REMOTE_DIR' && mkdir -p '$REMOTE_DIR'"
decrypt_password "$MIGRATOR_SOPS" | ssh $SSH_OPTS "$SYSUSER@$DB_IP" "cat > '$REMOTE_DIR/master_db_migrator_pw'"
decrypt_password "$APP_SOPS" | ssh $SSH_OPTS "$SYSUSER@$DB_IP" "cat > '$REMOTE_DIR/master_db_app_pw'"
# postgres user must be able to read the password files.
ssh $SSH_OPTS "$SYSUSER@$DB_IP" "chmod 755 '$REMOTE_DIR' && chmod 644 '$REMOTE_DIR'/master_db_migrator_pw '$REMOTE_DIR'/master_db_app_pw"

# ---- Stream the SQL to psql on the VM ----
log "Applying roles, databases, and extensions on $DB_LABEL ($DB_IP)"
{
	printf '\\set master_db_migrator_pw `cat %s/master_db_migrator_pw`\n\\set master_db_app_pw `cat %s/master_db_app_pw`\n' \
		"$REMOTE_DIR" "$REMOTE_DIR"
	cat "$SQL_FILE"
} | ssh $SSH_OPTS "$SYSUSER@$DB_IP" "sudo -u postgres psql -v ON_ERROR_STOP=1"

log "Done: $DB_LABEL bootstrap is in place"
