"""Tests for the Terraform environment contracts.

Schemas live beside the environment files under
`terraform/proxmox/env/schema`. These tests validate environment files against
their schemas and enforce that env files mirror the base file's top-level keys.
"""

from __future__ import annotations

from collections.abc import Mapping
from pathlib import Path

import jsonschema
import pytest
import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
TERRAFORM_ENV_DIR = REPO_ROOT / "terraform" / "proxmox" / "env"
SCHEMA_DIR = TERRAFORM_ENV_DIR / "schema"

ENVIRONMENTS = ("dev", "prod")

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


def _load_yaml(path: Path) -> Mapping[str, object]:
    return _as_mapping(yaml.safe_load(path.read_text(encoding="utf-8")))


def _base_definitions() -> Mapping[str, object]:
    return _load_yaml(TERRAFORM_ENV_DIR / "base" / "proxmox.yaml")


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
