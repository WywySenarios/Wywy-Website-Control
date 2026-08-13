#!/usr/bin/env bash
#
# update-pg-hba.sh — deploy pg_hba.conf + ufw worker rules to the DB VM.
#
# Renders config/db/pg_hba.conf with the CURRENT config/.env.network values
# and pushes it to the DB VM as /etc/postgresql/18/main/pg_hba.conf, then:
#   - allows the mode's worker IPs through ufw on 5432/tcp
#   - reloads postgres and validates the file via pg_hba_file_rules
#
# This is intentionally re-runnable: cloud-init bakes pg_hba only at first
# boot, so .env.network changes (new workers, new pod CIDR) are applied by
# re-running this script against a running VM.
#
# Background: Calico masquerades pod -> LAN traffic to the node IP
# (natOutgoing: true), so the DB VM sees the worker IP, never the pod CIDR.
# ufw is the coarse gate, pg_hba the precise gate; both must list the
# workers. The bootstrap's pod-CIDR ufw rule is kept as a safety net but
# never matches masqueraded traffic.
#
# Usage:
#   scripts/proxmox/vm/db/update-pg-hba.sh --dev|--prod
#
# Prerequisites:
#   - config/.env.network with K8S_POD_CIDR, the worker IP list, and the DB
#     VM group (DATABASE_IP / DEV_DATABASE_IP, etc.)
#   - ssh key for wywy@<db-ip>; wywy has passwordless sudo
#   - ssh, scp, awk
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ENV_NETWORK="$CONTROL_DIR/config/.env.network"
PG_HBA_TEMPLATE="$CONTROL_DIR/config/db/pg_hba.conf"
PG_HBA_REMOTE="/etc/postgresql/18/main/pg_hba.conf"
SYSUSER="wywy"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o BatchMode=yes"

# --- Mode is required: --dev|--prod (dashes are stripped for group selection) ---
MODE="${1:-}"
case "$MODE" in
--dev)
	MODE="dev"
	;;
--prod)
	MODE="prod"
	;;
*)
	echo "Usage: $0 --dev|--prod" >&2
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

# ---- Load the selected .env.network group ----
VP="DATABASE"
[ "$MODE" = "dev" ] && VP="DEV_DATABASE"
IP_VAR="${VP}_IP"
DB_IP="${!IP_VAR:-}"
: "${DB_IP:?$IP_VAR not set in config/.env.network}"
: "${K8S_POD_CIDR:?K8S_POD_CIDR not set in config/.env.network}"

# Worker IP list for this mode (DEV_K8S_WORKER_IPS / K8S_WORKER_IPS).
WP=""
[ "$MODE" = "dev" ] && WP="DEV_"
WORKERS_VAR="${WP}K8S_WORKER_IPS"
WORKERS="${!WORKERS_VAR:-}"
: "${WORKERS:?$WORKERS_VAR not set in config/.env.network}"

# ---- Validate inputs ----
[[ -f "$PG_HBA_TEMPLATE" ]] || {
	echo "Error: $PG_HBA_TEMPLATE not found" >&2
	exit 1
}
for cmd in ssh scp awk; do
	command -v "$cmd" >/dev/null 2>&1 || {
		echo "Error: '$cmd' is required" >&2
		exit 1
	}
done

# ---- Render the template with current .env.network values ----
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Expand the comma-separated worker list into pg_hba host lines.
WORKER_BLOCK=""
IFS=',' read -r -a WORKER_IPS <<<"$WORKERS"
for ip in "${WORKER_IPS[@]}"; do
	ip="${ip//[[:space:]]/}"
	[[ -n "$ip" ]] || continue
	WORKER_BLOCK+="host    all             all             ${ip}/32                 scram-sha-256"$'\n'
done
[[ -n "$WORKER_BLOCK" ]] || {
	echo "Error: $WORKERS_VAR contains no usable IPs" >&2
	exit 1
}

RENDERED="$TMP_DIR/pg_hba.conf"
# Comment-aware render: {{NAME}} is substituted on rule lines only; comment
# lines (starting with #) pass through untouched. Comments reference
# placeholders as <NAME>, which never matches the {{NAME}} tokens.
awk -v block="$WORKER_BLOCK" -v pod="$K8S_POD_CIDR" '
	/^[[:space:]]*#/ { print; next }
	/\{\{K8S_WORKER_IPS\}\}/ { printf "%s", block; next }
	{ gsub(/\{\{K8S_POD_CIDR\}\}/, pod) }
	{ print }
' "$PG_HBA_TEMPLATE" >"$RENDERED"

# Fail on any leftover {{ placeholder on a rule line (comments exempt).
if grep -v '^[[:space:]]*#' "$RENDERED" | grep -q '{{'; then
	echo "FATAL: leftover placeholder in rendered pg_hba.conf:" >&2
	grep -v '^[[:space:]]*#' "$RENDERED" | grep -n '{{' >&2
	exit 1
fi

echo "==> Rendered pg_hba.conf for $MODE (DB VM $DB_IP):"
echo ""
cat "$RENDERED"
echo ""

# ---- Push the rendered file to the DB VM ----
echo "==> Pushing pg_hba.conf to $SYSUSER@$DB_IP..."
scp $SSH_OPTS "$RENDERED" "$SYSUSER@$DB_IP:/tmp/pg_hba.conf.new"

# ---- Install, open ufw for the workers, reload + validate ----
echo "==> Installing on $DB_IP (ufw + pg_hba + reload)..."
# shellcheck disable=SC2087
ssh $SSH_OPTS "$SYSUSER@$DB_IP" bash -s <<REMOTE
	set -euo pipefail

	echo "--- ufw: allowing workers on 5432/tcp"
	$(for ip in "${WORKER_IPS[@]}"; do
	echo "sudo ufw allow from $ip to any port 5432 proto tcp >/dev/null"
done)
	sudo ufw status | grep 5432 || true

	echo "--- installing pg_hba.conf"
	sudo install -o root -g postgres -m 640 /tmp/pg_hba.conf.new $PG_HBA_REMOTE
	rm -f /tmp/pg_hba.conf.new

	echo "--- reloading postgres"
	sudo -u postgres psql -v ON_ERROR_STOP=1 -Atc "SELECT pg_reload_conf()" >/dev/null

	echo "--- validating via pg_hba_file_rules"
	ERRORS="\$(sudo -u postgres psql -v ON_ERROR_STOP=1 -Atc \
		"SELECT line_number || ': ' || error FROM pg_hba_file_rules WHERE error IS NOT NULL")"
	if [[ -n "\$ERRORS" ]]; then
		echo "FATAL: pg_hba.conf has parse errors:" >&2
		echo "\$ERRORS" >&2
		exit 1
	fi
	echo "  -> pg_hba.conf valid, postgres reloaded"
REMOTE

echo ""
echo "==> OK: $MODE DB VM ($DB_IP) pg_hba.conf and ufw are current."
echo "    Verify end-to-end (dev only): ./test.sh deployment"
