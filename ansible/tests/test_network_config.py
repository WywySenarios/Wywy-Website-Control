"""Tests for the shared VM network contract."""

from __future__ import annotations

from collections.abc import Mapping
from pathlib import Path

import jsonschema
import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = REPO_ROOT / "config" / "schema" / "network.schema.yaml"
TARGET_PATH = REPO_ROOT / "config" / "base" / "network.yaml"


def _as_mapping(value: object) -> Mapping[str, object]:
    """Return value as a string-keyed mapping, or an empty mapping."""
    if not isinstance(value, Mapping):
        return {}
    return {key: item for key, item in value.items() if isinstance(key, str)}


def _load_yaml(path: Path) -> Mapping[str, object]:
    """Load a YAML mapping from path."""
    return _as_mapping(yaml.safe_load(path.read_text(encoding="utf-8")))


def test_network_contract_satisfies_schema() -> None:
    schema = _load_yaml(SCHEMA_PATH)
    target = _load_yaml(TARGET_PATH)
    jsonschema.validate(instance=target, schema=schema)
