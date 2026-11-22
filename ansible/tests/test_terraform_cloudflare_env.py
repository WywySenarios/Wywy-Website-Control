"""Tests for the Cloudflare Terraform environment contract."""

from __future__ import annotations

from collections.abc import Mapping
from pathlib import Path

import jsonschema
import pytest
import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
ENV_DIR = REPO_ROOT / "terraform" / "cloudflare" / "env"
SCHEMA_PATH = ENV_DIR / "schema" / "env.schema.yaml"
ENVIRONMENTS = ("dev", "prod")


def _as_mapping(value: object) -> Mapping[str, object]:
    if not isinstance(value, Mapping):
        return {}
    return {key: item for key, item in value.items() if isinstance(key, str)}


def _load_yaml(path: Path) -> Mapping[str, object]:
    return _as_mapping(yaml.safe_load(path.read_text(encoding="utf-8")))


@pytest.mark.parametrize("environment", ENVIRONMENTS)
def test_cloudflare_env_satisfies_schema(environment: str) -> None:
    schema = _load_yaml(SCHEMA_PATH)
    target = _load_yaml(ENV_DIR / environment / "cloudflare.yaml")
    jsonschema.validate(instance=target, schema=schema)
