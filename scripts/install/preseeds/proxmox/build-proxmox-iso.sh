#!/usr/bin/env bash
#
# Create a preseeded Proxmox VE installer ISO.
#
# Takes a Debian Trixie netinst ISO, a hostname, a static IP, an
# interface name, SSH public keys, and a preseed template, and produces
# a hybrid (BIOS+UEFI) ISO that installs Proxmox VE 9.x with the least
# manual intervention possible.
#
# The generated ISO is intentionally GENERIC:
#   - No passwords baked into the ISO (prompted during install)
#   - SSH keys ARE baked in for post-install access
#   - Partitioning is automated unless --no-partition is given
#   - If the interface is a wireless one (wlp*), WiFi SSID and PSK are
#     prompted interactively and baked into the wpa_supplicant config
#   - If the interface is wired, WiFi configuration is skipped entirely
#   - Gateway/DNS defaults are read from config/.env.network
#     (GATEWAY/NAMESERVER) when present; --gateway/--dns override them
#
# Usage: See usage() function or run this script with the `--help` flag.
#
# Output:
#   A hybrid ISO ready to be written to any bootable medium via:
#     dd if=<output> of=<medium-name> bs=4M status=progress oflag=sync
#   Or use Rufus, Ventoy, Balena Etcher, etc.
#
# NOTE: You may need to run this script as superuser.
# NOTE: I didn't manage to figure out how to preseed network SSID selection.
# NOTE: This preseed does not ask for or generate the password hash.
set -euo pipefail

# ---- Paths ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRESEED_TEMPLATE="$SCRIPT_DIR/preseed.cfg"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ENV_NETWORK="$REPO_ROOT/config/.env.network"

# ---- State ----
TARGET_HOSTNAME=""
ISO_PATH=""
OUTPUT_ISO=""
TARGET_DISK=""
NO_PARTITION=false
INTERFACE=""
TARGET_IP=""
# Preserve GATEWAY/DNS if exported in the environment; config/.env.network,
# --gateway/--dns, or the built-in defaults below may override or fill them.
GATEWAY="${GATEWAY:-}"
DNS="${DNS:-}"

SSH_KEY_FILES=()
ISO_MOUNT=""
WORK_DIR=""

# ---- Cleanup trap ----
cleanup() {
	local exit_code=$?
	if [ -n "$ISO_MOUNT" ] && mountpoint -q "$ISO_MOUNT" 2>/dev/null; then
		umount "$ISO_MOUNT" 2>/dev/null || true
	fi
	[ -n "$ISO_MOUNT" ] && rmdir "$ISO_MOUNT" 2>/dev/null || true
	[ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR" 2>/dev/null || true
	exit "$exit_code"
}
trap cleanup EXIT

# ---- Helper functions ----
die() {
	echo "Error: $*" >&2
	exit 1
}

usage() {
	cat >&2 <<EOF
Usage: $(basename "$0") --hostname HOSTNAME --iso ISO --ip IP_ADDRESS [--interface IFACE] [--gateway GATEWAY] [--dns DNS] [--target-disk DEVICE] [--no-partition] [--output FILE] [ssh_key ...]

Create a preseeded Proxmox VE installer ISO with static networking.

Required:
  --hostname HOSTNAME  Desired hostname for the installed node
  --iso ISO            Path to Debian Bookworm netinst ISO file
  --ip IP_ADDRESS      Static IP address for the node (e.g. 192.168.2.100)

Optional:
  --interface IFACE    Network interface name (e.g. eth0, enp1s0, wlp1s0).
                       If it starts with wlp*, WiFi SSID and password are
                       prompted interactively and baked into the ISO.
                       (default: eth0)
  --gateway GATEWAY    Default gateway (default: GATEWAY from config/.env.network, else 192.168.2.1)
  --dns DNS            DNS server (default: NAMESERVER from config/.env.network, else 192.168.2.1)
  --target-disk DEVICE  Target disk for automated partitioning
                        (default: /dev/nvme0n1)
                        Examples: /dev/nvme1n1, /dev/sda, /dev/vda
  --no-partition       Skip automated partitioning entirely.
                       You will partition manually during install.
  --output FILE        Path for the output ISO (default: ./proxmox-preseed-\$HOSTNAME.iso)
  ssh_key ...          SSH public key file paths
                       (defaults to ~/.ssh/id_*.pub, first match)

  --help               Show this help and exit
EOF
	exit 1
}

# ---- Source network defaults (optional) ----
# If config/.env.network exists, its GATEWAY/NAMESERVER values are used as
# defaults below. Sourcing happens before argument parsing so that explicit
# --gateway/--dns flags always override the file values.
if [ -f "$ENV_NETWORK" ]; then
	# shellcheck disable=SC1090
	source "$ENV_NETWORK"
	echo "  Using network defaults from $ENV_NETWORK"
else
	echo "  — $ENV_NETWORK not found — falling back to built-in defaults"
fi

# ---- Parse arguments ----
while [[ $# -gt 0 ]]; do
	case "$1" in
	--hostname)
		TARGET_HOSTNAME="$2"
		shift 2
		;;
	--iso)
		ISO_PATH="$2"
		shift 2
		;;
	--target-disk)
		TARGET_DISK="$2"
		shift 2
		;;
	--no-partition)
		NO_PARTITION=true
		shift
		;;
	--interface)
		INTERFACE="$2"
		shift 2
		;;
	--ip)
		TARGET_IP="$2"
		shift 2
		;;
	--gateway)
		GATEWAY="$2"
		shift 2
		;;
	--dns)
		DNS="$2"
		shift 2
		;;
	--output)
		OUTPUT_ISO="$2"
		shift 2
		;;
	--help)
		usage
		;;
	--*)
		die "Unknown option: $1"
		;;
	*)
		SSH_KEY_FILES+=("$1")
		shift
		;;
	esac
done

# ---- Validate required flags ----
[ -z "$TARGET_HOSTNAME" ] && die "--hostname is required"
[ -z "$ISO_PATH" ] && die "--iso is required"
[ -z "$TARGET_IP" ] && die "--ip is required"
[ -z "$OUTPUT_ISO" ] && OUTPUT_ISO="./proxmox-preseed-${TARGET_HOSTNAME}.iso"

# ---- Defaults ----
# Use the GATEWAY/NAMESERVER env vars (from config/.env.network when present,
# or exported in the environment), then --gateway/--dns overrides, then
# hardcoded fallbacks.
GATEWAY="${GATEWAY:-192.168.2.1}"
DNS="${DNS:-${NAMESERVER:-192.168.2.1}}"

echo "Creating preseed ISO..."

# ---- Validation (fail-fast) ----
missing_deps=()
for cmd in xorriso isohybrid mount cp sed mktemp; do
	if ! command -v "$cmd" &>/dev/null; then
		missing_deps+=("$cmd")
	fi
done
if [ ${#missing_deps[@]} -gt 0 ]; then
	echo "  ✗ Missing dependencies:" >&2
	for dep in "${missing_deps[@]}"; do
		echo "    - $dep"
	done
	die "Install missing dependencies and retry."
fi
echo "  ✓ Dependencies available"

[ ! -f "$ISO_PATH" ] && die "ISO file not found: $ISO_PATH"
ISO_IS_VALID=false
if command -v isoinfo &>/dev/null; then
	if isoinfo -J -i "$ISO_PATH" -f 2>/dev/null | grep -qE '^/isolinux/|^/boot/grub/'; then
		ISO_IS_VALID=true
	fi
else
	if file "$ISO_PATH" | grep -qi "ISO 9660"; then
		ISO_IS_VALID=true
	fi
fi
if ! $ISO_IS_VALID; then
	echo "  ⚠ Could not verify ISO type (will validate after mount)"
fi

OUTPUT_DIR="$(cd "$(dirname "$OUTPUT_ISO")" && pwd 2>/dev/null || dirname "$OUTPUT_ISO")"
[ ! -d "$OUTPUT_DIR" ] && die "Output directory does not exist: $OUTPUT_DIR"
[ -e "$OUTPUT_ISO" ] && echo "  ⚠ Output file exists — will overwrite"
touch "$OUTPUT_DIR/.write-test" 2>/dev/null && rm "$OUTPUT_DIR/.write-test" || die "Output directory is not writable: $OUTPUT_DIR"

if [ ${#SSH_KEY_FILES[@]} -eq 0 ]; then
	for key in "$HOME"/.ssh/id_*.pub; do
		[ -f "$key" ] && {
			SSH_KEY_FILES+=("$key")
			break
		}
	done
fi
for key in "${SSH_KEY_FILES[@]}"; do
	[ ! -f "$key" ] && die "SSH public key not found: $key"
done
if [ ${#SSH_KEY_FILES[@]} -eq 0 ]; then
	echo "  ⚠ No SSH keys found — node will have no SSH access"
fi

[ ! -f "$PRESEED_TEMPLATE" ] && die "Preseed template not found: $PRESEED_TEMPLATE"

NETWORK_TEMPLATE="$SCRIPT_DIR/interfaces"
[ ! -f "$NETWORK_TEMPLATE" ] && die "Network template not found: $NETWORK_TEMPLATE"

WPA_TEMPLATE="$SCRIPT_DIR/wpa_supplicant.conf"

if [ "$NO_PARTITION" = false ] && [ -z "$TARGET_DISK" ]; then
	TARGET_DISK="/dev/nvme0n1"
fi

# ---- Resolve interface name ----
[ -z "$INTERFACE" ] && INTERFACE="eth0"

# ---- Determine extra packages based on interface type ----
if [[ "$INTERFACE" == wlp* ]]; then
	EXTRA_PACKAGES="curl gnupg ifupdown2 openssh-server wpasupplicant isc-dhcp-client"
else
	EXTRA_PACKAGES="curl gnupg ifupdown2 openssh-server isc-dhcp-client"
fi

# ---- WiFi prompts (SSID and PSK are NEVER accepted as CLI arguments) ----
WIFI_CONFIGURED=false
WIFI_SSID=""
if [[ "$INTERFACE" == wlp* ]]; then
	read -r -p "Enter WiFi SSID for interface \"$INTERFACE\": " WIFI_SSID
	[ -z "$WIFI_SSID" ] && die "WiFi SSID cannot be empty"
	read -r -s -p "Enter WiFi password for SSID \"$WIFI_SSID\": " WIFI_PSK
	echo ""
	[ -z "$WIFI_PSK" ] && die "WiFi password cannot be empty"
	WIFI_CONFIGURED=true

	if [ ! -f "$WPA_TEMPLATE" ]; then
		die "wpa_supplicant template not found: $WPA_TEMPLATE"
	fi
fi

echo ""
echo "  Hostname:   $TARGET_HOSTNAME"
echo "  Source:     $ISO_PATH"
echo "  Output:     $OUTPUT_ISO"
echo "  Disk:       $([ "$NO_PARTITION" = true ] && echo "manual" || echo "$TARGET_DISK")"
echo "  SSH keys:   ${#SSH_KEY_FILES[@]}"
echo "  IP:         $TARGET_IP/24"
echo "  Gateway:    $GATEWAY"
echo "  DNS:        $DNS"
echo "  Interface:  $INTERFACE"
echo "  WiFi:       $([ "$WIFI_CONFIGURED" = true ] && echo "SSID \"$WIFI_SSID\"" || echo "not configured")"
echo ""

# ---- Build ----
ISO_MOUNT=$(mktemp -d)
WORK_DIR=$(mktemp -d)

## Mount ISO and extract contents
echo "  Extracting ISO contents..."
mount -o loop "$ISO_PATH" "$ISO_MOUNT"
cp -a "$ISO_MOUNT/." "$WORK_DIR/"
chmod -R 644 "$WORK_DIR"
umount "$ISO_MOUNT"
rmdir "$ISO_MOUNT"
ISO_MOUNT=""
echo "  ✓ ISO extracted"

## Generate preseed.cfg
echo "  Generating preseed.cfg..."
cp "$PRESEED_TEMPLATE" "$WORK_DIR/preseed.cfg"
sed -i "s/<hostname>/$TARGET_HOSTNAME/g" "$WORK_DIR/preseed.cfg"
sed -i "s/<extrapackages>/$EXTRA_PACKAGES/g" "$WORK_DIR/preseed.cfg"
sed -i "s/<netiface>/$INTERFACE/g" "$WORK_DIR/preseed.cfg"

if [ "$WIFI_CONFIGURED" = true ]; then
	# Uncomment and fill in wireless credentials
	WIFI_SSID_ESC=$(printf '%s\n' "$WIFI_SSID" | sed 's:[&/\\]:\\&:g')
	WIFI_PSK_ESC=$(printf '%s\n' "$WIFI_PSK" | sed 's:[&/\\]:\\&:g')
	sed -i "s/<wifissid>/$WIFI_SSID_ESC/g" "$WORK_DIR/preseed.cfg"
	sed -i "s/<wifipsk>/$WIFI_PSK_ESC/g" "$WORK_DIR/preseed.cfg"
	sed -i 's/^# \(d-i netcfg\/wireless_essid string \)/\1/' "$WORK_DIR/preseed.cfg"
	sed -i 's/^# \(d-i netcfg\/wireless_wpa string \)/\1/' "$WORK_DIR/preseed.cfg"
fi

if [ "$NO_PARTITION" = true ]; then
	sed -i '/^### BEGIN PARTITION BLOCK$/,/^### END PARTITION BLOCK$/d' "$WORK_DIR/preseed.cfg"
	sed -i 's|<target_disk>|default|' "$WORK_DIR/preseed.cfg"
else
	sed -i "s|<target_disk>|$TARGET_DISK|g" "$WORK_DIR/preseed.cfg"
	sed -i '/^### BEGIN PARTITION BLOCK$/d; /^### END PARTITION BLOCK$/d' "$WORK_DIR/preseed.cfg"
fi

## Copy scripts to ISO
for script in copy-files.sh late-command.sh cleanup.sh in-target.sh; do
	src="$SCRIPT_DIR/$script"
	if [ -f "$src" ]; then
		cp "$src" "$WORK_DIR/$script"
		echo "  ✓ $script bundled"
	else
		echo "  ⚠ $script not found — skipping"
	fi
done

cp "$NETWORK_TEMPLATE" "$WORK_DIR/interfaces"
sed -i \
	-e "s/<interface>/$INTERFACE/g" \
	-e "s/<ip>/$TARGET_IP/g" \
	-e "s/<gateway>/$GATEWAY/g" \
	-e "s/<dns>/$DNS/g" \
	"$WORK_DIR/interfaces"
if [ "$WIFI_CONFIGURED" = true ]; then
	sed -i "s|<wifiline>|    wpa-conf /etc/wpa_supplicant/wpa_supplicant-${INTERFACE}.conf|" "$WORK_DIR/interfaces"
else
	sed -i '/<wifiline>/d' "$WORK_DIR/interfaces"
fi
echo "  ✓ /etc/network/interfaces generated ($TARGET_IP/24 @ $INTERFACE)"

## Generate and bundle wpa_supplicant config
if [ "$WIFI_CONFIGURED" = true ]; then
	# Escape special sed characters (| & / \) so they survive substitution
	WIFI_SSID_ESC=$(printf '%s\n' "$WIFI_SSID" | sed 's:[|&/\\]:\\&:g')
	WIFI_PSK_ESC=$(printf '%s\n' "$WIFI_PSK" | sed 's:[|&/\\]:\\&:g')
	sed -e "s|<wifissid>|$WIFI_SSID_ESC|g" \
		-e "s|<wifipsk>|$WIFI_PSK_ESC|g" \
		"$WPA_TEMPLATE" >"$WORK_DIR/wpa_supplicant-${INTERFACE}.conf"
	chmod 600 "$WORK_DIR/wpa_supplicant-${INTERFACE}.conf"
	echo "  ✓ wpa_supplicant-${INTERFACE}.conf generated"
else
	echo "  — WiFi not configured, skipping wpa_supplicant config"
fi

## Inject SSH authorized keys
echo "  Injecting SSH authorized keys..."
valid_keys=()
for key in "${SSH_KEY_FILES[@]}"; do
	if [ ! -f "$key" ]; then
		echo "  ⚠ SSH key not found, skipping: $key"
		continue
	fi
	if ssh-keygen -l -f "$key" &>/dev/null; then
		valid_keys+=("$key")
	else
		echo "  ⚠ Invalid SSH key, skipping: $key"
	fi
done
if [ ${#valid_keys[@]} -gt 0 ]; then
	cat "${valid_keys[@]}" >"$WORK_DIR/authorized_keys"
	echo "  ✓ $(wc -l <"$WORK_DIR/authorized_keys") key(s) injected"
else
	echo "  ⚠ No valid SSH keys — skipping"
fi

## Inject preseed kernel parameters into boot configs
PRESEED_PARAMS="auto=true preseed/file=/cdrom/preseed.cfg"
for cfg in isolinux/txt.cfg boot/grub/grub.cfg; do
	cfgpath="$WORK_DIR/$cfg"
	if [ -f "$cfgpath" ]; then
		sed -i "s|---|--- $PRESEED_PARAMS|" "$cfgpath"
	else
		echo "  ⚠ Boot config not found, skipping: $cfg"
	fi
done

## Build the ISO with xorriso
echo "  Building ISO (xorriso)..."
xorriso \
	-outdev "$OUTPUT_ISO" \
	-volid "PVE_PRESEED" \
	-padding 0 \
	-compliance no_emul_toc \
	-map "$WORK_DIR" / \
	-chmod 0755 / -- \
	-boot_image isolinux dir=/isolinux \
	-boot_image any next \
	-boot_image any efi_path=boot/grub/efi.img \
	-boot_image isolinux partition_entry=gpt_basdat \
	-stdio_sync off

echo "  ✓ ISO built"

## Make it hybrid (UEFI-capable)
echo "  Making ISO hybrid (UEFI)..."
isohybrid --uefi "$OUTPUT_ISO"

## Cleanup
sync

# ---- Done ----
echo ""
echo "Done. Write it with: dd if=$OUTPUT_ISO of=/dev/sd<X> bs=4M status=progress conv=fsync"
