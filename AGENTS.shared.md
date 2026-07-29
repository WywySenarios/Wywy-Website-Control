# AGENTS.md — Wywy (shared via Wywy-Website-Control)

This file lives in the [Wywy-Website-Control](https://github.com/wywy/website-control) repo and is symlinked (or copied) into every Wywy repo at the root. It is the single source of truth for how agents should operate across all Wywy projects.

## Testing

ALWAYS prefer to use root level test.sh to run tests. That is the default entrypoint for CI.

## Wywy-Docs MCP tools

The tools and their parameters are listed in your system prompt. Use them.

### When to use them

**Use `search_docs` first**, especially when you need to find or follow relevant documentation, conventions, or code patterns. This applies to any task — not just documentation work. You should reach for these tools before writing code or answering a question about the project.

Use `get_doc` to read a specific document when you already know its path.

### What's in the docs

All content lives under two top-level directories in the Wywy-Docs repo:

**`docs/`** — operators / setup

- `architecture/` — system architecture, infrastructure, service topology
- `data/` — data model, functions, selectors

**`internal/`** — developers / planning

- `conventions/` — code conventions (naming, documentation, agent prompts, filesystem permissions)
  - `conventions/languages/`
  - `conventions/tech-stack/` — Astro, Django, React, Tailwind, Docker, configuration, etc. conventions
- `implementation-plans/` — feature and migration plans
- `reports/` — test reports, analyses
- `services/` — service definitions (repos, containers, CI)
- `todo/` — task tracking

**If you're about to write code, there's likely a conventions doc for it.** If there isn't, **stop** and discuss with the user a good convention to lay the foundation. Search before you write.

### Anti-patterns

- **Don't** write code that contradicts documented conventions without asking the user first.
- **Don't** guess a doc path — use `search_docs` to find it.
- **Don't** ask the user "can you point me to the conventions doc?" — search for it yourself.
- **Don't** skip the tools because you think you already know the answer — the docs are the source of truth.
- **Don't** proceed without following or documenting conventions.

The tools are fast (sub-second for search, instant for get_doc) and the docs are the source of truth for all Wywy projects. Use them at the start of every task.

### Writing documentation

Use `write_doc` to create or update documentation files. The tool accepts content and frontmatter separately — `published` and `last_updated` are auto-populated.

**If `write_doc` returns an error, STOP.** Do not attempt to write the file yourself, do not retry silently. Report the error to the user and explain what went wrong. The tool may have partially written the file but failed to update the search index — proceeding without a correct index will cause the documentation to be invisible to `search_docs`.

### Documentation conventions

- `docs/` is user-facing documentation.
- `internal/` is developer-facing documentation.
- If a new section or subfolder of documentation is beneficial, **stop** and ask the user to create the folder(s)
- Use `gettimestamp.sh` from the control repo when writing a date into documentation.

### Code conventions

Repository-specific language and tech-stack conventions are documented in `internal/conventions/languages/` and `internal/conventions/tech-stack/` in the Wywy-Docs repo. Search before you write code.
