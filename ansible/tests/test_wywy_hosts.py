"""Tests for the wywy_hosts lookup plugin."""

from __future__ import annotations

from pathlib import Path
from subprocess import CompletedProcess, TimeoutExpired
from textwrap import dedent
from unittest.mock import Mock

import pytest
import wywy_hosts
from ansible.errors import AnsibleError
from wywy_hosts import HostLine, HostsError

HOSTS_TEXT = """\
# comment
192.168.1.1 gateway.internal nameserver.internal
192.168.1.10 k8s-control-plane-1.internal
192.168.1.11 k8s-control-plane-2.internal
192.168.1.20 k8s-worker-1.internal
"""

ALIAS_HOSTS_TEXT = dedent(
    """\
    192.168.1.1 gateway.internal k8s-worker-99.internal
    192.168.1.2 k8s-worker-1.internal
    """,
)


def _records() -> list[HostLine]:
    return wywy_hosts.parse_hosts(HOSTS_TEXT)


def _fake_decrypt(_path: Path) -> str:
    return HOSTS_TEXT


def _completed(
    argv: list[str],
    *,
    returncode: int = 0,
    stdout: str = "",
    stderr: str = "",
) -> CompletedProcess[str]:
    return CompletedProcess(
        args=argv,
        returncode=returncode,
        stdout=stdout,
        stderr=stderr,
    )


@pytest.fixture
def control_dir(tmp_path: Path) -> Path:
    secrets = tmp_path / "secrets" / "dev"
    secrets.mkdir(parents=True)
    (secrets / "hosts.sops").write_text(HOSTS_TEXT)
    return tmp_path


@pytest.fixture
def variables(control_dir: Path) -> dict[str, str]:
    return {"control_dir": str(control_dir), "wywy_env": "dev"}


@pytest.fixture
def plugin(monkeypatch: pytest.MonkeyPatch) -> wywy_hosts.LookupModule:
    module = wywy_hosts.LookupModule()
    monkeypatch.setattr(wywy_hosts, "decrypt_file", _fake_decrypt)
    return module


def test_parse_hosts_reads_addresses_and_names() -> None:
    records = _records()
    assert [record.address for record in records] == [
        "192.168.1.1",
        "192.168.1.10",
        "192.168.1.11",
        "192.168.1.20",
    ]
    assert records[0].names == ("gateway.internal", "nameserver.internal")


def test_parse_hosts_strips_inline_comments() -> None:
    records = wywy_hosts.parse_hosts(
        "192.168.1.1 gateway.internal # management\n",
    )
    assert records == [
        HostLine(address="192.168.1.1", names=("gateway.internal",)),
    ]


@pytest.mark.parametrize(
    "text",
    [
        "  192.168.1.1 gateway.internal\n",
        "\t192.168.1.1 gateway.internal\n",
        "192.168.1.1\tgateway.internal\n",
    ],
)
def test_parse_hosts_accepts_whitespace(text: str) -> None:
    records = wywy_hosts.parse_hosts(text)
    assert records == [
        HostLine(address="192.168.1.1", names=("gateway.internal",)),
    ]


@pytest.mark.parametrize(
    ("text", "match"),
    [
        ("192.168.1.1\n", "expected '<address> <name>"),
        ("not-an-ip gateway.internal\n", "invalid address"),
        ("# only a comment\n", "no hosts"),
    ],
)
def test_parse_hosts_rejects_bad_input(text: str, match: str) -> None:
    with pytest.raises(HostsError, match=match):
        wywy_hosts.parse_hosts(text)


def test_resolve_name_canonical_and_alias() -> None:
    records = _records()
    assert wywy_hosts.resolve_name(records, "gateway.internal") == "192.168.1.1"
    assert wywy_hosts.resolve_name(records, "nameserver.internal") == "192.168.1.1"


def test_resolve_name_rejects_missing() -> None:
    with pytest.raises(HostsError, match="no entry"):
        wywy_hosts.resolve_name(_records(), "missing.internal")


AMBIGUOUS_HOSTS_TEXT = dedent(
    """\
    192.168.1.1 one.internal same.internal
    192.168.1.2 two.internal same.internal
    """,
)


def test_resolve_name_rejects_ambiguous() -> None:
    records = wywy_hosts.parse_hosts(AMBIGUOUS_HOSTS_TEXT)
    with pytest.raises(HostsError, match="ambiguous"):
        wywy_hosts.resolve_name(records, "same.internal")


def test_list_all_preserves_file_order() -> None:
    assert wywy_hosts.list_all(_records()) == [
        "192.168.1.1",
        "192.168.1.10",
        "192.168.1.11",
        "192.168.1.20",
    ]


def test_list_prefix_ignores_aliases() -> None:
    records = wywy_hosts.parse_hosts(ALIAS_HOSTS_TEXT)
    assert wywy_hosts.list_prefix(records, "k8s-worker-") == ["192.168.1.2"]


def test_resolve_name_still_resolves_aliases() -> None:
    records = wywy_hosts.parse_hosts(ALIAS_HOSTS_TEXT)
    assert wywy_hosts.resolve_name(records, "k8s-worker-99.internal") == "192.168.1.1"


def test_list_prefix_rejects_empty() -> None:
    with pytest.raises(HostsError, match="non-empty"):
        wywy_hosts.list_prefix(_records(), "")


def test_list_prefix_rejects_no_match() -> None:
    with pytest.raises(HostsError, match="no entry with prefix"):
        wywy_hosts.list_prefix(_records(), "missing-")


def test_plugin_resolves_name(
    plugin: wywy_hosts.LookupModule,
    variables: dict[str, str],
) -> None:
    assert plugin.run(["hosts.sops", "gateway.internal"], variables) == [
        "192.168.1.1",
    ]


def test_plugin_resolves_alias(
    plugin: wywy_hosts.LookupModule,
    variables: dict[str, str],
) -> None:
    assert plugin.run(["hosts.sops", "nameserver.internal"], variables) == [
        "192.168.1.1",
    ]


def test_plugin_lists_all(
    plugin: wywy_hosts.LookupModule,
    variables: dict[str, str],
) -> None:
    assert plugin.run(["hosts.sops"], variables, all=True) == [
        "192.168.1.1",
        "192.168.1.10",
        "192.168.1.11",
        "192.168.1.20",
    ]


def test_plugin_lists_prefix(
    plugin: wywy_hosts.LookupModule,
    variables: dict[str, str],
) -> None:
    assert plugin.run(["hosts.sops"], variables, prefix="k8s-worker-") == [
        "192.168.1.20",
    ]


def test_plugin_lists_prefix_rejects_empty(
    plugin: wywy_hosts.LookupModule,
    variables: dict[str, str],
) -> None:
    with pytest.raises(AnsibleError, match="non-empty"):
        plugin.run(["hosts.sops"], variables, prefix="")


def test_plugin_returns_whole_file(
    plugin: wywy_hosts.LookupModule,
    variables: dict[str, str],
) -> None:
    assert plugin.run(["hosts.sops"], variables, whole=True) == [
        HOSTS_TEXT.rstrip("\n"),
    ]


def test_plugin_wraps_lookup_errors(
    plugin: wywy_hosts.LookupModule,
    variables: dict[str, str],
) -> None:
    with pytest.raises(AnsibleError, match="no entry"):
        plugin.run(["hosts.sops", "missing.internal"], variables)


def test_plugin_rejects_path_traversal(
    plugin: wywy_hosts.LookupModule,
    variables: dict[str, str],
) -> None:
    with pytest.raises(AnsibleError, match="invalid hosts file name"):
        plugin.run(["../hosts.sops", "gateway.internal"], variables)


def test_plugin_rejects_wrong_suffix(
    plugin: wywy_hosts.LookupModule,
    variables: dict[str, str],
) -> None:
    with pytest.raises(AnsibleError, match="must end with"):
        plugin.run(["hosts.txt", "gateway.internal"], variables)


def test_plugin_requires_control_dir(
    plugin: wywy_hosts.LookupModule,
) -> None:
    with pytest.raises(AnsibleError, match="control_dir"):
        plugin.run(["hosts.sops", "gateway.internal"], {"wywy_env": "dev"})


def test_plugin_requires_env(
    plugin: wywy_hosts.LookupModule,
    variables: dict[str, str],
) -> None:
    with pytest.raises(AnsibleError, match="wywy_env"):
        plugin.run(
            ["hosts.sops", "gateway.internal"],
            {"control_dir": variables["control_dir"]},
        )


def test_templated_control_dir_resolves_to_secrets_path(
    plugin: wywy_hosts.LookupModule,
    variables: dict[str, str],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    templar = Mock()
    templar.template.return_value = variables["control_dir"]
    monkeypatch.setattr(plugin, "_templar", templar)

    decrypted: list[Path] = []

    def _capture(path: Path) -> str:
        decrypted.append(path)
        return HOSTS_TEXT

    monkeypatch.setattr(wywy_hosts, "decrypt_file", _capture)

    assert plugin.run(
        ["hosts.sops", "gateway.internal"],
        {"control_dir": "{{ control_dir }}", "wywy_env": "dev"},
    ) == ["192.168.1.1"]
    templar.template.assert_called_once_with("{{ control_dir }}")
    assert decrypted == [
        Path(variables["control_dir"]) / "secrets" / "dev" / "hosts.sops",
    ]


def test_decrypt_file_returns_sops_stdout(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    source = tmp_path / "hosts.sops"

    def _run(argv: list[str], **_kwargs: object) -> CompletedProcess[str]:
        return _completed(argv, stdout=HOSTS_TEXT)

    monkeypatch.setattr(wywy_hosts.shutil, "which", lambda _command: "/usr/bin/sops")
    monkeypatch.setattr(wywy_hosts.subprocess, "run", _run)

    assert wywy_hosts.decrypt_file(source) == HOSTS_TEXT


def test_decrypt_file_reports_sops_failure(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    source = tmp_path / "hosts.sops"

    def _run(argv: list[str], **_kwargs: object) -> CompletedProcess[str]:
        return _completed(argv, returncode=1, stderr="boom\n")

    monkeypatch.setattr(wywy_hosts.shutil, "which", lambda _command: "/usr/bin/sops")
    monkeypatch.setattr(wywy_hosts.subprocess, "run", _run)
    with pytest.raises(AnsibleError, match="boom"):
        wywy_hosts.decrypt_file(source)


def test_decrypt_file_does_not_include_stdout_on_failure(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    source = tmp_path / "hosts.sops"

    def _run(argv: list[str], **_kwargs: object) -> CompletedProcess[str]:
        return _completed(
            argv,
            returncode=1,
            stdout="partial plaintext\n",
        )

    monkeypatch.setattr(wywy_hosts.shutil, "which", lambda _command: "/usr/bin/sops")
    monkeypatch.setattr(wywy_hosts.subprocess, "run", _run)
    with pytest.raises(AnsibleError, match="exited 1") as error:
        wywy_hosts.decrypt_file(source)

    assert "partial plaintext" not in str(error.value)


def test_decrypt_file_reports_exec_error(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    source = tmp_path / "hosts.sops"

    def _run(_argv: list[str], **_kwargs: object) -> CompletedProcess[str]:
        message = "cannot execute"
        raise OSError(message)

    monkeypatch.setattr(wywy_hosts.shutil, "which", lambda _command: "/usr/bin/sops")
    monkeypatch.setattr(wywy_hosts.subprocess, "run", _run)
    with pytest.raises(AnsibleError, match="cannot execute"):
        wywy_hosts.decrypt_file(source)


def test_decrypt_file_reports_timeout(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    source = tmp_path / "hosts.sops"

    def _run(_argv: list[str], **_kwargs: object) -> CompletedProcess[str]:
        # The value is fake; decrypt_file only translates the exception type.
        raise TimeoutExpired(cmd="sops", timeout=1)

    monkeypatch.setattr(wywy_hosts.shutil, "which", lambda _command: "/usr/bin/sops")
    monkeypatch.setattr(wywy_hosts.subprocess, "run", _run)
    with pytest.raises(AnsibleError, match="timed out"):
        wywy_hosts.decrypt_file(source)


def test_decrypt_file_requires_sops(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(wywy_hosts.shutil, "which", lambda _command: None)
    with pytest.raises(AnsibleError, match="sops not found"):
        wywy_hosts.decrypt_file(tmp_path / "hosts.sops")
