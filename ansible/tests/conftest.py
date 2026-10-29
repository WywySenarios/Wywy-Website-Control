"""Tests for the Ansible plugins."""

from __future__ import annotations

import sys
from pathlib import Path

PLUGIN_DIR = Path(__file__).resolve().parents[1] / "plugins" / "lookup"
sys.path.insert(0, str(PLUGIN_DIR))
