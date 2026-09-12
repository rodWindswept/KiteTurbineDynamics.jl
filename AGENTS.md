# AGENTS.md

Cross-tool entry point for AI agents and human contributors working in this
repository. Claude-specific commands and workflows live in
[`CLAUDE.md`](CLAUDE.md); this file holds the tool-agnostic conventions that
apply to any agent harness (Hermes, Codex, OpenCode, etc.).

## Start here

1. **Structure & load path (read first)** — [`docs/agents/physics-topology.md`](docs/agents/physics-topology.md)
   names every line in the lift chain, states the taut-chain and per-ring
   rotor-model rules, and carries the pre-flight checklist. **Mandatory before any
   geometry, tension or load-path work** — this is where the repeated
   "re-derived it from expectation instead of from the record" mistakes live.
2. **Domain & context** — [`CONTEXT.md`](CONTEXT.md) and [`DECISIONS.md`](DECISIONS.md)
   at the repo root explain the TRPT kite-turbine physics and the design choices
   behind the current model.
3. **Architecture decisions** — see [`docs/adr/`](docs/adr/) (e.g.
   `0001-inertia-relief.md`).
4. **Developer commands** — the canonical build/test/campaign commands live in
   [`CLAUDE.md`](CLAUDE.md).

## Working agreement

- **Run the suite.** Run `scripts/ktd-julia test/runtests.jl` before committing
  (fast unit tests, 50 files, ~2.6 min). Never commit with a red suite. Plain
  `julia --project=.` does not work in this sandbox — see [`CLAUDE.md`](CLAUDE.md).
- **Acceptance tests.** The eight slow ODE acceptance tests live in
  `test/acceptance_runtests.jl` (~18 min, parallel). Run them before a merge
  that touches `src/` physics. See DECISIONS.md [2026-08-20].
- **Physics conservatism.** Physical calculations must conform to the
  BEM-coupled v2/v5 solver formulations described in `DECISIONS.md`.
- **Idempotent scripts.** Report-patching scripts must remain fully idempotent.
- **Formatting.** Run `scripts/ktd-format` (JuliaFormatter, config in
  `.JuliaFormatter.toml`, Blue style) before committing so diffs stay focused on
  logic.
- **SI units; angles in degrees at the API boundary.** Match existing
  conventions in `src/`.
- **Re-derive nothing about the structure.** The lift chain, line names, rotor
  models and standing geometry are recorded in
  [`docs/agents/physics-topology.md`](docs/agents/physics-topology.md). Run its
  **pre-flight checklist** before any geometry, tension, load-path or rotor-model
  work. If you are about to "simplify" the load path or the ring model, stop and
  read it first — re-deriving these from expectation has repeatedly cost a session.
- **Tension-only means tension.** Every line above the ground ring must be taut at
  the operating point. Slack is a defect to diagnose, never a resting state.

## Conventions

- New `src/` file → add the matching `include(...)` (and any `export`) in
  `src/KiteTurbineDynamics.jl`. Wire a STATIC unit test into `test/runtests.jl`.
  A test that runs an ODE window (20-30 s simulation) is an acceptance test:
  put it in `test/acceptance_runtests.jl`, never in `test/runtests.jl`.
- Citations and licensing: MIT (`LICENSE`); cite via `CITATION.cff`.

## Skills & issue tracking

See `docs/agents/` — `physics-topology.md` (structure, load path, rotor models),
`issue-tracker.md`, `triage-labels.md`, `domain.md`,
`instrument-trust-log.md` (instrument fault ledger).
