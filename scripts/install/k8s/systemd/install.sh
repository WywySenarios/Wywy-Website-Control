#!/usr/bin/env bash
#
# Install port-forward systemd user services.
#
# Copies .service files to ~/.config/systemd/user/, then enables and
# starts each one.  Safe to re-run — already-installed services are
# skipped (systemctl --user enable --now is idempotent).
#
set -euo pipefail

SERVICE_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
USER_SYSTEMD="$HOME/.config/systemd/user"

mkdir -p "$USER_SYSTEMD"

# If specific services given as args, install only those; otherwise all
if [ $# -gt 0 ]; then
	services=()
	for name in "$@"; do
		services+=("$SERVICE_DIR/$name")
	done
else
	services=("$SERVICE_DIR"/*.service)
fi

for svc in "${services[@]}"; do
	name="$(basename "$svc")"
	dst="$USER_SYSTEMD/$name"

	if [ -f "$dst" ]; then
		echo "  $name already installed"
	else
		echo "==> Installing $name..."
		cp "$svc" "$dst"
	fi
done

systemctl --user daemon-reload

for svc in "${services[@]}"; do
	name="$(basename "$svc")"
	echo "==> Enabling $name..."
	systemctl --user enable --now "$name"
done

echo ""
echo "=============================================="
echo "  Port-forward services (user):"
echo "    systemctl --user status grafana-pf.service"
echo "    systemctl --user status linkerd-pf.service"
echo "    systemctl --user status argocd-pf.service"
echo ""
echo "  http://localhost:8081 — Grafana"
echo "  http://localhost:8082 — Linkerd"
echo "  http://localhost:8083 — ArgoCD"
echo "=============================================="
echo "You will need to enable linger to make these services start at boot."
echo "Enable it with this command: sudo loginctl enable-linger $USER"