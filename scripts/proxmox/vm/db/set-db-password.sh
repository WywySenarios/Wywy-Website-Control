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
# --dev|--prod is REQUIRED: it selects the sops file and hosts file mode.
# The DB VM IP comes from the encrypted hosts file (hosts_ip_real
# db.internal) — no CLI overrides, so there is a single source of truth and
# nothing to mismatch.
#
# Requires: SSH key auth to wywy@<vm-ip>, passwordless sudo for postgres,
#           sops + age key configured (see docs/sops-setup.mdx).

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
SYSUSER="wywy"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o BatchMode=yes"

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

# ---- DB VM IP from the encrypted hosts file (single source) ----
HOSTS_MODE="${MODE#--}"
# shellcheck source=../../../lib/hosts.sh
source "$CONTROL_DIR/scripts/lib/hosts.sh"
DB_IP="$(hosts_ip_real db.internal)"

PASSWORD_SOPS_REL="secrets/prod/postgres-password.sops.yaml"
[ "$MODE" = "--dev" ] && PASSWORD_SOPS_REL="secrets/dev/postgres-password.sops.yaml"

# Human-readable target for output; the IP itself is an implementation detail.
DB_LABEL="production database"
[ "$MODE" = "--dev" ] && DB_LABEL="development database"

command -v sops >/dev/null 2>&1 || {
	echo "Error: sops not found in PATH (see docs/sops-setup.mdx)" >&2
	exit 1
}

# ---- Prompt for the password (hidden; never on a command line) ----
read -rsp "postgres password for $DB_LABEL: " PASSWORD
echo
if [ -z "$PASSWORD" ]; then
	echo "Error: empty password" >&2
	exit 1
fi

# ---- 1. Set on the DB VM: SQL over ssh stdin, never argv/history ----
# Doubling single quotes is the only escaping needed in a SQL string literal.
SQL_PASSWORD="${PASSWORD//\'/\'\'}"
echo "==> Setting postgres password on $DB_LABEL..."
printf "ALTER USER postgres PASSWORD '%s';\n" "$SQL_PASSWORD" |
	ssh $SSH_OPTS "$SYSUSER@$DB_IP" "sudo -u postgres psql -v ON_ERROR_STOP=1"

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

echo "==> Done."
