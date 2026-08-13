#!/usr/bin/env bash
#
# Set the postgres superuser password on the DB VM and encrypt it into the
# matching sops file — WITHOUT ever placing the password on a command line.
#
# The password is only ever read from the terminal (read -rs, hidden input)
# and transported via stdin:
#   - the ALTER USER SQL is piped to ssh -> psql on the VM
#   - the raw value is piped to sops
# It never appears in bash_history, in /proc/<pid>/cmdline, or in a process
# listing (printf is a bash builtin, so its arguments are not exec'd argv).
#
# Usage:
#   scripts/proxmox/vm/db/set-db-password.sh --dev|--prod
#
# --dev|--prod is REQUIRED: it selects the .env.network group and sops file.
# The DB VM IP always comes from .env.network ({DEV_,}DATABASE_IP) — no CLI
# overrides, so there is a single source of truth and nothing to mismatch.
#
# Requires: SSH key auth to wywy@<vm-ip>, passwordless sudo for postgres,
#           sops + age key configured (see docs/sops-setup.mdx).

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ENV_NETWORK="$CONTROL_DIR/config/.env.network"
SYSUSER="wywy"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o BatchMode=yes"

[[ -f "$ENV_NETWORK" ]] || {
	echo "Error: $ENV_NETWORK not found (copy config/.env.network.example)" >&2
	exit 1
}
# shellcheck disable=SC1090
source "$ENV_NETWORK"

# ---- Parse mode (--dev|--prod REQUIRED — fail fast on anything else) ----
MODE="${1:-}"
case "$MODE" in
--dev | --prod)
	shift
	;;
*)
	echo "Error: first argument must be --dev or --prod (got '${MODE:-<none>}')" >&2
	echo "Usage: scripts/proxmox/vm/db/set-db-password.sh --dev|--prod" >&2
	exit 1
	;;
esac

VP="DATABASE"
[ "$MODE" = "dev" ] && VP="DEV_DATABASE"

PASSWORD_SOPS_REL="secrets/prod/postgres-password.sops"
[ "$MODE" = "dev" ] && PASSWORD_SOPS_REL="secrets/dev/postgres-password.sops"

# ---- Guards ----
for var in "${VP}_IP"; do
	: "${!var:?$var not set in config/.env.network}"
done
IP_VAR="${VP}_IP"
IP="${!IP_VAR}"

command -v sops >/dev/null 2>&1 || {
	echo "Error: sops not found in PATH (see docs/sops-setup.mdx)" >&2
	exit 1
}

# ---- Prompt for the password (hidden; never on a command line) ----
read -rsp "postgres password for ${MODE}@${IP}: " PASSWORD
echo
if [ -z "$PASSWORD" ]; then
	echo "Error: empty password" >&2
	exit 1
fi

# ---- 1. Set on the DB VM: SQL over ssh stdin, never argv/history ----
# Doubling single quotes is the only escaping needed in a SQL string literal.
SQL_PASSWORD="${PASSWORD//\'/\'\'}"
echo "==> Setting postgres password on $SYSUSER@$IP..."
printf "ALTER USER postgres PASSWORD '%s';\n" "$SQL_PASSWORD" |
	ssh $SSH_OPTS "$SYSUSER@$IP" "sudo -u postgres psql -v ON_ERROR_STOP=1"

# ---- 2. Encrypt into sops: raw value via stdin, never argv/history ----
# Write to a temp file first, then mv into place: the `> target` redirect
# truncates before sops runs, so a failure would destroy the existing file.
echo "==> Writing $PASSWORD_SOPS_REL..."
TMP_SOPS="$(mktemp "$CONTROL_DIR/secrets/.tmp-password.XXXXXX")"
trap 'rm -f "$TMP_SOPS"' EXIT
printf '%s' "$PASSWORD" |
	sops --input-type raw --output-type raw --encrypt /dev/stdin \
		>"$TMP_SOPS"
[ -s "$TMP_SOPS" ] || {
	echo "Error: sops produced no output — $PASSWORD_SOPS_REL not updated" >&2
	exit 1
}
mv "$TMP_SOPS" "$CONTROL_DIR/$PASSWORD_SOPS_REL"

echo "==> Done. Next: scripts/init-k8s-secrets.sh"
