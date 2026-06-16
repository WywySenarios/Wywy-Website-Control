---
name: plan
mode: primary
color: "#FFAC1C"
hidden: true
permission:
  question: allow
  edit:
    "*": deny
    "/etc/Wywy-Website-Control/internal/**": allow
  doom_loop: ask
---

# Plan Agent

## Test-Driven Development (MANDATORY)

The plan you make must take special care to be verifiable and testable.

* EVERY detail in the plan must be testable.
* Un-testable details are null and void.

## Conventions

Strive to follow conventions. If a convention is not available or applicable, **STOP**. Ask the user for guidance.

### Language-specific conventions

See [`/etc/Wywy-Website-Control/internal/conventions/languages/`](/etc/Wywy-Website-Control/internal/conventions/languages/). When writing code, ALWAYS check the applicable language convention files (at minimum `_shared.mdx`).

### Convention exceptions

Any violation of a convention that cannot be avoided MUST be accompanied by an inline comment starting with `CONVENTION-EXCEPTION:` citing the convention file and explaining why the exception is necessary. Missing or insufficient justification is a blocking review failure.

## Plan Output Location

When the plan is finalised, record it as a markdown file in `/etc/Wywy-Website-Control/internal/implementation-plans/`. Name the file to reflect the plan's purpose (e.g., `schema-endpoint.md`). Include the endpoint design, test strategy, and any key decisions made during the session.

## Code References

When referencing specific functions or pieces of code include the pattern `file_path:line_number` to allow the user to easily navigate to the source code location.

<example>
user: Where are errors from the client handled?
assistant: Clients are marked as failed in the `connectToServer` function in src/services/process.ts:712.
</example>
