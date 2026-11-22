"""Tests for the wywy_internal_dns lookup plugin.

The plugin must statically determine the DNS map.

@TODO get rid of this in favor of Molecule
"""

from __future__ import annotations

import ast
import socket
import subprocess
from pathlib import Path
from typing import Any, cast

import pytest
import wywy_internal_dns
from ansible.errors import AnsibleError
from wywy_internal_dns import DnsError, build_records

FORBIDDEN_IMPORTS = frozenset(
    {"socket", "subprocess", "http", "urllib", "requests", "proxmox", "pvesh"},
)

# Expected input. Written manually.
SERVICE_VMS = {
    "alpha.internal": "alpha_vm",
    "beta.internal": "beta_vm",
    "gamma.internal": "gamma_vm",
}

VM_HOSTS = [
    "node-2.internal",
    "alpha.internal",
    "gamma.internal",
    "node-1.internal",
    "beta.internal",
]

TERRAFORM_ENV: dict[str, object] = {
    "template_image": {"url": "https://example.invalid/image.qcow2"},
    "alpha_template": {"vm_id": 1_001},
    "alpha_vm": {"vm_id": 1, "ipv4_address": "192.0.2.10"},
    "beta_template": {"vm_id": 1_002},
    "beta_vm": {"vm_id": 2, "ipv4_address": "192.0.2.11"},
    "gamma_template": {"vm_id": 1_003},
    "gamma_vm": {"vm_id": 3, "ipv4_address": "198.51.100.20"},
    "node_templates": {
        "node-1": {"vm_id": 1_004},
        "node-2": {"vm_id": 1_005},
    },
    "node_vms": {
        "node-1": {"vm_id": 4, "ipv4_address": "203.0.113.30"},
        "node-2": {"vm_id": 5, "ipv4_address": "203.0.113.31"},
    },
}

ALPHA_ALIAS = {"alpha.internal": "alpha_vm"}


# Expected output. Written manually; do not derive it from the implementation.
EXPECTED_RECORDS: list[dict[str, str]] = [
    {"name": "alpha.internal", "address": "192.0.2.10"},
    {"name": "beta.internal", "address": "192.0.2.11"},
    {"name": "gamma.internal", "address": "198.51.100.20"},
    {"name": "node-1.internal", "address": "203.0.113.30"},
    {"name": "node-2.internal", "address": "203.0.113.31"},
]


def _lookup() -> wywy_internal_dns.LookupModule:
    return wywy_internal_dns.LookupModule()


def test_build_records_returns_expected_records() -> None:
    assert build_records(TERRAFORM_ENV, SERVICE_VMS, VM_HOSTS) == EXPECTED_RECORDS


def test_build_records_rejects_vm_without_ipv4_address() -> None:
    with pytest.raises(DnsError, match="ipv4_address"):
        build_records(
            {"alpha_vm": {"vm_id": 1}},
            ALPHA_ALIAS,
            ["alpha.internal"],
        )


def test_build_records_rejects_unknown_inventory_host() -> None:
    with pytest.raises(DnsError, match="unknown"):
        build_records(
            {"alpha_vm": {"vm_id": 1, "ipv4_address": "192.0.2.10"}},
            ALPHA_ALIAS,
            ["alpha.internal", "ghost.internal"],
        )


def test_build_records_rejects_unused_terraform_vm() -> None:
    environment = {
        "alpha_vm": {"ipv4_address": "192.0.2.10"},
        "beta_vm": {"ipv4_address": "192.0.2.11"},
    }
    with pytest.raises(DnsError, match="unused"):
        build_records(environment, ALPHA_ALIAS, ["alpha.internal"])


def test_build_records_rejects_service_alias_missing_from_inventory() -> None:
    environment = {
        "alpha_vm": {"ipv4_address": "192.0.2.10"},
        "gamma_vm": {"ipv4_address": "198.51.100.20"},
    }
    aliases = {
        "alpha.internal": "alpha_vm",
        "gamma.internal": "gamma_vm",
    }
    with pytest.raises(DnsError, match="not present in the inventory"):
        build_records(environment, aliases, ["alpha.internal"])


def test_build_records_rejects_duplicate_inventory_host() -> None:
    with pytest.raises(DnsError, match="duplicate"):
        build_records(
            {"alpha_vm": {"vm_id": 1, "ipv4_address": "192.0.2.10"}},
            ALPHA_ALIAS,
            ["alpha.internal", "alpha.internal"],
        )


def test_build_records_rejects_non_internal_name() -> None:
    with pytest.raises(DnsError, match=r"\.internal"):
        build_records(
            {"alpha_vm": {"vm_id": 1, "ipv4_address": "192.0.2.10"}},
            {"alpha.example.com": "alpha_vm"},
            ["alpha.example.com"],
        )


def test_build_records_rejects_invalid_ipv4_address() -> None:
    with pytest.raises(DnsError, match="IPv4"):
        build_records(
            {"alpha_vm": {"vm_id": 1, "ipv4_address": "192.0.2.999"}},
            ALPHA_ALIAS,
            ["alpha.internal"],
        )


def test_build_records_rejects_ipv6_address() -> None:
    with pytest.raises(DnsError, match=r"IPv4|IPv6"):
        build_records(
            {"alpha_vm": {"vm_id": 1, "ipv4_address": "2001:db8::1"}},
            ALPHA_ALIAS,
            ["alpha.internal"],
        )


def _imported_roots(source: str) -> set[str]:
    roots: set[str] = set()
    for node in ast.walk(ast.parse(source)):
        if isinstance(node, ast.Import):
            roots.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module is not None:
            roots.add(node.module.split(".")[0])
    return roots


def test_lookup_is_stateless(monkeypatch: pytest.MonkeyPatch) -> None:
    module_file = wywy_internal_dns.__file__
    assert module_file is not None
    imported = _imported_roots(Path(module_file).read_text(encoding="utf-8"))
    assert imported.isdisjoint(FORBIDDEN_IMPORTS), imported & FORBIDDEN_IMPORTS

    def _forbidden(*_args: object, **_kwargs: object) -> None:
        message = "build_records must not perform I/O"
        raise AssertionError(message)

    monkeypatch.setattr(socket, "socket", _forbidden)
    monkeypatch.setattr(subprocess, "run", _forbidden)
    assert build_records(TERRAFORM_ENV, SERVICE_VMS, VM_HOSTS) == EXPECTED_RECORDS


def test_lookup_run_returns_records() -> None:
    assert (
        _lookup().run(
            [TERRAFORM_ENV],
            service_vms=SERVICE_VMS,
            vm_hosts=VM_HOSTS,
        )
        == EXPECTED_RECORDS
    )


@pytest.mark.parametrize("terms", [[], [TERRAFORM_ENV, TERRAFORM_ENV]])
def test_lookup_run_rejects_wrong_term_count(terms: list[object]) -> None:
    with pytest.raises(AnsibleError, match="exactly one"):
        _lookup().run(
            cast("list[str]", terms),
            service_vms=SERVICE_VMS,
            vm_hosts=VM_HOSTS,
        )


def test_lookup_run_rejects_non_mapping_term() -> None:
    with pytest.raises(AnsibleError, match="mapping"):
        _lookup().run(
            ["not-a-mapping"],
            service_vms=SERVICE_VMS,
            vm_hosts=VM_HOSTS,
        )


def test_lookup_run_requires_service_vms() -> None:
    with pytest.raises(AnsibleError, match="service_vms"):
        _lookup().run([TERRAFORM_ENV], vm_hosts=VM_HOSTS)


def test_lookup_run_requires_vm_hosts() -> None:
    with pytest.raises(AnsibleError, match="vm_hosts"):
        _lookup().run([TERRAFORM_ENV], service_vms=SERVICE_VMS)


def test_lookup_run_rejects_non_mapping_service_vms() -> None:
    with pytest.raises(AnsibleError, match="service_vms"):
        _lookup().run(
            [TERRAFORM_ENV],
            service_vms=cast("Any", ["alpha_vm"]),
            vm_hosts=VM_HOSTS,
        )


def test_lookup_run_rejects_string_vm_hosts() -> None:
    with pytest.raises(AnsibleError, match="vm_hosts"):
        _lookup().run(
            [TERRAFORM_ENV],
            service_vms=SERVICE_VMS,
            vm_hosts=cast("Any", "alpha.internal"),
        )


def test_lookup_run_wraps_dns_error() -> None:
    environment: dict[str, object] = {
        "alpha_vm": {"ipv4_address": "192.0.2.10"},
    }
    with pytest.raises(AnsibleError, match="unknown"):
        _lookup().run(
            [environment],
            service_vms={},
            vm_hosts=["ghost.internal"],
        )
