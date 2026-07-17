#!/bin/sh
#
# Post-install late-command configuration for Proxmox VE.
#
# Runs inside the target chroot.  All paths are relative to / (the target
# root).  This script is staged at /root/late-command.sh by copy-files.sh and
# invoked via:
#   chroot /target sh /root/late-command.sh
#
set -eu

echo "==========================================="
echo "  Late-command phase started"
echo "  Date: $(date)"
echo "  Host: $(hostname)"
echo "==========================================="

# ---- Helper ----
step() {
	echo ""
	echo "==> $(date '+%H:%M:%S') $*"
}

# ==================================================================
# Prevent cdrom entry from breaking apt during late-command.
# Remove cdrom entry from sources.list
# ==================================================================
step "Comment out cdrom entry in /etc/apt/sources.list"

sed -i '/^deb cdrom:/s/^/#/' /etc/apt/sources.list 2>/dev/null || true
echo "  -> Done"

# ==================================================================
# Import Proxmox VE GPG key
# ==================================================================
step "Import Proxmox VE GPG key"

curl -fsSL https://enterprise.proxmox.com/debian/proxmox-archive-keyring-trixie.gpg \
	-o /etc/apt/trusted.gpg.d/proxmox-release-trixie.gpg
echo "  -> GPG key imported"

# ==================================================================
# Enable systemd-networkd (network config was staged by copy-files.sh)
# ==================================================================
step "Enable systemd-networkd"

systemctl enable systemd-networkd
echo "  -> systemd-networkd enabled"

# ==================================================================
# Enable wpa_supplicant for each wireless interface with a config
# ==================================================================
step "Enable wpa_supplicant for wireless interface(s)"

found=false
for conf in /etc/wpa_supplicant/wpa_supplicant-*.conf; do
	if [ -f "$conf" ]; then
		iface=$(basename "$conf" .conf | sed 's/wpa_supplicant-//')
		systemctl enable "wpa_supplicant@${iface}"
		echo "  -> wpa_supplicant@${iface} enabled"
		found=true
	fi
done
if [ "$found" = false ]; then
	echo "  -> No wpa_supplicant-*.conf found — WiFi not configured"
fi

# ==================================================================
# Done
# ==================================================================
echo ""
echo "==========================================="
echo "  Late-command phase completed"
echo "  Date: $(date)"
echo "==========================================="
