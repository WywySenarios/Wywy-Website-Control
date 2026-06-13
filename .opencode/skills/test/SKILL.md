---
name: test
description: Run tests. Use when user mentions testing, debugging test failures, or verifying a service. Also use when you have made a potentially breaking change.
---

# Test a Wywy-Website Service

All commands use absolute paths to `/etc/Wywy-Website-Control/`. They work from any working directory -- you do NOT need to be inside a specific service repo.

## Quick start

```bash
# Run all tests for a service (from any directory)
/etc/Wywy-Website-Control/run.sh master-database test
/etc/Wywy-Website-Control/run.sh cache test
```

## Services

| Service | Test type | Test command | Docker containers |
|---|---|---|---|
| master-database | Python integration (`test`) + C valgrind unit (`unit-test`) | `/etc/Wywy-Website-Control/run.sh master-database test` | `test`, `unit_test` |
| cache | Python Django (`test`) | `/etc/Wywy-Website-Control/run.sh cache test` | `test` |
| website | Test compose file exists | `/etc/Wywy-Website-Control/run.sh website test` | `test` |
| agentic | Django pytest (`test`) | `/etc/Wywy-Website-Control/run.sh agentic test` | `django` |
| backup | No containers | — | — |

The `test` compose file layers `docker-compose.dev.yml` + `docker-compose.test.yml` in each service's `docker/` directory. The run script auto-teardowns containers after tests finish.

## Workflows

### 1. Run tests and capture output

Run `/etc/Wywy-Website-Control/run.sh <service> test` to bring up test containers, run tests, and auto-teardown. No `cd` needed.

### 2. Summarize results

After tests complete:

- Extract pass/fail counts from output
- List any test names that failed
- Note any errors, tracebacks, or valgrind leak summaries (for master-database unit tests)
- Reference `/etc/Wywy-Website-Control/config/test_config.yml` for the schema under test

### 3. Suggest fixes

Analyze failure patterns by service:

- **master-database Python integration tests** -- inspect `apps/tests/` in `/usr/local/Wywy-Website/Wywy-Website-Master-Database/`. Failures often stem from:
  - Schema mismatches with `/etc/Wywy-Website-Control/config/test_config.yml`
  - API contract changes in `sql_receptionist` or `sync`
  - Missing/wrong env variables in `/etc/Wywy-Website-Control/config/master-database/.env.dev`
- **master-database C unit tests (valgrind)** -- inspect `apps/unit_tests/` and `apps/sql-receptionist/` in the master-database repo. Leaks or crashes indicate memory bugs in sql-receptionist.
- **cache Django tests** -- inspect `apps/sync/` in `/usr/local/Wywy-Website/Wywy-Website-Cache/`. Likely failures: model changes, URL routing, DB schema drift.
- **agentic Django tests** -- inspect `apps/django/apps/orchestrator/tests/` in `/usr/local/Wywy-Website/Wywy-Codes/`. Failures often stem from:
  - Orchestrator pipeline stage logic changes in `orchestrator.py`
  - Model/serializer changes in `models.py` / `serializers.py`
  - Fixture misconfiguration in `conftest.py`
  - Docker SDK mocking issues (use `_spawn_agent_container` monkeypatch, not real Docker)

## Agentic test logs

The agentic test run writes a summary log to `/var/log/Wywy-Website/agentic/test-summary.log`
on the host.  Individual pipeline orchestrator logs from tests go to temporary directories
(overridden by the `temp_log_root` fixture) and are cleaned up after each test.

```bash
# View test summary after a run
cat /var/log/Wywy-Website/agentic/test-summary.log
```

## Inspecting test containers manually

Auto-teardown shuts down containers after tests. To enter a running test container (before it completes):

### Enter a test container

```bash
/etc/Wywy-Website-Control/enter.sh <service> <container-alias> test
```

Container aliases per service:

| Service | Alias | Actual container | Notes |
|---|---|---|---|
| master-database | `sqlr` | `sql_receptionist` | C11 HTTP API |
| master-database | `pgres` / `psql` / `database` | `postgres` | PG18 database |
| master-database | `unittest` | `unit_test` | C valgrind unit tests |
| cache | `pgres` / `psql` / `postgres` | `database` | PG18 database |
| agentic | `py` / `python` | `django` | Django shell |

For valgrind unit tests run manually inside the container:

```bash
/etc/Wywy-Website-Control/enter.sh master-database unittest test
# Then inside the container:
make clean && make && valgrind --leak-check=yes --show-leak-kinds=definite ./app
```

To keep a test container running without auto-teardown, use `enter.sh` in a separate terminal while the main test run is active:

```bash
/etc/Wywy-Website-Control/enter.sh <service> <container-alias> test
```

## Test config

The config schema for tests is in `/etc/Wywy-Website-Control/config/test_config.yml`. It defines the databases, tables, columns, pointer types, and tagging rules that test datasets are validated against.
