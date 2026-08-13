#!/bin/bash
# init-k8s-secrets.sh — Bootstrap K8s Secrets from local SOPS-encrypted files.
#
# Usage:   sudo bash scripts/init-k8s-secrets.sh
#
# Prerequisites:
#   - kubectl installed and configured for the original (non-root) user
#   - sops installed and able to decrypt secrets/*.sops
#   - Run once per cluster before deploying ArgoCD Applications
#     that reference these Secrets
#
# Behaviour:
#   - Prints a warning banner listing every secret that will be created
#   - Asks for confirmation
#   - 5-second countdown with Ctrl+C abort
#   - Decrypts SOPS files, creates/updates K8s Secrets via kubectl
#   - kubectl runs as $SUDO_USER via runuser (kubeconfig lives under the
#     original user's home directory)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTROL_DIR="${WYWY_CONTROL_DIR:-"$(cd "$SCRIPT_DIR/.." && pwd)"}"
SECRETS_DIR="$CONTROL_DIR/secrets"
GHCR_USERNAME="${GHCR_USERNAME:-WywySenarios}"
RUNNER_NAMESPACE="github-runner"

# --- Privilege check ---
# Test seam: set INIT_K8S_SECRETS_SKIP_PRIVILEGE_CHECK=1 to bypass
# (used by bats tests to test the rest of the script without root)
if [[ -z "${INIT_K8S_SECRETS_SKIP_PRIVILEGE_CHECK:-}" ]]; then
	if [[ $EUID -ne 0 ]]; then
		echo "ERROR: This script must be run with sudo."
		echo "       sudo bash $0"
		exit 1
	fi

	if [[ -z "${SUDO_USER:-}" ]]; then
		echo "ERROR: SUDO_USER is not set. Run with sudo, not as root directly."
		exit 1
	fi
fi

# --- Helper: run kubectl as the original user ---
kubectl_user() {
	local user="${SUDO_USER:-root}"
	runuser -u "$user" -- kubectl "$@"
}

# --- Define secret mappings ---
# Format: "source_file|secret_name|key_name|namespace"
# source_file is relative to SECRETS_DIR
# SOPS files are decrypted automatically; plaintext files are read as-is.
#
# TODO: Confirm the namespaces marked below before relying on those secrets.
# The current K8s manifests only establish github-runner for the runner and
# registry secrets; the database and backup consumers are not present here.
declare -a SECRET_MAP=(
	# "shared/admin.txt.sops|master-db-admin|password|default" # TODO: confirm database namespace
	"ci/github-runner-token.sops|github-runner-pat|token|github-runner"
	"dev/registry-auth.sops|registry-auth|htpasswd|github-runner"
	# "prod/postgres-password.sops|postgres-password|password|default" # TODO: confirm database namespace
	# "dev/postgres-password.sops|postgres-password|password|default" # TODO: dev database namespace
)

# --- Resolve actual values ---
# (Note: can't use subshell-based resolve function here because
#  WARN_MISSING mutations made inside $() would be lost.)
declare -a ENTRIES=()
declare -a WARN_MISSING=()
RUNNER_PAT=""

for mapping in "${SECRET_MAP[@]}"; do
	IFS='|' read -r src secret key target_namespace <<<"$mapping"
	full_path="$SECRETS_DIR/$src"

	if [[ ! -f "$full_path" ]]; then
		WARN_MISSING+=("$src")
		continue
	fi

	if [[ "$src" == *.sops ]]; then
		value="$(sops --decrypt "$full_path" 2>/dev/null)" || {
			WARN_MISSING+=("$src (decryption failed)")
			continue
		}
	else
		value="$(cat "$full_path")"
	fi

	ENTRIES+=("$secret|$key|$value|$target_namespace")
	if [[ "$secret" == "github-runner-pat" && "$key" == "token" ]]; then
		RUNNER_PAT="$value"
		RUNNER_NAMESPACE="$target_namespace"
	fi
done

# --- Warning banner ---
cat <<WARN

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                                   WARNING
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

This script will create or update the following Kubernetes Secrets in
the namespaces specified in SECRET_MAP below.

WARN

if [[ ${#ENTRIES[@]} -eq 0 ]]; then
	echo "  (no secrets to create — all source files missing or failed to decrypt)"
	echo ""
	echo "Nothing to do. Exiting."
	exit 0
fi

for entry in "${ENTRIES[@]}"; do
	IFS='|' read -r secret key value target_namespace <<<"$entry"
	echo "  * Secret: $secret  |  Namespace: $target_namespace  |  Key: $key  |  Value length: ${#value} chars"
done
if [[ -n "$RUNNER_PAT" ]]; then
	echo "  * Secret: regcred-ghcr  |  Namespace: $RUNNER_NAMESPACE  |  Type: docker-registry  |  Value length: ${#RUNNER_PAT} chars"
fi

if [[ ${#WARN_MISSING[@]} -gt 0 ]]; then
	echo ""
	echo "WARNING: The following source files were missing or could not be read:"
	for w in "${WARN_MISSING[@]}"; do
		echo "  - $w"
	done
fi

echo ""
echo "The original user ($SUDO_USER) will be used for kubectl operations."
echo "To abort, press Ctrl+C within 5 seconds."

# --- Countdown ---
for i in 5 4 3 2 1; do
	echo -n "$i... "
	sleep 1
done
echo ""

# --- Apply ---
echo ""
echo "Applying secrets..."

for entry in "${ENTRIES[@]}"; do
	IFS='|' read -r secret key value target_namespace <<<"$entry"

	if kubectl_user get secret "$secret" -n "$target_namespace" &>/dev/null; then
		echo "  Updating existing secret: $secret"
	else
		echo "  Creating new secret: $secret"
	fi

	kubectl_user create secret generic "$secret" \
		--namespace "$target_namespace" \
		--from-literal="$key=$value" \
		--dry-run=client -o yaml | kubectl_user apply -f -
done

# GHCR requires a dockerconfigjson pull secret rather than a generic Secret.
# Keep it synchronized with the runner PAT so image pulls use the same
# current credentials as KEDA and the runner container.
if [[ -n "$RUNNER_PAT" ]]; then
	if kubectl_user get secret regcred-ghcr -n "$RUNNER_NAMESPACE" &>/dev/null; then
		echo "  Updating existing secret: regcred-ghcr"
	else
		echo "  Creating new secret: regcred-ghcr"
	fi

	kubectl_user create secret docker-registry regcred-ghcr \
		--namespace "$RUNNER_NAMESPACE" \
		--docker-server=ghcr.io \
		--docker-username="$GHCR_USERNAME" \
		--docker-password="$RUNNER_PAT" \
		--dry-run=client -o yaml | kubectl_user apply -f -
fi

echo ""
echo "Done. Verify each target namespace from SECRET_MAP."
