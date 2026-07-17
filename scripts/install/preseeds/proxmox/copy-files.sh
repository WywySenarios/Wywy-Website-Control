#!/bin/sh
#
# Copies configuration files from the ISO to the target system.
#
# Runs in the installer environment (outside chroot) — the target
# filesystem is mounted at /target.  All paths reference /target/ directly.
#
# The late-command.sh script is also copied into /target/root/ so that
# the next phase can run it via chroot (piping via stdin doesn't work).
# cleanup.sh removes it afterward.
#
# This script is invoked from preseed.cfg as the first of three phases
# writing to the same log file.  See preseed.cfg for the exact invocation.
#
set -eu

echo "==========================================="
echo "  Copy-files phase started"
echo "  Date: $(date)"
echo "==========================================="

# ---- Helper ----
step() {
	echo ""
	echo "==> $(date '+%H:%M:%S') $*"
}

# ==================================================================
# SSH authorized_keys
# ==================================================================
step "SSH authorized_keys"
(
	set -e
	mkdir -p /target/home/wywy/.ssh
	cp /cdrom/authorized_keys /target/home/wywy/.ssh/authorized_keys

	if [ -f /target/home/wywy/.ssh/authorized_keys ]; then
		chmod 600 /target/home/wywy/.ssh/authorized_keys
		chroot /target chown wywy:wywy /home/wywy/.ssh/authorized_keys
		echo "  -> $(wc -l </target/home/wywy/.ssh/authorized_keys) key(s) installed"
	else
		echo "  -> No authorized_keys found (user will need password login)"
	fi
) || echo "  \342\232\240 SSH authorized_keys step failed (non-fatal, continuing)"

# ==================================================================
# Grant passwordless sudo to wywy
# ==================================================================
step "Grant passwordless sudo to wywy"

echo 'wywy ALL=(ALL) NOPASSWD: ALL' >/target/etc/sudoers.d/wywy
chmod 440 /target/etc/sudoers.d/wywy
echo "  -> /target/etc/sudoers.d/wywy created"

# ==================================================================
# Configure systemd-networkd
# ==================================================================
step "Configure systemd-networkd"

mkdir -p /target/etc/systemd/network
echo "  -> /target/etc/systemd/network/ created"

if [ -f /cdrom/00-main.network ]; then
	cp /cdrom/00-main.network /target/etc/systemd/network/00-main.network
	chmod 644 /target/etc/systemd/network/00-main.network
	echo "  -> 00-main.network copied from /cdrom"
else
	echo "  -> No 00-main.network on CDROM — DHCP will be used"
fi

# ==================================================================
# Write /etc/hosts with the static IP from 00-main.network
# ==================================================================
step "Write /etc/hosts from 00-main.network"

if [ -f /target/etc/systemd/network/00-main.network ]; then
	IP=$(sed -n 's/^Address=\([0-9.]*\).*/\1/p' /target/etc/systemd/network/00-main.network)
	if [ -n "$IP" ]; then
		HOSTNAME=$(cat /target/etc/hostname 2>/dev/null || echo "proxmox")
		cat >/target/etc/hosts <<HOSTSEOF
127.0.0.1 localhost
$IP $HOSTNAME

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
HOSTSEOF
		echo "  -> /etc/hosts — $HOSTNAME resolves to $IP"
	else
		echo "  -> No Address= in 00-main.network — /etc/hosts not modified"
	fi
else
	echo "  -> 00-main.network not found — /etc/hosts not modified"
fi

# ==================================================================
# Copy wpa_supplicant configuration(s)
# ==================================================================
step "Copy wpa_supplicant config(s)"

mkdir -p /target/etc/wpa_supplicant
echo "  -> /target/etc/wpa_supplicant/ created"

found=false
for conf in /cdrom/wpa_supplicant-*.conf; do
	if [ -f "$conf" ]; then
		name=$(basename "$conf")
		cp "$conf" "/target/etc/wpa_supplicant/$name"
		chmod 600 "/target/etc/wpa_supplicant/$name"
		echo "  -> $name installed"
		found=true
	fi
done
if [ "$found" = false ]; then
	echo "  -> No wpa_supplicant-*.conf on CDROM — WiFi not configured"
fi

# ==================================================================
# Write Proxmox VE repository list (for the in-target phase)
# ==================================================================
step "Add Proxmox VE pve-no-subscription repository list"

echo 'deb http://download.proxmox.com/debian/pve trixie pve-no-subscription' \
	>/target/etc/apt/sources.list.d/pve-install-repo.list
echo "  -> Repository list written"

# ==================================================================
# Stage late-command.sh into /target/root/ for the chroot phase
# ==================================================================
step "Stage late-command.sh into /target/root/"

mkdir -p /target/root
cp /cdrom/late-command.sh /target/root/late-command.sh
chmod 755 /target/root/late-command.sh
echo "  -> /target/root/late-command.sh staged"

# ==================================================================
# Stage in-target.sh into /target/home/wywy/ for interactive use
# ==================================================================
step "Stage in-target.sh into /target/home/wywy/"

if [ -f /cdrom/in-target.sh ]; then
	cp /cdrom/in-target.sh /target/home/wywy/in-target.sh
	chmod 755 /target/home/wywy/in-target.sh
	chroot /target chown wywy:wywy /home/wywy/in-target.sh
	echo "  -> /target/home/wywy/in-target.sh staged"
else
	echo "  -> No in-target.sh on CDROM (skipping)"
fi

# ==================================================================
# Install policy-rc.d to prevent package postinst scripts from
# trying to start services inside the chroot.
#
# In a chroot, systemd is not PID 1, so any postinst that calls
# systemctl (start/enable) or invoke-rc.d will fail.  The shim
# tells dpkg to skip the "start now" step while still allowing
# package configuration (user creation, unit enablement, etc.).
# cleanup.sh removes it after the chroot phase.
# ==================================================================
step "Install policy-rc.d in /target/usr/sbin/policy-rc.d"

cat >/target/usr/sbin/policy-rc.d <<'POLICYEOF'
#!/bin/sh
exit 101
POLICYEOF
chmod +x /target/usr/sbin/policy-rc.d
echo "  -> policy-rc.d installed — service starts suppressed during install"

# ==================================================================
# Mount virtual filesystems for the chroot phase.
# The late-command.sh script needs /proc, /sys, and /dev to be present
# inside the chroot so that kernel postinst scripts (update-grub,
# proxmox-boot-tool) can enumerate block devices.
# cleanup.sh unmounts them afterward.
# ==================================================================
step "Mount proc, sysfs, and dev into /target"

mount -t proc proc /target/proc
mount -t sysfs sysfs /target/sys
mount -o bind /dev /target/dev
echo "  -> Done — /target/{proc,sys,dev} mounted"

# ==================================================================
# Done
# ==================================================================
echo ""
echo "==========================================="
echo "  Copy-files phase completed"
echo "  Date: $(date)"
echo "==========================================="
