#!/usr/bin/env bats
# Deployment test: pod → NFS TCP reachability probe (busybox nc).
#
# Runs a throwaway busybox pod that attempts a TCP connection to the dev files VM's port 2049 with a 5s timeout.
# It isolates the network path (pod → ufw → nfs-kernel-server listener) from mount/authentication concerns.
# Use this script to bisect a failing `mount -t nfs files.internal:/srv/nfs/xxx`:
#   - "open"    -> TCP reachable; the export or the mount options are the suspect
#   - "refused" -> no accepting listener (nfs-kernel-server not listening, or
#                  ufw REJECT)
#   - "timeout" -> silently dropped (ufw DROP, routing, or masquerade hiding
#                  the pod source IP)
# Prerequisites:
#   - kubectl configured for the invoking user, cluster on the same LAN as
#     the files VM
#   - hosts file entry files.internal (secrets/dev/hosts.sops.yaml)

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BATS_TEST_FILENAME}")")" && pwd)"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
POD="nfs-net-probe-$$"
NFS_PORT="2049"

setup() {
    HOSTS_MODE="dev"
    # shellcheck source=../../../../scripts/lib/hosts.sh
    source "$CONTROL_DIR/scripts/lib/hosts.sh" 2>/dev/null || skip "scripts/lib/hosts.sh not found"
    FILES_IP="$(hosts_ip_real files.internal)" || skip "files.internal not resolvable from the hosts file (missing or placeholder)"
    command -v kubectl >/dev/null 2>&1 || skip "kubectl not found"
    kubectl cluster-info >/dev/null 2>&1 || skip "kubectl cannot reach the cluster"
}

teardown() {
    kubectl delete pod "$POD" --ignore-not-found >/dev/null 2>&1 || true
}

@test "net probe: pod can reach dev files VM 2049 (TCP open)" {
    echo "==> Probing pod -> $FILES_IP:$NFS_PORT (TCP, 5s timeout)"
    echo "    pod: $POD"

    # kubectl run propagates the container exit code.
    # Guard it so a failing probe does not abort the test before the wait loop and diagnostics.
    kubectl run "$POD" \
        --image=busybox \
        --restart=Never \
        --command -- \
        sh -c "nc -w 5 -z $FILES_IP $NFS_PORT; rc=\$?; echo exit=\$rc; exit \$rc" \
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
        echo "==> OK: pod can reach $FILES_IP:$NFS_PORT (TCP open)"
        return 0
    fi

    # Failure: classify refused vs timeout, then surface placement/events.
    REASON="unclassified (see logs above)"
    if grep -qi "connection refused" <<<"$LOGS"; then
        REASON="REFUSED — no accepting listener on $FILES_IP:$NFS_PORT (nfs-kernel-server not listening, or ufw REJECT)"
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
        echo "  - TIMEOUT/DROP   -> compare the source IP the files VM sees:"
        echo "      sudo tcpdump -ni any tcp port 2049"
        echo "      If it is the node IP (192.168.18.x) instead of the pod IP (10.244.x.x),"
        echo "      that is masquerade, and the ufw rule 'allow from 10.244.0.0/16' will drop it."
    } >&2
    fail "TCP probe failed — pod phase: ${PHASE:-unknown}; $REASON"
}
