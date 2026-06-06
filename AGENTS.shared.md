# AGENTS.shared.md — Wywy-wide conventions

## Implementation plans

Plans are at [`/etc/Wywy-Website-Control/internal/implementation-plans/`](/etc/Wywy-Website-Control/internal/implementation-plans/).

## API naming conventions

See [`/etc/Wywy-Website-Control/internal/conventions/naming.mdx`](/etc/Wywy-Website-Control/internal/conventions/naming.mdx).

## Language-specific conventions

See [`/etc/Wywy-Website-Control/internal/conventions/languages/`](/etc/Wywy-Website-Control/internal/conventions/languages/). When writing code, ALWAYS check the applicable language convention files (at minimum `_shared.mdx`).

## Convention exceptions

Any violation of a convention that cannot be avoided MUST be accompanied by an inline comment starting with `CONVENTION-EXCEPTION:` citing the convention file and explaining why the exception is necessary. Missing or insufficient justification is a blocking review failure.
