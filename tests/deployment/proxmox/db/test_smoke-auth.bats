#!/usr/bin/env bats
# Deployment test: quick postgres password check over the VM loopback.
#
# Connects to the dev DB VM via ssh and runs psql over TCP to 127.0.0.1 with
# the password from secrets/dev/postgres-password.sops. Verifies the password
# itself (scram over TCP) WITHOUT the cluster — use this to rule the DB VM in
# or out, then use test_pod-auth.bats for the full pod → ufw → DB path.
#
# Runs as the invoking user; only the sops decrypt needs root (root owns the
# age key at /root/.config/sops/age/keys.txt), so it uses sudo per command.
#
# Dev only — tests never run against prod.
#
# Prerequisites:
#   - ssh key auth from the invoking user to wywy@<DB_IP> (VMs are provisioned
#     with --ciuser wywy and the user's authorized_keys)
#   - root owns the sops age key
#   - config/.env.network with DEV_DATABASE_IP
#   - postgres password set on the server to match the sops value

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BATS_TEST_FILENAME}")")" && pwd)"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ENV_NETWORK="$CONTROL_DIR/config/.env.network"
SECRETS_DIR="$CONTROL_DIR/secrets"
PASSWORD_SOPS="$SECRETS_DIR/dev/postgres-password.sops"
SYSUSER="wywy"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o BatchMode=yes"

setup() {
    # shellcheck disable=SC1090
    source "$ENV_NETWORK" 2>/dev/null || skip "config/.env.network not found — copy .env.network.example"
    DB_IP="${DEV_DATABASE_IP:-}"
    [[ -n "$DB_IP" ]] || skip "DEV_DATABASE_IP not set in config/.env.network"
    [[ -f "$PASSWORD_SOPS" ]] || skip "secrets/dev/postgres-password.sops not found"
    PGPASSWORD="$(sudo sops --decrypt "$PASSWORD_SOPS")" || fail "failed to decrypt secrets/dev/postgres-password.sops"
    [[ -n "$PGPASSWORD" ]] || fail "secrets/dev/postgres-password.sops decrypted to an empty value"
}

@test "smoke auth: sops password can login to database via 127.0.0.1 loopback" {
    echo "==> Smoke test: sops password can login to database via 127.0.0.1 loopback."
    if ! ssh $SSH_OPTS "$SYSUSER@$DB_IP" bash -s <<REMOTE; then
        set -euo pipefail
        PGPASSWORD='$PGPASSWORD' psql -h 127.0.0.1 -U postgres -d postgres -w -c "select 1"
REMOTE
        echo ""
        echo "FATAL: smoke auth test failed — password mismatch or server not ready on $DB_IP" >&2
        echo "       Fix it safely with: scripts/proxmox/vm/db/set-db-password.sh --dev" >&2
        echo "       (prompts interactively — never put the password on a command line or in PGPASSWORD=...)" >&2
        fail "smoke auth failed on $DB_IP"
    fi
    echo "==> OK: postgres password verified on $DB_IP (loopback)"
}
