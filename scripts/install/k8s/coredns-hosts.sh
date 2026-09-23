#!/usr/bin/env bash
#
# Idempotently render the encrypted hosts file into the cluster's CoreDNS.
# No cluster restart is needed thanks to CoreDNS' auto-rollout.
#
# Usage:
#   coredns-hosts.sh [--dev|--prod] [--dry-run]
#
# Requires: kubectl (cluster access), sudo sops (operator age key).
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

MODE="dev"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
	case "$1" in
	--dev) MODE="dev" ;;
	--prod) MODE="prod" ;;
	--dry-run) DRY_RUN=true ;;
	*)
		echo "Usage: $0 [--dev|--prod] [--dry-run]" >&2
		exit 1
		;;
	esac
	shift
done

HOSTS_MODE="$MODE"
source "$SCRIPT_DIR/../../lib/hosts.sh"

[[ -f "$HOSTS_FILE" ]] || {
	echo "Error: $HOSTS_FILE not found (secrets/$MODE/hosts.sops.yaml)" >&2
	exit 1
}

# ---- Fetch the live Corefile ----
CURRENT_COREFILE="$(kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}')" || {
	echo "Error: could not fetch the coredns ConfigMap — is kubectl configured for this cluster?" >&2
	exit 1
}

# ---- Build the hosts block from the encrypted hosts file ----
HOSTS_BLOCK="$(sudo sops -d --output-type binary "$HOSTS_FILE" | awk '{printf "        %s %s\n", $1, $2}')" || {
	echo "Error: failed to decrypt $HOSTS_FILE" >&2
	exit 1
}
HOSTS_BLOCK="    hosts {
$HOSTS_BLOCK
        fallthrough
    }"

# ---- Insert/replace the hosts block before `forward` ----
NEW_COREFILE="$(awk -v block="$HOSTS_BLOCK" '
/^    hosts \{/ { in_hosts=1; next }
in_hosts && /^    \}/ { in_hosts=0; next }
in_hosts { next }
/^    forward / { print block }
{ print }
' <<<"$CURRENT_COREFILE")"

grep -q '^    hosts {' <<<"$NEW_COREFILE" || {
	echo "Error: could not place the hosts block — unexpected Corefile layout (no 'forward' plugin found)" >&2
	exit 1
}

if [[ "$NEW_COREFILE" == "$CURRENT_COREFILE" ]]; then
	echo "==> Corefile already up to date for $MODE — no change."
	exit 0
fi

if [[ "$DRY_RUN" == true ]]; then
	echo "==> DRY RUN — would apply this Corefile:"
	echo "---"
	printf '%s\n' "$NEW_COREFILE"
	echo "---"
	exit 0
fi

# ---- Back up the current Corefile ----
BACKUP="/tmp/coredns-corefile-$(date +%Y%m%d-%H%M%S).bak"
printf '%s\n' "$CURRENT_COREFILE" >"$BACKUP"
echo "==> Backed up current Corefile to $BACKUP"

# ---- Apply ----
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
$(printf '%s\n' "$NEW_COREFILE" | sed 's/^/    /')
EOF

echo "==> Applied hosts entry for $MODE. CoreDNS will reload automatically."
