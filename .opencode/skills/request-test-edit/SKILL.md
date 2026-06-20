---
name: request-test-edit
description: Use when any agent determines a test must be modified. Do NOT use for writing new tests (use the RED stage of the TDD cycle for that).
---

# Request a test edit

This skill formalises how **any agent** requests a modification to an existing test. It ensures the request is:

- Traceable to the context that triggered it
- Justified against clear editing rules
- Reviewed before any file is touched

---

## Request template

Every request to edit a test MUST use this template. Paste it into your response or tool call so it is captured in the conversation:

```md
## Test edit request

### Justification
`<one-paragraph explanation of why this edit is necessary>`

### Coverage
`<one-paragraph explaination of changes to test coverage>`

### Behaviour change?

**Context:** `<TDD-stage> / <debug> / <other>`
**Test file:** `<path/to/test_file>`
**Type:** `correction` / `refactor` / `specification-change`
**Behaviour change?: `YES` / `NO`** — `<reasoning here...>`
```

---

## After the edit

1. Run the full test suite for the service:
   ```bash
   /etc/Wywy-Website-Control/run.sh <service> test
   ```
2. Confirm the entire suite stays green (or, if in a TDD RED stage, confirm the intended failure still occurs).
3. Report the result back to the original context (TDD stage, debug session, etc.).
