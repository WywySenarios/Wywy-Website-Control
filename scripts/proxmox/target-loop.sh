#!/usr/bin/env bash
#
# Source this file after defining process_target():
#   process_target() {
#     local host="$1"    # Proxmox host IP
#     local worker="$2"  # Worker IP
#     local idx="$3"     # Index in IP arrays
#     local prefix="$4"  # Name prefix (dev-k8s-worker or prod-k8s-worker)
#     ...
#   }
#
# On source it sources .env.network, parses --dev/--prod/<host> from $@,
# and loops over all targets calling process_target() for each.
#
# Exported arrays: DEV_PROXMOX_ARR, DEV_K8S_WORKER_ARR, PROD_PROXMOX_ARR, K8S_WORKER_ARR

helper_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
control_dir="$(realpath "$helper_dir/../..")"
env_network="$control_dir/config/.env.network"

# ---- Source env ----
[ -f "$env_network" ] || {
	echo "Error: $env_network not found" >&2
	exit 1
}
# shellcheck disable=SC1090
source "$env_network"

# ---- Parse all IP lists ----
IFS=',' read -ra DEV_PROXMOX_ARR <<<"$DEV_PROXMOX_IPS"
IFS=',' read -ra DEV_K8S_WORKER_ARR <<<"$DEV_K8S_WORKER_IPS"
IFS=',' read -ra PROD_PROXMOX_ARR <<<"$PROXMOX_IPS"
IFS=',' read -ra K8S_WORKER_ARR <<<"$K8S_WORKER_IPS"

# ---- Resolve targets ----
targets=()

case "${1:-}" in
--dev)
	for i in "${!DEV_PROXMOX_ARR[@]}"; do
		host="$(echo "${DEV_PROXMOX_ARR[$i]}" | xargs)"
		worker="$(echo "${DEV_K8S_WORKER_ARR[$i]:-}" | xargs)"
		[ -z "$host" ] || [ -z "$worker" ] && continue
		targets+=("$host:$worker:$i:dev-k8s-worker")
	done
	;;
--prod)
	for i in "${!PROD_PROXMOX_ARR[@]}"; do
		host="$(echo "${PROD_PROXMOX_ARR[$i]}" | xargs)"
		worker="$(echo "${K8S_WORKER_ARR[$i]:-}" | xargs)"
		[ -z "$host" ] || [ -z "$worker" ] && continue
		targets+=("$host:$worker:$i:prod-k8s-worker")
	done
	;;
*)
	[ $# -eq 0 ] && {
		echo "Usage: $0 [--dev|--prod|<host>...]" >&2
		exit 1
	}
	for arg in "$@"; do
		host="$(echo "$arg" | xargs)"
		found=false

		# Look up in dev array
		for i in "${!DEV_PROXMOX_ARR[@]}"; do
			[ "$host" = "$(echo "${DEV_PROXMOX_ARR[$i]}" | xargs)" ] || continue
			worker="$(echo "${DEV_K8S_WORKER_ARR[$i]:-}" | xargs)"
			[ -n "$worker" ] && targets+=("$host:$worker:$i:dev-k8s-worker")
			found=true
			break
		done

		# Fall back to prod array
		if [ "$found" = false ]; then
			for i in "${!PROD_PROXMOX_ARR[@]}"; do
				[ "$host" = "$(echo "${PROD_PROXMOX_ARR[$i]}" | xargs)" ] || continue
				worker="$(echo "${K8S_WORKER_ARR[$i]:-}" | xargs)"
				[ -n "$worker" ] && targets+=("$host:$worker:$i:prod-k8s-worker")
				found=true
				break
			done
		fi

		if [ "$found" = false ]; then
			echo "Error: $host not found in DEV_PROXMOX_IPS or PROXMOX_IPS — skipping" >&2
		fi
	done

	[ ${#targets[@]} -eq 0 ] && {
		echo "No valid targets." >&2
		exit 1
	}
	;;
esac

echo "Targets: ${#targets[@]} host(s)"
echo ""

# ---- Loop over targets ----
for target in "${targets[@]}"; do
	host="${target%%:*}"
	rest="${target#*:}"
	worker="${rest%%:*}"
	rest="${rest#*:}"
	idx="${rest%%:*}"
	prefix="${rest#*:}"

	process_target "$host" "$worker" "$idx" "$prefix"
done

echo "==> All done."
