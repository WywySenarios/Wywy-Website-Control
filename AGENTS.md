# AGENTS.md — Wywy-Website-Control

Control commands (run, enter, pull, purge) — see [`docs/wywy-website-control.mdx`](docs/wywy-website-control.mdx).

## Conventions

### Error handling: invalid states

Throwing (or returning an error result) when a state is invalid is **highly encouraged**. Do not silently ignore or mask invalid states — let them fail fast and loud so the root cause is found early.

If a state is **expected to be temporarily invalid** (e.g., during a multi-step migration, partial initialization, or transitional phase), **stop and ask the user for permission before continuing implementation**. Do not assume the user is aware of the temporary invalidity or has accounted for it in the overall design.
