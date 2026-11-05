"""Tests for the Ansible inventory contracts."""

from __future__ import annotations

from collections.abc import Mapping
from typing import TYPE_CHECKING

import jsonschema
import pytest
import yaml

from tests.constants import (
    INVENTORY_DIR,
    SCHEMA_DIR,
    SCHEMA_PATHS,
    SCHEMA_TARGET_FILES,
    SCHEMA_TARGETS,
)

if TYPE_CHECKING:
    from pathlib import Path

SUBSET_KEY = "x-wywy-subset"


def _as_mapping(value: object) -> Mapping[str, object]:
    """Return value as a string-keyed mapping, or an empty mapping."""
    if not isinstance(value, Mapping):
        return {}
    return {key: item for key, item in value.items() if isinstance(key, str)}


def _load_yaml(path: Path) -> Mapping[str, object]:
    """Load a YAML mapping from path."""
    return _as_mapping(yaml.safe_load(path.read_text(encoding="utf-8")))


def _effective_groups(inventory: Mapping[str, object]) -> dict[str, set[str]]:
    """Flatten the inventory's nested children into effective host sets."""
    direct: dict[str, set[str]] = {}
    children: dict[str, set[str]] = {}

    def walk(name: str, spec: object) -> None:
        branch = _as_mapping(spec)
        direct.setdefault(name, set()).update(_as_mapping(branch.get("hosts")))
        child_groups = _as_mapping(branch.get("children"))
        children.setdefault(name, set()).update(child_groups)
        for child_name, child_spec in child_groups.items():
            walk(child_name, child_spec)

    for name, spec in inventory.items():
        walk(name, spec)

    groups = {name: set(hosts) for name, hosts in direct.items()}
    changed = True
    while changed:
        changed = False
        for name, child_names in children.items():
            before = len(groups.setdefault(name, set()))
            for child in child_names:
                groups[name].update(groups.get(child, set()))
            if len(groups[name]) != before:
                changed = True
    return groups


def _subset_problems(
    inventory: Mapping[str, object],
    schema: Mapping[str, object],
) -> list[str]:
    """Check the cross-group subset rules JSON Schema cannot express."""
    rules = _as_mapping(schema.get(SUBSET_KEY))
    if not rules:
        return []
    groups = _effective_groups(inventory)
    problems: list[str] = []
    for group, raw_superset in rules.items():
        if not isinstance(raw_superset, str):
            continue
        outside = sorted(groups.get(group, set()) - groups.get(raw_superset, set()))
        if outside:
            problems.append(
                f"'{group}' selects hosts outside "
                f"'{raw_superset}': {', '.join(outside)}",
            )
    return problems


SCHEMA_TARGET_IDS = [
    (
        f"{schema.relative_to(SCHEMA_DIR).as_posix()}:"
        f"{target.relative_to(INVENTORY_DIR).as_posix()}"
    )
    for schema, target in SCHEMA_TARGETS
]


def test_schema_and_target_lists_are_consistent() -> None:
    discovered = {path.relative_to(SCHEMA_DIR).as_posix() for path in SCHEMA_PATHS}
    assert discovered == set(SCHEMA_TARGET_FILES)
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
    assert _subset_problems(target, schema) == []
