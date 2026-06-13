---
name: commit
description: Commit changes in a Wywy service repository. Use when the user asks to commit, save work, or make a commit.
---

# Commit changes

MISSION CRITICAL: You may only run `git add` and `./commit.sh`.

## Service table

| Service name | Repo path | Has submodules |
|---|---|---|
| `control` | `/etc/Wywy-Website-Control` | No |
| `cache` | `/usr/local/Wywy-Website/Wywy-Website-Cache` | Yes |
| `website` | `/usr/local/Wywy-Website/Wywy-Website` | No |
| `backup` | `/usr/local/Wywy-Website/Wywy-Website-Backup` | No |
| `master-database` | `/usr/local/Wywy-Website/Wywy-Website-Master-Database` | Yes |
| `agentic` | `/usr/local/Wywy-Website/Wywy-Codes` | No |

## Flag table

| Flag | Long form | Behavior |
|---|---|---|
| *(none)* | — | Commit staged changes in the parent repo only. |
| `-r` | `--recurse-submodules` | Commit inside each dirty submodule first, then commit the parent repo. Clean submodules are skipped. |

## Workflow

### 1. Stage changes

The script does NOT stage — you must stage everything yourself before running it. Bundle reevant changes together. Each commit should focus on exactly one modification. You are encouraged to make multiple commits to avoid bundling unrelated commits.

### 2. Commit script

The message follows `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`.

```bash
# Parent repo only
/etc/Wywy-Website-Control/.opencode/skills/commit/commit.sh <service_name> "<message>"

# Recurse into submodules
/etc/Wywy-Website-Control/.opencode/skills/commit/commit.sh -r <service_name> "<message>"
```