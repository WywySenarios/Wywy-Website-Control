#!/bin/sh
#
# Cleans up after the in-target phase.
#
# Runs in the installer environment (outside chroot) — the target
# filesystem is mounted at /target.  All paths reference /target/ directly.
#
# This script is invoked from preseed.cfg as the last of three phases
# writing to the same log file.  See preseed.cfg for the exact invocation.
#
set -eu

echo "==========================================="
echo "  Cleanup phase started"
echo "  Date: $(date)"
echo "==========================================="

# ---- Helper ----
step() {
	echo ""
	echo "==> $(date '+%H:%M:%S') $*"
}

# ==================================================================
# Unmount virtual filesystems mounted by copy-files.sh.
# These must be unmounted before the target filesystem is detached
# at the end of the installation.
# ==================================================================
step "Unmount proc, sysfs, and dev from /target"

umount /target/dev 2>/dev/null || echo "  -> /target/dev not mounted (skipping)"
umount /target/sys 2>/dev/null || echo "  -> /target/sys not mounted (skipping)"
umount /target/proc 2>/dev/null || echo "  -> /target/proc not mounted (skipping)"
echo "  -> Done"

# ==================================================================
# Remove policy-rc.d now that package installation is complete.
# Services will start normally on first boot.
# ==================================================================
step "Remove policy-rc.d from /target"

rm -f /target/usr/sbin/policy-rc.d
echo "  -> policy-rc.d removed — service starts allowed again"

# ==================================================================
# Remove staged late-command.sh
# ==================================================================
step "Remove staged late-command.sh"

rm -f /target/root/late-command.sh
echo "  -> /target/root/late-command.sh removed"

# ==================================================================
# Remove install-time repository pin
# ==================================================================
# step "Remove install-time repository pin"

# rm -f /target/etc/apt/sources.list.d/pve-install-repo.list
# echo "  -> Repository pin removed"

# ==================================================================
# Restore cdrom entry in sources.list
# ==================================================================
step "Restore cdrom entry in /etc/apt/sources.list"

sed -i '/^#.*deb cdrom:/s/^#//' /target/etc/apt/sources.list 2>/dev/null || true
echo "  -> Cdrom entry restored"

# ==================================================================
# Done
# ==================================================================
echo ""
echo "==========================================="
echo "  Cleanup phase completed"
echo "  Date: $(date)"
echo "==========================================="
