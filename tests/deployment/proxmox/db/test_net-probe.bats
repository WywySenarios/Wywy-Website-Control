#!/usr/bin/env bats
# Deployment test: pod → DB TCP reachability probe (busybox nc).
#
# Runs a throwaway busybox pod that attempts a TCP connection to the dev DB
# VM's 5432 with a 5s timeout. No password, no sops, no sudo — this isolates
# the network path (pod → ufw → postgres listener) from auth. Use it to
# bisect test_pod-auth.bats failures:
#   - "open"    -> TCP reachable; auth is the suspect (sops value vs server)
#   - "refused" -> no accepting listener (postgres not listening externally,
#                  or ufw REJECT)
#   - "timeout" -> silently dropped (ufw DROP, routing, or masquerade hiding
#                  the pod source IP)
#
# Dev only — tests never run against prod.
#
# Prerequisites:
#   - kubectl configured for the invoking user, cluster on the same LAN as
#     the DB VM
#   - config/.env.network with DEV_DATABASE_IP

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BATS_TEST_FILENAME}")")" && pwd)"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ENV_NETWORK="$CONTROL_DIR/config/.env.network"
POD="pg-net-probe-$$"
DB_PORT="5432"

setup() {
    # shellcheck disable=SC1090
    source "$ENV_NETWORK" 2>/dev/null || skip "config/.env.network not found — copy .env.network.example"
    DB_IP="${DEV_DATABASE_IP:-}"
    [[ -n "$DB_IP" ]] || skip "DEV_DATABASE_IP not set in config/.env.network"
    command -v kubectl >/dev/null 2>&1 || skip "kubectl not found"
    kubectl cluster-info >/dev/null 2>&1 || skip "kubectl cannot reach the cluster"
}

teardown() {
    kubectl delete pod "$POD" --ignore-not-found >/dev/null 2>&1 || true
}

@test "net probe: pod can reach dev DB VM 5432 (TCP open)" {
    echo "==> Probing pod -> $DB_IP:$DB_PORT (TCP, 5s timeout)"
    echo "    pod: $POD"

    # kubectl run propagates the container exit code; guard it so a failing
    # probe does not abort the test before the wait loop and diagnostics.
    kubectl run "$POD" \
        --image=busybox \
        --restart=Never \
        --command -- \
        sh -c "nc -w 5 -z $DB_IP $DB_PORT; rc=\$?; echo exit=\$rc; exit \$rc" \
        || true

    PHASE=""
    for _ in $(seq 1 60); do
        PHASE="$(kubectl get pod "$POD" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
        [[ "$PHASE" == "Succeeded" || "$PHASE" == "Failed" ]] && break
        sleep 2
    done

    LOGS="$(kubectl logs "$POD" 2>/dev/null || true)"
    echo ""
    echo "--- probe logs ---"
    echo "$LOGS"
    echo ""

    if [[ "$PHASE" == "Succeeded" ]]; then
        echo "==> OK: pod can reach $DB_IP:$DB_PORT (TCP open)"
        return 0
    fi

    # Failure: classify refused vs timeout, then surface placement/events.
    REASON="unclassified (see logs above)"
    if grep -qi "connection refused" <<<"$LOGS"; then
        REASON="REFUSED — no accepting listener on $DB_IP:$DB_PORT (postgres not listening externally, or ufw REJECT)"
    elif grep -q "exit=1" <<<"$LOGS"; then
        REASON="TIMEOUT/DROP — silent no-reply (ufw DROP, routing, or masquerade hiding the pod source IP)"
    fi

    {
        echo ""
        echo "--- pod placement (node / pod IP) ---"
        kubectl get pod "$POD" -o wide 2>/dev/null || true
        echo ""
        echo "--- pod events ---"
        kubectl get events --field-selector "involvedObject.name=$POD" --sort-by=.lastTimestamp 2>/dev/null || true
        echo ""
        echo "Next:"
        echo "  - phase Pending  -> scheduling / image pull (see events), not the network."
        echo "  - TIMEOUT/DROP   -> compare the source IP the DB VM sees:"
        echo "      sudo tcpdump -ni any tcp port 5432"
        echo "      If it is the node IP (192.168.2.x) instead of the pod IP (10.244.x.x),"
        echo "      that is masquerade, and the ufw rule 'allow from 10.244.0.0/16' will drop it."
    } >&2
    fail "TCP probe failed — pod phase: ${PHASE:-unknown}; $REASON"
}
