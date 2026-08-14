#!/usr/bin/env bats
# Deployment test: end-to-end postgres auth from inside the cluster using an
# ephemeral postgres pod.
#
# Validates that a k8s pod can reach the dev DB VM and authenticate with the
# password from secrets/dev/postgres-password.sops.yaml.
#
# Dev only — tests never run against prod.
#
# Prerequisites:
#   - kubectl configured for the invoking user
#   - config/.env.network with DEV_DATABASE_IP
#   - secrets/dev/postgres-password.sops.yaml (decrypt needs root — age key)
#   - postgres password set on the server to match the sops value

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BATS_TEST_FILENAME}")")" && pwd)"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ENV_NETWORK="$CONTROL_DIR/config/.env.network"
SECRETS_DIR="$CONTROL_DIR/secrets"
PASSWORD_SOPS="$SECRETS_DIR/dev/postgres-password.sops.yaml"
POD="pg-auth-test-$$"
IMAGE="postgres:18"

setup() {
    # shellcheck disable=SC1090
    source "$ENV_NETWORK" 2>/dev/null || skip "config/.env.network not found — copy .env.network.example"
    DB_IP="${DEV_DATABASE_IP:-}"
    [[ -n "$DB_IP" ]] || skip "DEV_DATABASE_IP not set in config/.env.network"
    [[ -f "$PASSWORD_SOPS" ]] || skip "secrets/dev/postgres-password.sops.yaml not found"
    PGPASSWORD="$(sudo sops --decrypt "$PASSWORD_SOPS")" || fail "failed to decrypt secrets/dev/postgres-password.sops.yaml"
    [[ -n "$PGPASSWORD" ]] || fail "secrets/dev/postgres-password.sops.yaml decrypted to an empty value"
    command -v kubectl >/dev/null 2>&1 || skip "kubectl not found"
    kubectl cluster-info >/dev/null 2>&1 || skip "kubectl cannot reach the cluster"
}

teardown() {
    kubectl delete pod "$POD" --ignore-not-found >/dev/null 2>&1 || true
}

@test "pod auth: postgres auth verified from pod -> dev DB VM" {
    echo "==> Testing postgres auth from a pod: psql -h $DB_IP -U postgres"
    echo "    pod: $POD"

    # kubectl run propagates the container exit code; guard it so a failing
    # test does not abort the test before the wait loop and diagnostics.
    # Never describe the pod: describe prints container env vars, which would
    # leak PGPASSWORD to the terminal. Events do not.
    kubectl run "$POD" \
        --image="$IMAGE" \
        --restart=Never \
        --env "PGPASSWORD=$PGPASSWORD" \
        --command -- \
        psql -h "$DB_IP" -U postgres -d postgres -w \
        -v ON_ERROR_STOP=1 -c "select 1" \
        || true

    PHASE=""
    for _ in $(seq 1 60); do
        PHASE="$(kubectl get pod "$POD" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
        [[ "$PHASE" == "Succeeded" || "$PHASE" == "Failed" ]] && break
        sleep 2
    done

    echo ""
    kubectl logs "$POD" 2>/dev/null || true
    echo ""

    if [[ "$PHASE" == "Succeeded" ]]; then
        echo "==> OK: postgres auth verified from pod -> $DB_IP"
        return 0
    fi

    # Failure: surface placement + events (no describe — password leak).
    {
        echo ""
        echo "--- pod placement (node / pod IP) ---"
        kubectl get pod "$POD" -o wide 2>/dev/null || true
        echo ""
        echo "--- pod events ---"
        kubectl get events --field-selector "involvedObject.name=$POD" --sort-by=.lastTimestamp 2>/dev/null || true
        echo ""
        echo "Next:"
        echo "  - phase Pending  -> scheduling / image pull (see events), not auth."
        echo "  - psql hangs     -> TCP not getting a reply; run tests/deployment/proxmox/db/test_net-probe.bats"
        echo "                      to check pod -> DB reachability, then compare the"
        echo "                      source IP the DB VM sees (tcpdump -ni any tcp port 5432)."
        echo "  - password not set on the server (or mismatch):"
        echo "      set it safely with: scripts/proxmox/vm/db/set-db-password.sh --dev"
        echo "      (prompts interactively — never type the password on a command line)"
    } >&2
    fail "postgres auth test failed — pod phase: ${PHASE:-unknown}"
}
