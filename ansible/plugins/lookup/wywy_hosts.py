# ruff: noqa: INP001
"""Lookup plugin for sops-encrypted hosts-format files.

A hosts-format file has one host per line:

    <address> <canonical-name> [<alias>...]

Field 1 is the address. Field 2 is the canonical name: the name every lookup
expects, and the only field an ordered list is keyed on. Fields 3+ are aliases
of the same host. Blank lines and text after `#` are ignored.

Supported lookups:

    lookup('wywy_hosts', '<file>', '<name>')     single address
    query('wywy_hosts', '<file>', all=true)      every address, file order
    query('wywy_hosts', '<file>', prefix='...')  canonical names by prefix
    lookup('wywy_hosts', '<file>', whole=true)   decrypted file text
"""

from __future__ import annotations

import ipaddress
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from ansible.errors import AnsibleError
from ansible.plugins.lookup import LookupBase

_TIMEOUT_SECONDS = 30.0
_NAME_TERM_COUNT = 2
_MIN_HOST_FIELDS = 2
_SINGLE_MATCH = 1
_ALLOWED_SUFFIXES = (".sops", ".sops.yaml")


class HostsError(Exception):
    """A hosts-file parse or lookup failure."""


@dataclass(frozen=True)
class HostLine:
    """One hosts-format line."""

    address: str
    names: tuple[str, ...]

    @property
    def canonical(self) -> str:
        """Return the canonical name (field 2)."""
        return self.names[0]


def parse_hosts(text: str, *, source: str = "<hosts>") -> list[HostLine]:
    """Parse hosts-format text into address/name records."""
    records: list[HostLine] = []
    for number, raw_line in enumerate(text.splitlines(), start=1):
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        fields = line.split()
        if len(fields) < _MIN_HOST_FIELDS:
            message = f"{source}:{number}: expected '<address> <name> [<alias>...]'"
            raise HostsError(message)
        try:
            address = str(ipaddress.ip_address(fields[0]))
        except ValueError as error:
            message = f"{source}:{number}: invalid address {fields[0]!r}"
            raise HostsError(message) from error
        records.append(HostLine(address=address, names=tuple(fields[1:])))
    if not records:
        message = f"{source}: no hosts"
        raise HostsError(message)
    return records


def resolve_name(
    records: list[HostLine],
    name: str,
    *,
    source: str = "<hosts>",
) -> str:
    """Return the address for a canonical name or alias."""
    matches = [record for record in records if name in record.names]
    if not matches:
        message = f"{source}: no entry for {name!r}"
        raise HostsError(message)
    if len(matches) > _SINGLE_MATCH:
        claimed = ", ".join(
            f"{record.address} ({', '.join(record.names)})" for record in matches
        )
        message = f"{source}: {name!r} is ambiguous: {claimed}"
        raise HostsError(message)
    return matches[0].address


def list_all(records: list[HostLine], *, source: str = "<hosts>") -> list[str]:
    """Return every address in file order."""
    if not records:
        message = f"{source}: no hosts"
        raise HostsError(message)
    return [record.address for record in records]


def list_prefix(
    records: list[HostLine],
    prefix: str,
    *,
    source: str = "<hosts>",
) -> list[str]:
    """Return addresses whose canonical name starts with prefix."""
    if not isinstance(prefix, str) or not prefix:
        message = "prefix must be a non-empty string"
        raise HostsError(message)
    matches = [
        record.address for record in records if record.canonical.startswith(prefix)
    ]
    if not matches:
        message = f"{source}: no entry with prefix {prefix!r}"
        raise HostsError(message)
    return matches


def decrypt_file(path: Path) -> str:
    """Return the decrypted contents of a sops file."""
    sops = shutil.which("sops")
    if sops is None:
        message = "sops not found in PATH"
        raise AnsibleError(message)
    try:
        completed = subprocess.run(  # noqa: S603
            [sops, "-d", "--output-type", "binary", str(path)],
            check=False,
            capture_output=True,
            text=True,
            timeout=_TIMEOUT_SECONDS,
        )
    except OSError as error:
        message = f"cannot run sops: {error}"
        raise AnsibleError(message) from error
    except subprocess.TimeoutExpired as error:
        message = f"sops timed out after {_TIMEOUT_SECONDS}s for {path}"
        raise AnsibleError(message) from error
    if completed.returncode != 0:
        detail = completed.stderr.strip()
        message = (
            f"cannot decrypt {path}: {detail}"
            if detail
            else f"cannot decrypt {path}: sops exited {completed.returncode}"
        )
        raise AnsibleError(message)
    return completed.stdout


class LookupModule(LookupBase):
    """Resolve names and role lists from a sops hosts file."""

    def run(
        self,
        terms: list[str],
        variables: dict[str, Any] | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> list[str]:
        """Return one address, a list of addresses, or the decrypted file."""
        variables = variables or {}
        control_dir = self._control_dir(variables)
        file_name, name = self._parse_terms(terms, kwargs)
        path = self._hosts_path(control_dir, file_name, variables)
        text = decrypt_file(path)

        if kwargs.get("whole"):
            return [text.rstrip("\n")]

        try:
            records = parse_hosts(text, source=file_name)
            if kwargs.get("all"):
                return list_all(records, source=file_name)
            prefix = kwargs.get("prefix")
            if prefix is not None:
                return list_prefix(records, prefix, source=file_name)
            return [resolve_name(records, name, source=file_name)]
        except HostsError as error:
            raise AnsibleError(str(error)) from error

    def _control_dir(self, variables: dict[str, Any]) -> Path:
        value = variables.get("control_dir")
        if not value:
            message = "wywy_hosts needs a non-empty control_dir variable"
            raise AnsibleError(message)
        control_dir = self._render(value)
        if not control_dir:
            message = "wywy_hosts needs a non-empty control_dir variable"
            raise AnsibleError(message)
        return Path(control_dir).resolve()

    def _render(self, value: object) -> str:
        if not isinstance(value, str):
            message = (
                f"wywy_hosts expected a string variable, got {type(value).__name__}"
            )
            raise AnsibleError(message)
        if "{{" not in value:
            return value
        if self._templar is None:
            message = "wywy_hosts cannot template control_dir without a templar"
            raise AnsibleError(message)
        rendered = self._templar.template(value)
        if not isinstance(rendered, str):
            message = (
                "wywy_hosts expected a string after templating, "
                f"got {type(rendered).__name__}"
            )
            raise AnsibleError(message)
        return rendered

    def _parse_terms(
        self,
        terms: list[str],
        kwargs: dict[str, Any],
    ) -> tuple[str, str | None]:
        if not terms or not terms[0]:
            message = "wywy_hosts expects a hosts-file name"
            raise AnsibleError(message)

        file_name = terms[0]
        list_mode = bool(
            kwargs.get("all") or kwargs.get("whole") or "prefix" in kwargs,
        )
        if list_mode:
            if len(terms) != 1:
                message = "wywy_hosts list/whole modes take only the hosts-file name"
                raise AnsibleError(message)
            return file_name, None

        if len(terms) != _NAME_TERM_COUNT or not terms[1]:
            message = "wywy_hosts expects <file> <name>"
            raise AnsibleError(message)

        name = terms[1]
        if any(character.isspace() for character in name):
            message = f"invalid host name: {name!r}"
            raise AnsibleError(message)
        return file_name, name

    def _hosts_path(
        self,
        control_dir: Path,
        file_name: str,
        variables: dict[str, Any],
    ) -> Path:
        value = variables.get("wywy_env")
        if not value:
            message = "wywy_hosts needs a non-empty wywy_env variable"
            raise AnsibleError(message)
        env = self._render(value)
        if not env:
            message = "wywy_hosts needs a non-empty wywy_env variable"
            raise AnsibleError(message)
        if "/" in file_name or "\\" in file_name or file_name in {".", ".."}:
            message = f"invalid hosts file name: {file_name!r}"
            raise AnsibleError(message)
        if not file_name.endswith(_ALLOWED_SUFFIXES):
            message = f"hosts file must end with .sops or .sops.yaml: {file_name!r}"
            raise AnsibleError(message)

        secrets_dir = (control_dir / "secrets" / env).resolve()
        path = (secrets_dir / file_name).resolve()
        if secrets_dir not in path.parents:
            message = f"hosts file escapes secrets/{env}: {file_name!r}"
            raise AnsibleError(message)
        return path
