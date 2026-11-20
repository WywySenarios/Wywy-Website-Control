"""Tests for the Terraform environment contracts.

Schemas live beside the environment files under `terraform/env/schema`. These
tests also enforce the VMID-to-address rules that JSON Schema cannot express.
"""

from __future__ import annotations

import ipaddress
from collections.abc import Mapping
from pathlib import Path

import jsonschema
import pytest
import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
TERRAFORM_ENV_DIR = REPO_ROOT / "terraform" / "env"
SCHEMA_DIR = TERRAFORM_ENV_DIR / "schema"
NETWORK_PATH = REPO_ROOT / "config" / "base" / "network.yaml"

ENVIRONMENTS = ("dev", "prod")
SERVICE_NAMES = ("registry", "database", "files")
K8S_PREFIXES = ("k8s_worker", "k8s_control_plane")

TEMPLATE_VMID_OFFSET = 1_000_000
OCTET_DIVISOR = 1_000
MIN_VM_VMID = 1
MAX_VM_VMID = 255_254
MIN_TEMPLATE_VMID = 1_000_001
MAX_TEMPLATE_VMID = 1_255_254
MIN_NETWORK_OCTET = 0
MAX_NETWORK_OCTET = 255
MIN_HOST_OCTET = 1
MAX_HOST_OCTET = 254
SDN_PREFIX_LENGTH = 16

SCHEMA_TARGET_FILES: dict[str, tuple[str, ...]] = {
    "base.schema.yaml": ("base/proxmox.yaml",),
    "env.schema.yaml": ("dev/proxmox.yaml", "prod/proxmox.yaml"),
}
SCHEMA_PATHS = tuple(sorted(SCHEMA_DIR.glob("*.schema.yaml")))
TARGET_PATHS = tuple(
    sorted(
        path for path in TERRAFORM_ENV_DIR.glob("*/*.yaml") if path.parent != SCHEMA_DIR
    ),
)
SCHEMA_TARGETS = tuple(
    (SCHEMA_DIR / schema, TERRAFORM_ENV_DIR / target)
    for schema, targets in SCHEMA_TARGET_FILES.items()
    for target in targets
)
SCHEMA_TARGET_IDS = [
    (
        f"{schema.relative_to(SCHEMA_DIR).as_posix()}:"
        f"{target.relative_to(TERRAFORM_ENV_DIR).as_posix()}"
    )
    for schema, target in SCHEMA_TARGETS
]


def _as_mapping(value: object) -> Mapping[str, object]:
    if not isinstance(value, Mapping):
        return {}
    return {key: item for key, item in value.items() if isinstance(key, str)}


def _as_int(value: object) -> int:
    assert isinstance(value, int), value
    assert not isinstance(value, bool), value
    return value


def _load_yaml(path: Path) -> Mapping[str, object]:
    return _as_mapping(yaml.safe_load(path.read_text(encoding="utf-8")))


def _base_definitions() -> Mapping[str, object]:
    return _load_yaml(TERRAFORM_ENV_DIR / "base" / "proxmox.yaml")


def _vm_pairs(
    base: Mapping[str, object],
) -> list[tuple[str, Mapping[str, object], Mapping[str, object]]]:
    pairs: list[tuple[str, Mapping[str, object], Mapping[str, object]]] = [
        (
            service,
            _as_mapping(base.get(f"{service}_template")),
            _as_mapping(base.get(f"{service}_vm")),
        )
        for service in SERVICE_NAMES
    ]
    for prefix in K8S_PREFIXES:
        templates = _as_mapping(base.get(f"{prefix}_templates"))
        vms = _as_mapping(base.get(f"{prefix}_vms"))
        pairs.extend(
            (key, _as_mapping(templates.get(key)), _as_mapping(vms.get(key)))
            for key in sorted(vms)
        )
    return pairs


def _vm_overrides(env: Mapping[str, object]) -> dict[str, Mapping[str, object]]:
    overrides: dict[str, Mapping[str, object]] = {
        service: _as_mapping(env.get(f"{service}_vm")) for service in SERVICE_NAMES
    }
    for prefix in K8S_PREFIXES:
        for key, value in _as_mapping(env.get(f"{prefix}_vms")).items():
            overrides[key] = _as_mapping(value)
    return overrides


def _network_subnet() -> ipaddress.IPv4Network:
    sdn = _as_mapping(_load_yaml(NETWORK_PATH).get("proxmox_sdn"))
    subnet = sdn.get("subnet")
    assert isinstance(subnet, str)
    parsed = ipaddress.ip_network(subnet)
    assert isinstance(parsed, ipaddress.IPv4Network)
    assert parsed.prefixlen == SDN_PREFIX_LENGTH
    return parsed


def _expected_address(
    vm_vmid: int,
    subnet: ipaddress.IPv4Network,
) -> ipaddress.IPv4Address:
    third = vm_vmid // OCTET_DIVISOR
    fourth = vm_vmid % OCTET_DIVISOR
    prefix = str(subnet.network_address).split(".")[:2]
    parsed = ipaddress.ip_address(f"{prefix[0]}.{prefix[1]}.{third}.{fourth}")
    assert isinstance(parsed, ipaddress.IPv4Address)
    return parsed


def test_schema_and_target_lists_are_consistent() -> None:
    assert {path.name for path in SCHEMA_PATHS} == set(SCHEMA_TARGET_FILES)
    assert {
        path.relative_to(TERRAFORM_ENV_DIR).as_posix() for path in TARGET_PATHS
    } == {target for targets in SCHEMA_TARGET_FILES.values() for target in targets}
    assert SCHEMA_TARGETS, "no schema targets configured"


@pytest.mark.parametrize(
    ("schema_path", "target_path"),
    SCHEMA_TARGETS,
    ids=SCHEMA_TARGET_IDS,
)
def test_target_satisfies_schema(schema_path: Path, target_path: Path) -> None:
    schema = _load_yaml(schema_path)
    target = _load_yaml(target_path)
    jsonschema.validate(instance=target, schema=schema)


def test_env_and_base_entries_match() -> None:
    base = _base_definitions()
    base_keys = set(base) - {"template_image"}
    for environment in ENVIRONMENTS:
        env = _load_yaml(TERRAFORM_ENV_DIR / environment / "proxmox.yaml")
        assert set(env) - {"ssh_public_keys"} == base_keys, environment
        for prefix in K8S_PREFIXES:
            for suffix in ("templates", "vms"):
                base_map = _as_mapping(base.get(f"{prefix}_{suffix}"))
                env_map = _as_mapping(env.get(f"{prefix}_{suffix}"))
                assert set(env_map) == set(base_map), (environment, prefix, suffix)


def test_template_vmids_match_vm_vmids() -> None:
    for name, template, vm in _vm_pairs(_base_definitions()):
        template_vmid = _as_int(template.get("vm_id"))
        vm_vmid = _as_int(vm.get("vm_id"))
        assert template_vmid == vm_vmid + TEMPLATE_VMID_OFFSET, name
        assert MIN_VM_VMID <= vm_vmid <= MAX_VM_VMID, name
        assert MIN_TEMPLATE_VMID <= template_vmid <= MAX_TEMPLATE_VMID, name


def test_vmids_are_unique() -> None:
    vmids = [
        _as_int(definition.get("vm_id"))
        for _, template, vm in _vm_pairs(_base_definitions())
        for definition in (template, vm)
    ]
    assert len(vmids) == len(set(vmids))


def test_vmids_map_to_valid_octets() -> None:
    for name, _, vm in _vm_pairs(_base_definitions()):
        vm_vmid = _as_int(vm.get("vm_id"))
        third = vm_vmid // OCTET_DIVISOR
        fourth = vm_vmid % OCTET_DIVISOR
        assert MIN_NETWORK_OCTET <= third <= MAX_NETWORK_OCTET, name
        assert MIN_HOST_OCTET <= fourth <= MAX_HOST_OCTET, name


@pytest.mark.parametrize("environment", ENVIRONMENTS)
def test_ipv4_addresses_follow_vmids(environment: str) -> None:
    base_vms = {name: vm for name, _, vm in _vm_pairs(_base_definitions())}
    env = _load_yaml(TERRAFORM_ENV_DIR / environment / "proxmox.yaml")
    subnet = _network_subnet()
    for name, override in _vm_overrides(env).items():
        address = override.get("ipv4_address")
        if address is None:
            continue
        assert isinstance(address, str)
        vm_vmid = _as_int(base_vms[name].get("vm_id"))
        assert ipaddress.ip_address(address) == _expected_address(vm_vmid, subnet), name
