"""Entrypoint for the Wywy Ansible playbooks.

The environment is chosen once, here, and turned into an absolute inventory
path, so a run cannot silently fall back on ansible.cfg's inventory default.
"""

import argparse
import os
import sys
from pathlib import Path

# The project is installed in editable mode, so __file__ stays in the source
# tree: <control>/ansible/src/wywy_ansible/cli.py
ANSIBLE_DIR = Path(__file__).resolve().parents[2]
CONFIG_FILE = ANSIBLE_DIR / "ansible.cfg"
INVENTORY_DIR = ANSIBLE_DIR / "inventory"
PLAYBOOKS_DIR = ANSIBLE_DIR / "playbooks"


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse the environment flag and the playbook path."""
    parser = argparse.ArgumentParser(
        prog="wywy-ansible",
        description="Run a playbook against dev or prod.",
    )
    environment = parser.add_mutually_exclusive_group(required=True)
    environment.add_argument(
        "--dev",
        dest="env",
        action="store_const",
        const="dev",
        help="target the dev inventory",
    )
    environment.add_argument(
        "--prod",
        dest="env",
        action="store_const",
        const="prod",
        help="target the prod inventory",
    )
    parser.add_argument(
        "playbook",
        help="playbook path relative to ansible/, e.g. playbooks/db/db.yaml",
    )
    return parser.parse_args(argv)


def resolve_playbook(raw: str) -> Path:
    """Resolve a playbook argument against ansible/, refusing anything else."""
    candidate = (ANSIBLE_DIR / raw).resolve()
    if not candidate.is_file() or PLAYBOOKS_DIR.resolve() not in candidate.parents:
        problem = f"not a playbook under {PLAYBOOKS_DIR}: {raw}"
        raise SystemExit(problem)
    return candidate


# Not thread-safe — mutates the process environment and replaces the process.
def main() -> None:
    """Hand the playbook to ansible-playbook with the chosen inventory."""
    args = parse_args(sys.argv[1:])
    playbook = resolve_playbook(args.playbook)
    inventory = INVENTORY_DIR / args.env
    print(f"==> {args.env}: {playbook} with {inventory}", file=sys.stderr)
    environment = os.environ | {
        "ANSIBLE_CONFIG": str(CONFIG_FILE),
        "ANSIBLE_INVENTORY": str(inventory),
    }
    # S606/S607: exec is deliberate; the bare name comes from the venv on PATH.
    os.execvpe(  # noqa: S606
        "ansible-playbook",  # noqa: S607
        ["ansible-playbook", str(playbook)],
        environment,
    )
