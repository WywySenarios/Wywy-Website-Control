#!/bin/sh
#
# Interactive post-install configuration for Proxmox VE.
#
# Runs inside the actual installed system (not chroot).  Installs
# necessary apt packages with interactive prompts so that debconf
# dialogs (postfix, proxmox-ve) are presented to the operator.
# Prompts to reboot when done.
#
# Place this script in the wywy user's home directory (~/in-target.sh)
# and run it after the first boot:
#   sudo ./in-target.sh
#
set -eu

# ==================================================================
# Safety check — must be run as root
# ==================================================================
if [ "$(id -u)" -ne 0 ]; then
	echo "This script must be run as root (use sudo)."
	exit 1
fi

echo "==========================================="
echo "  Interactive in-target setup"
echo "  Date: $(date)"
echo "  Host: $(hostname)"
echo "==========================================="

# ---- Helper ----
step() {
	echo ""
	echo "==> $(date '+%H:%M:%S') $*"
}

# ==================================================================
# Update package index
# ==================================================================
step "Updating package index"

apt-get update

echo "  -> Package index updated"

# ==================================================================
# Remove os-prober
# ==================================================================

apt-get remove -y os-prober

# ==================================================================
# Install age for SOPS-compatible secret decryption
# ==================================================================
step "Installing age"

apt-get install -y age

echo "  -> age installed"

# ==================================================================
# Install sops (SOPS CLI, not available as apt package)
# ==================================================================
step "Installing sops"

SOPS_VERSION="v3.13.2"
if ! command -v sops; then
	curl -fsSL --retry 3 \
		"https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64" \
		-o /usr/local/bin/sops
	chmod 755 /usr/local/bin/sops
	echo "  -> sops ${SOPS_VERSION} installed"
else
	echo "  -> sops already installed ($(sops --version 2>/dev/null || echo "unknown"))"
fi

# ==================================================================
# Install postfix (interactive — will prompt for mail configuration)
# ==================================================================
step "Installing postfix"

apt-get install -y postfix

echo "  -> postfix installed"

# ==================================================================
# Install open-iscsi
# ==================================================================
step "Installing open-iscsi"

apt-get install -y open-iscsi
systemctl enable iscsid iscsid.socket
echo "  -> open-iscsi installed, iscsid enabled"

# ==================================================================
# Install proxmox-ve (interactive — may prompt for configuration)
# ==================================================================
step "Installing proxmox-ve"

apt-get install -y proxmox-ve

echo "  -> proxmox-ve installed"

# ==================================================================
# Install proxmox-secure-boot-support
# ==================================================================
step "Installing proxmox-secure-boot-support"

apt-get install -y proxmox-secure-boot-support

echo "  -> proxmox-secure-boot-support installed"

# ==================================================================
# Create Proxmox VE admin user (wywy@pam)
# ==================================================================
step "Creating Proxmox VE admin user (wywy@pam)"

# Grant the existing Linux user 'wywy' Proxmox admin access via PAM.
# This lets wywy log into the Proxmox web UI using their Linux password.
pveum useradd wywy@pam -comment "Wywy Admin" 2>/dev/null ||
	echo "  -> wywy@pam already exists"
pveum aclmod / -user wywy@pam -role Administrator
echo "  -> wywy@pam granted Administrator role on /"

# ==================================================================
# Done — prompt to reboot
# ==================================================================
echo ""
echo "==========================================="
echo "  Package installation complete"
echo "  Date: $(date)"
echo "==========================================="
echo ""
echo "Please reboot into Proxmox: \"sudo reboot\""
echo ""
