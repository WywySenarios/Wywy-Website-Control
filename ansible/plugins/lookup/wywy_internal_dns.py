# ruff: noqa: INP001
"""Lookup plugin for the pure internal DNS map.

The map combines the merged Terraform VM definitions with the inventory VM host
list. Every address is taken from Terraform; the plugin never contacts Proxmox
or any other resolver.
"""

from __future__ import annotations

import ipaddress
from collections.abc import Mapping, Sequence
from typing import TYPE_CHECKING, Any

from ansible.errors import AnsibleError

if TYPE_CHECKING:

    class _LookupBase:
        """Typed stand-in for Ansible's untyped LookupBase."""
else:
    from ansible.plugins.lookup import LookupBase as _LookupBase

_INTERNAL_SUFFIX = ".internal"
_VM_SUFFIX = "_vm"
_VMS_SUFFIX = "_vms"
_IPV4_FIELD = "ipv4_address"
_ENVIRONMENT_TERM_COUNT = 1

_ERR_INVALID_INTERNAL_NAME = "{label} must end with {suffix}: {name!r}"
_ERR_VM_HOSTS_STRINGS = "vm_hosts must contain strings"
_ERR_DUPLICATE_HOST = "duplicate inventory host: {host!r}"
_ERR_ALIAS_NOT_INVENTORY = "service alias {alias!r} is not present in the inventory"
_ERR_MISSING_ADDRESS = "VM {vm_key!r} is missing {field}"
_ERR_INVALID_ADDRESS = "VM {vm_key!r} has an invalid IPv4 address: {value!r}"
_ERR_UNKNOWN_HOST = "unknown inventory host: {host!r}"
_ERR_UNUSED_VMS = "unused Terraform VM definitions: {names}"
_ERR_TERM_COUNT = "wywy_internal_dns expects exactly one term"
_ERR_ENV_MAPPING = "wywy_internal_dns expects the Terraform environment as a mapping"
_ERR_SERVICE_VMS_MAPPING = "wywy_internal_dns requires a service_vms mapping"
_ERR_SERVICE_VMS_STRINGS = "wywy_internal_dns service_vms must map strings to strings"
_ERR_VM_HOSTS_SEQUENCE = "wywy_internal_dns requires a vm_hosts sequence"
_ERR_VM_HOSTS_STRINGS = "wywy_internal_dns vm_hosts must contain strings"


class DnsError(Exception):
    """An internal DNS map build failure."""


def _string_mapping(value: object) -> dict[str, object]:
    """Return a string-keyed mapping, or an empty mapping."""
    if not isinstance(value, Mapping):
        return {}
    return {key: item for key, item in value.items() if isinstance(key, str)}


def _terraform_vms(
    environment: Mapping[str, object],
) -> dict[str, Mapping[str, object]]:
    """Collect Terraform VM definitions keyed by VM name."""
    vms: dict[str, Mapping[str, object]] = {}
    for key, value in environment.items():
        if not isinstance(key, str):
            continue
        if key.endswith(_VMS_SUFFIX):
            for name, definition in _string_mapping(value).items():
                vms[name] = _string_mapping(definition)
        elif key.endswith(_VM_SUFFIX):
            vms[key] = _string_mapping(value)
    return vms


def _require_internal(name: str, label: str) -> None:
    """Raise unless the name carries the internal DNS suffix."""
    if not name.endswith(_INTERNAL_SUFFIX):
        raise DnsError(
            _ERR_INVALID_INTERNAL_NAME.format(
                label=label,
                suffix=_INTERNAL_SUFFIX,
                name=name,
            ),
        )


def _validate_hosts(vm_hosts: Sequence[str]) -> set[str]:
    """Validate inventory host names and return them as a set."""
    hosts: set[str] = set()
    for host in vm_hosts:
        if not isinstance(host, str):
            raise DnsError(_ERR_VM_HOSTS_STRINGS)
        _require_internal(host, "host name")
        if host in hosts:
            raise DnsError(_ERR_DUPLICATE_HOST.format(host=host))
        hosts.add(host)
    return hosts


def _check_aliases(service_vms: Mapping[str, str], hosts: set[str]) -> None:
    """Validate service aliases against the inventory host set."""
    for alias in service_vms:
        _require_internal(alias, "service alias")
        if alias not in hosts:
            raise DnsError(_ERR_ALIAS_NOT_INVENTORY.format(alias=alias))


def _ipv4_address(vm_key: str, definition: Mapping[str, object]) -> str:
    """Return the validated IPv4 address from a VM definition."""
    value = definition.get(_IPV4_FIELD)
    if not isinstance(value, str):
        raise DnsError(_ERR_MISSING_ADDRESS.format(vm_key=vm_key, field=_IPV4_FIELD))
    try:
        address = ipaddress.IPv4Address(value)
    except ipaddress.AddressValueError as error:
        raise DnsError(
            _ERR_INVALID_ADDRESS.format(vm_key=vm_key, value=value),
        ) from error
    return str(address)


def _vm_key_for_host(host: str, service_vms: Mapping[str, str]) -> str:
    """Return the Terraform VM key for an inventory host."""
    return service_vms.get(host, host.removesuffix(_INTERNAL_SUFFIX))


def build_records(
    terraform_env: Mapping[str, object],
    service_vms: Mapping[str, str],
    vm_hosts: Sequence[str],
) -> list[dict[str, str]]:
    """Return the sorted internal DNS records."""
    hosts = _validate_hosts(vm_hosts)
    _check_aliases(service_vms, hosts)
    vms = _terraform_vms(terraform_env)

    records: list[dict[str, str]] = []
    used: set[str] = set()
    for host in hosts:
        vm_key = _vm_key_for_host(host, service_vms)
        definition = vms.get(vm_key)
        if definition is None:
            raise DnsError(_ERR_UNKNOWN_HOST.format(host=host))
        records.append(
            {"name": host, "address": _ipv4_address(vm_key, definition)},
        )
        used.add(vm_key)

    unused = sorted(set(vms) - used)
    if unused:
        raise DnsError(_ERR_UNUSED_VMS.format(names=", ".join(unused)))

    records.sort(key=lambda record: record["name"])
    return records


def _environment_term(terms: Sequence[object]) -> Mapping[str, object]:
    """Return the single Terraform environment mapping from the terms."""
    if len(terms) != _ENVIRONMENT_TERM_COUNT:
        raise AnsibleError(_ERR_TERM_COUNT)
    term = terms[0]
    if not isinstance(term, Mapping):
        raise AnsibleError(_ERR_ENV_MAPPING)
    return _string_mapping(term)


def _service_vms_kwarg(kwargs: Mapping[str, Any]) -> dict[str, str]:
    """Return the validated service_vms keyword argument."""
    value = kwargs.get("service_vms")
    if not isinstance(value, Mapping):
        raise AnsibleError(_ERR_SERVICE_VMS_MAPPING)
    service_vms: dict[str, str] = {}
    for key, item in value.items():
        if not isinstance(key, str) or not isinstance(item, str):
            raise AnsibleError(_ERR_SERVICE_VMS_STRINGS)
        service_vms[key] = item
    return service_vms


def _vm_hosts_kwarg(kwargs: Mapping[str, Any]) -> list[str]:
    """Return the validated vm_hosts keyword argument."""
    value = kwargs.get("vm_hosts")
    if isinstance(value, str) or not isinstance(value, Sequence):
        raise AnsibleError(_ERR_VM_HOSTS_SEQUENCE)
    vm_hosts: list[str] = []
    for item in value:
        if not isinstance(item, str):
            raise AnsibleError(_ERR_VM_HOSTS_STRINGS)
        vm_hosts.append(item)
    return vm_hosts


class LookupModule(_LookupBase):
    """Build the internal DNS map from Terraform and inventory data."""

    def run(
        self,
        terms: Sequence[object],
        variables: dict[str, Any] | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> list[dict[str, str]]:
        """Return the sorted internal DNS records."""
        _ = variables
        environment = _environment_term(terms)
        service_vms = _service_vms_kwarg(kwargs)
        vm_hosts = _vm_hosts_kwarg(kwargs)
        try:
            return build_records(environment, service_vms, vm_hosts)
        except DnsError as error:
            raise AnsibleError(str(error)) from error
