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
# Reconfigure LVM layout: remove scratch (overflow placeholder),
# create vz (16 GB), create "data" thin pool (rest of VG).
#
# Background: partman's recipe creates LV "scratch" with max=-1 so
# it absorbs all VG overflow (partman's last-LV behavior swallows
# remaining space).  We tear it down here and reallocate properly.
# ==================================================================
step "Reconfigure LVM volumes in VG 'pve'"

if vgs pve >/dev/null 2>&1; then
	# --------------------------------------------------
	# Remove scratch LV (overflow placeholder from recipe)
	# --------------------------------------------------
	if lvs pve/scratch >/dev/null 2>&1; then
		echo "  -> Removing scratch LV (overflow placeholder)"
		umount /mnt/scratch 2>/dev/null || true
		rmdir /mnt/scratch 2>/dev/null || true
		sed -i '\|/mnt/scratch|d' /etc/fstab 2>/dev/null || true
		lvremove -f pve/scratch
		echo "  -> scratch LV removed"
	fi

	# --------------------------------------------------
	# Create vz LV (16 GB, btrfs) for /var/lib/vz
	# --------------------------------------------------
	if ! lvs pve/vz >/dev/null 2>&1; then
		lvcreate -L 16G -n vz pve
		mkfs.btrfs /dev/pve/vz
		echo '/dev/pve/vz /var/lib/vz btrfs defaults 0 2' >>/etc/fstab
		mkdir -p /var/lib/vz
		echo "  -> vz LV created (16 GB, btrfs) — added to fstab"
	else
		echo "  -> vz LV already exists — skipping"
	fi

	# --------------------------------------------------
	# Create "data" thin pool (rest of VG) for VM disk images
	# LVM auto-creates data_tmeta (100M) + data_tdata.
	# --------------------------------------------------
	free_extents=$(vgdisplay pve -c 2>/dev/null | cut -d: -f16)
	if [ "$free_extents" -gt 0 ] 2>/dev/null; then
		lvcreate --type thin-pool -n data -l 100%FREE pve
		echo "  -> Thin pool 'data' created ($free_extents extents)"
	else
		echo "  -> No free extents in VG 'pve' — skipping thin pool creation"
	fi
else
	echo "  -> VG 'pve' not found — skipping LVM reconfiguration"
fi

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
