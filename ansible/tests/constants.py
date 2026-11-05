"""Constants for the Ansible test suite."""

from __future__ import annotations

from pathlib import Path

ANSIBLE_DIR = Path(__file__).resolve().parents[1]
INVENTORY_DIR = ANSIBLE_DIR / "inventory"
SCHEMA_DIR = INVENTORY_DIR / "schema"
SCHEMA_GLOB = "**/*.schema.yaml"
SCHEMA_PATHS = tuple(sorted(SCHEMA_DIR.glob(SCHEMA_GLOB)))

SCHEMA_TARGET_FILES: dict[str, tuple[str, ...]] = {
    "hosts.schema.yaml": (
        "dev/hosts.yaml",
        "prod/hosts.yaml",
    ),
    "shared.hosts.schema.yaml": ("shared/hosts.yaml",),
    "all.schema.yaml": (
        "dev/group_vars/all.yaml",
        "prod/group_vars/all.yaml",
    ),
    "db_pve.schema.yaml": (
        "dev/group_vars/db_pve.yaml",
        "prod/group_vars/db_pve.yaml",
    ),
    "files_pve.schema.yaml": (
        "dev/group_vars/files_pve.yaml",
        "prod/group_vars/files_pve.yaml",
    ),
    "proxmox_iso.schema.yaml": (
        "dev/group_vars/proxmox_iso.yaml",
        "prod/group_vars/proxmox_iso.yaml",
    ),
    "proxmox.schema.yaml": (
        "dev/group_vars/proxmox.yaml",
        "prod/group_vars/proxmox.yaml",
    ),
    "registry_pve.schema.yaml": (
        "dev/group_vars/registry_pve.yaml",
        "prod/group_vars/registry_pve.yaml",
    ),
    "db.schema.yaml": ("shared/group_vars/db.yaml",),
    "files.schema.yaml": ("shared/group_vars/files.yaml",),
    "k8s_vms.schema.yaml": ("shared/group_vars/k8s_vms.yaml",),
    "k8s.schema.yaml": ("shared/group_vars/k8s.yaml",),
    "proxmox_k8s.schema.yaml": ("shared/group_vars/proxmox_k8s.yaml",),
    "registry.schema.yaml": ("shared/group_vars/registry.yaml",),
    "all.sops.schema.yaml": (
        "dev/group_vars/all.sops.yaml",
        "prod/group_vars/all.sops.yaml",
    ),
    "files.sops.schema.yaml": (
        "dev/group_vars/files.sops.yaml",
        "prod/group_vars/files.sops.yaml",
    ),
    "k8s_vms.sops.schema.yaml": (
        "dev/group_vars/k8s_vms.sops.yaml",
        "prod/group_vars/k8s_vms.sops.yaml",
    ),
    "proxmox.sops.schema.yaml": (
        "dev/group_vars/proxmox.sops.yaml",
        "prod/group_vars/proxmox.sops.yaml",
    ),
}
SCHEMA_TARGETS: tuple[tuple[Path, Path], ...] = tuple(
    (SCHEMA_DIR / schema, INVENTORY_DIR / target)
    for schema, targets in SCHEMA_TARGET_FILES.items()
    for target in targets
)
