---
name: build
mode: primary
color: "#0000FF"
permission:
  question: allow
  edit:
    "*": allow
    "**/tests/**": deny
    "**/test/**": deny
    "**/*.test.ts": deny
    "**/*.spec.ts": deny
    "**/pytest.ini": deny
    "**/vitest.config.*": deny
    "**/docker-compose.test.yml": deny
  doom_loop: ask
---

# Build Agent

## Test-Driven Development (MANDATORY)

This project uses TDD. All AI agents MUST follow:

1. **Red phase** - Write the test first. Run it. It fails. STOP. Wait for user approval to continue.
2. **Green phase** - Write the minimal implementation to pass the test. STOP. Wait for user approval to continue.
3. **Refractor phase** - Clean up without changing behaviour. Tests stay green.

### Enforcement

- No implementation code without a preceeding test.
- Every new feature of bug fix starts with a failing test.
- Test files mirror source files (e.g. `src/x.py` -> `tests/test_x.py`)
- Run full test suite before delcaring any task done.

## Conventions

Strive to follow conventions. If a convention is not available or applicable, **STOP**. Ask the user for guidance.

### Language-specific conventions

See [`/etc/Wywy-Website-Control/internal/conventions/languages/`](/etc/Wywy-Website-Control/internal/conventions/languages/). When writing code, ALWAYS check the applicable language convention files (at minimum `_shared.mdx`).

### Convention exceptions

Any violation of a convention that cannot be avoided MUST be accompanied by an inline comment starting with `CONVENTION-EXCEPTION:` citing the convention file and explaining why the exception is necessary. Missing or insufficient justification is a blocking review failure.

## Bash restrictions

Bash commands may be restricted by agent permissions. When running tests, use:

```bash
/etc/Wywy-Website-Control/run.sh <service> test
```

If a bash command is denied (e.g. `npm install`, `pip`, `python`, `docker`, `git`), **STOP** and ask the user to run it for you or to grant the necessary permission. Do not attempt to work around the restriction.

## Code References

When referencing specific functions or pieces of code include the pattern `file_path:line_number` to allow the user to easily navigate to the source code location.

<example>
user: Where are errors from the client handled?
assistant: Clients are marked as failed in the `connectToServer` function in src/services/process.ts:712.
</example>
