#!/bin/bash
#
# Bootstrap postgres on a dedicated Proxmox VM.
# Runs once at cloud-init first boot.
#
# The <K8S_POD_CIDR> placeholder is substituted at template creation time
# by create-template.sh (substituted from K8S_POD_CIDR in .env.network).
#
set -euo pipefail

LOG_FILE="/var/log/db-bootstrap.log"

# Log everything — tee to the log so both console (cloud-init captures it) and
# the file get a copy for post-mortem inspection.
exec > >(tee -a "$LOG_FILE") 2>&1

step() {
	echo ""
	echo "[$(date '+%H:%M:%S')] === $* ==="
}

# ---------------------------------------------------------------------------
step "Allow SSH before enabling firewall"
# ---------------------------------------------------------------------------
ufw allow ssh
echo "  -> SSH allowed"

# ---------------------------------------------------------------------------
step "Allow K8s pod traffic on port 5432"
# ---------------------------------------------------------------------------
# Safety net only: Calico masquerades pod -> LAN traffic to the worker IPs,
# so this rule never matches masqueraded traffic. Post-boot, the real gate is
# applied by vm/db/update-pg-hba.sh (worker IPs in ufw + pg_hba).
ufw allow from "{{K8S_POD_CIDR}}" to any port 5432 proto tcp
echo "  -> K8s pod CIDR {{K8S_POD_CIDR}} allowed on 5432/tcp (safety net)"

# ---------------------------------------------------------------------------
step "Enable firewall"
# ---------------------------------------------------------------------------
ufw --force enable
echo "  -> firewall enabled"

# ---------------------------------------------------------------------------
step "Configure postgres to listen on all interfaces"
# ---------------------------------------------------------------------------
sed -i "s/^#listen_addresses =.*/listen_addresses = '*'/" /etc/postgresql/18/main/postgresql.conf
echo "  -> listen_addresses = '*'"

# ---------------------------------------------------------------------------
step "Enable password auth for all hosts"
# ---------------------------------------------------------------------------
# SCRAM-sha-256: PG14+ stores SCRAM hashes; md5 fails network auth on PG18.
grep -qxF 'host all all 0.0.0.0/0 scram-sha-256' /etc/postgresql/18/main/pg_hba.conf ||
	echo "host all all 0.0.0.0/0 scram-sha-256" >>/etc/postgresql/18/main/pg_hba.conf
echo "  -> pg_hba.conf: scram-sha-256 auth for all hosts"

# ---------------------------------------------------------------------------
step "Restart postgres"
# ---------------------------------------------------------------------------
systemctl restart postgresql
echo "  -> postgresql restarted"

# ---------------------------------------------------------------------------
step "DB bootstrap complete — see /var/log/db-bootstrap.log"
# ---------------------------------------------------------------------------
