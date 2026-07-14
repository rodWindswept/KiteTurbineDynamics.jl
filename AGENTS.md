# AGENTS.md

Cross-tool entry point for AI agents and human contributors working in this
repository. Claude-specific commands and workflows live in
[`CLAUDE.md`](CLAUDE.md); this file holds the tool-agnostic conventions that
apply to any agent harness (Hermes, Codex, OpenCode, etc.).

## Start here

1. **Domain & context** — [`CONTEXT.md`](CONTEXT.md) and [`DECISIONS.md`](DECISIONS.md)
   at the repo root explain the TRPT kite-turbine physics and the design choices
   behind the current model.
2. **Architecture decisions** — see [`docs/adr/`](docs/adr/) (e.g.
   `0001-inertia-relief.md`).
3. **Developer commands** — the canonical build/test/campaign commands live in
   [`CLAUDE.md`](CLAUDE.md).

## Working agreement

- **Run the suite.** Run `julia --project=. test/runtests.jl` before committing.
  Never commit with a red suite.
- **Physics conservatism.** Physical calculations must conform to the
  BEM-coupled v2/v5 solver formulations described in `DECISIONS.md`.
- **Idempotent scripts.** Report-patching scripts must remain fully idempotent.
- **Formatting.** Run JuliaFormatter (config in `.JuliaFormatter.toml`,
  Blue style) before committing so diffs stay focused on logic.
- **SI units; angles in degrees at the API boundary.** Match existing
  conventions in `src/`.

## Conventions

- New `src/` file → add the matching `include(...)` (and any `export`) in
  `src/KiteTurbineDynamics.jl`, and wire a test file into `test/runtests.jl`.
- Citations and licensing: MIT (`LICENSE`); cite via `CITATION.cff`.

## Skills & issue tracking

See `docs/agents/` — `issue-tracker.md`, `triage-labels.md`, `domain.md`.
