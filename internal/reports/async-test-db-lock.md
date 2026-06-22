# Report: Async Test DB Lock Contention

Date: 2026-06-21  
Author: Scribe Agent  

## 1. Problem Statement

**6 out of 14** tests in `test_orchestrator_async.py` fail with:

```
django.db.utils.OperationalError: database table is locked: orchestrator_pipeline
```

**304 tests pass**, including:
- All `test_handle_stage_failure_*` tests (the `_maybe_save` catch suppresses the error)
- All `test_agent_client.py`, `test_stage_executor.py`, `test_container_manager.py` tests (they mock the DB entirely)
- Every other app test (sync code, no async DB access)

**Test command:** `/etc/Wywy-Website-Control/run.sh agentic test`

---

## 2. Root Cause Analysis

### 2.1 Architecture: Sync ORM From Async Context

The `orchestrator_async.py` module defines `async def` functions that call the Django ORM **synchronously** (without `sync_to_async`):

| File | Line | Call |
|------|------|------|
| `orchestrator_async.py` | 122 | `list(pipeline.stages.all())` |
| `orchestrator_async.py` | 200 | `Pipeline.objects.filter(status="running")` |
| `orchestrator_async.py` | 83 | `Pipeline.objects.filter(status="queued")` |

These are permitted by `DJANGO_ALLOW_ASYNC_UNSAFE=true`.

### 2.2 Thread Isolation

Django 6.0 stores `DatabaseWrapper` in `asgiref.local.Local`, which uses `contextvars.ContextVar`. When `async_to_sync()` (or `asyncio.run()`) is called from a sync test:

1. The sync test function runs on the **main thread** with `db` fixture → `DatabaseWrapper #1` → SQLite connection #1, holding a transaction.
2. `async_to_sync(coroutine)()` runs the coroutine on a **different thread** (docs: *"the async function will execute on a different thread to the calling code"*).
3. The sync ORM call inside the coroutine runs directly on that thread → `DatabaseWrapper #2` → SQLite connection #2.
4. Two connections to the same database → **lock conflict**.

This is **fundamentally a thread isolation issue**, not an `asyncio.run()` vs `async_to_sync()` issue. Both run the coroutine on a different thread.

### 2.3 Why Some Tests Pass

- **`test_handle_stage_failure_*`**: The DB writes are wrapped in `_maybe_save()` which catches `OperationalError` and logs a warning. In-memory assertions (`stage.retry_count == 1`) still pass.
- **`test_agent_client.py`, `test_stage_executor.py`, `test_container_manager.py`**: These mock every DB interaction and never hit the real database from async context.

---

## 3. Attempted Fixes and Outcomes

### 3.1 Fix A: `asyncio.run()` → `async_to_sync()` (attempted, insufficient)

**Change:** Replaced all 33 `asyncio.run(coro)` calls across 4 test files with `async_to_sync(coro)()`.

**Files changed:**
- `apps/django/apps/orchestrator/tests/test_orchestrator_async.py`
- `apps/django/apps/orchestrator/tests/test_agent_client.py`
- `apps/django/apps/orchestrator/tests/test_stage_executor.py`
- `apps/django/apps/orchestrator/tests/test_container_manager.py`

**Result:** Same 6 failures. The docs state `async_to_sync()` still runs the async function on a different thread. It only helps if the async code uses `sync_to_async(thread_sensitive=True)` to return to the main thread — our code calls ORM directly.

```
async_to_sync does NOT solve the problem.
```

### 3.2 Attempted: File-based test DB via `pytest_configure` (unsuccessful)

`apps/orchestrator/conftest.py` sets:
```python
settings.DATABASES["default"]["TEST"]["NAME"] = "/tmp/test_async_orchestrator.sqlite3"
```

**Problem:** The `pytest_configure` hook runs at app-package discovery time, which is too late — Django's `django_db_setup` fixture has already created the test database using the in-memory default. The setting is ignored.

### 3.3 Attempted: File-based test DB via `orchestrator_async.py` import side-effects

`orchestrator_async.py` attempts at lines 34-45:
```python
settings.DATABASES["default"].setdefault("TEST", {}).setdefault(
    "NAME", "/tmp/test_async_orchestrator.sqlite3",
)
```

**Problem:** Uses `setdefault`, so if the `conftest.py` already set it (even though it doesn't take effect), this is a no-op. More fundamentally, by the time the module is imported, the test DB connection may already exist.

---

## 4. Proposed Fixes

### 4.1 Fix B: Rewrite `orchestrator_async.py` as synchronous

**Status: NOT IMPLEMENTED**

**Approach:** Convert all `async def` functions to `def`:
- `run_pipeline`: replace `await cm.wait_healthy()` with `cm.wait_healthy()` (the method is already sync-compatible)
- `main`: replace `asyncio.Event` + `asyncio.wait_for` with `threading.Event` + `threading.Event.wait(timeout=5.0)`, replace `asyncio.Semaphore` with `threading.Semaphore`, replace `asyncio.create_task` with `threading.Thread`
- `reap_orphaned_pipelines`: simply becomes sync — no change needed
- `handle_stage_failure`: already has sync helpers

**Impact on tests:** Tests call functions directly — no `async_to_sync`, no thread hop, single connection, no lock. All 6 failures would resolve.

**Impact on production:** Functions run in the orchestrator daemon thread, same as before. No functional change.

**Cost:** Rewrite `orchestrator_async.py` to use `threading` primitives instead of `asyncio`. Requires changing `await cm.wait_healthy()` to a sync call. The `ContainerManager.wait_healthy` is already a sync method that returns an `AgentClient` — only the polling loop uses `asyncio.sleep`, which becomes `time.sleep`.

### 4.2 Fix C: Wrap all sync ORM calls in `sync_to_async(thread_sensitive=True)`

**Status: NOT IMPLEMENTED**

**Approach:** In `orchestrator_async.py`, replace every direct ORM call with a `sync_to_async` wrapper:

```python
from asgiref.sync import sync_to_async

# Instead of:
stages = list(pipeline.stages.all())
# Use:
stages = await sync_to_async(lambda: list(pipeline.stages.all()), thread_sensitive=True)()
```

With `thread_sensitive=True` AND `async_to_sync()` at the test level, the ORM calls would run on the main thread, sharing the `db` fixture's connection.

**Problem:** Requires pervasive changes to every ORM call site in `orchestrator_async.py` (at least 6-8 locations). Also requires `async_to_sync()` in tests to set up the thread-sensitive routing. Very invasive for the implementation code.

### 4.3 Fix D: File-based test database at the root conftest level

**Status: NOT IMPLEMENTED**

**Approach:** Create a root-level `/app/conftest.py` with a `pytest_configure` hook that sets the test DB to a file before Django creates it:

```python
# /app/conftest.py
def pytest_configure(config):
    from django.conf import settings
    settings.DATABASES["default"]["TEST"] = {
        "NAME": "/tmp/django_test.sqlite3",
    }
    settings.DATABASES["default"]["OPTIONS"] = {
        "timeout": 20,
        "init_command": "PRAGMA journal_mode=WAL",
    }
```

This runs at the very start of pytest discovery, before `django_db_setup`. Multiple SQLite connections to a file-based DB with WAL mode can coexist without lock conflicts — OS file locking handles concurrency properly.

**Concerns:**
- Slower than in-memory (disk I/O)
- Leaves stale `.db` files that need cleanup
- Changes test environment for ALL tests, not just async ones

---

## 5. Recommendation

**Fix B** (sync orchestrator) is the cleanest option because:

1. The async orchestrator doesn't benefit from async — it doesn't serve concurrent requests or do I/O-bound work at scale.
2. The `await` calls in `run_pipeline` are mocked in tests and thin wrappers in production (`cm.wait_healthy` polls with `asyncio.sleep` — trivially replaced by `time.sleep`).
3. Tests become simple sync calls — no `async_to_sync`, no thread isolation issues.
4. The `CONVENTION-EXCEPTION` comment about `DJANGO_ALLOW_ASYNC_UNSAFE` becomes obsolete rather than proliferating.

**Fix D** (file-based DB) is the fallback if keeping the async API is important — but it changes test infra globally and introduces slowdown.

---

## 6. Current State (Post-Fix A)

```
6 failed, 304 passed = 310 total
```

All 6 failures: `sqlite3.OperationalError: database table is locked: orchestrator_pipeline`  
All in `test_orchestrator_async.py`  
All caused by sync ORM reads from async context on a different thread.

### Failing Tests

| Test | Failure Point | Operation |
|------|---------------|-----------|
| `test_reap_orphaned_mark_running_as_failed` | `orchestrator_async.py:200` | `Pipeline.objects.filter(status="running")` |
| `test_reap_orphaned_does_not_affect_queued` | `orchestrator_async.py:200` | `Pipeline.objects.filter(status="running")` |
| `test_run_pipeline_starts_container` | `orchestrator_async.py:122` | `list(pipeline.stages.all())` |
| `test_run_pipeline_calls_execute_stage_for_each_stage` | `orchestrator_async.py:122` | `list(pipeline.stages.all())` |
| `test_run_pipeline_stops_container_on_completion` | `orchestrator_async.py:122` | `list(pipeline.stages.all())` |
| `test_semaphore_limits_concurrent_pipelines` | `orchestrator_async.py:122` + `refresh_from_db()` | `list(pipeline.stages.all())` |
