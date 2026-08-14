# CLAUDE.md — Developer & Agent Guide

Welcome to the **KiteTurbineDynamics.jl** workspace. This guide contains key entry points, domain documents, and standard execution commands for developers and agent sessions.

**Before acting on any instruction:** reflect back what you understand the user to be asking — summarise the request, the intent as you read it, and the action you propose to take. Do not proceed on hunches or intuition. Wait for the user to confirm your understanding before executing. We agree on the course of action first, then act. Only deal in facts. If there is something unclear, something you don't understand or know, ASK! If there's something hard to do, something confusing or you're unsure ASK. If there's something which does not make scientific sense, If there's logic lacking, ASK.

## ── Domain Documentation ──────────────────────────────────────────────

This repository uses a single-context domain documentation layout:
* **Core Context**: [CONTEXT.md](CONTEXT.md) at the repository root — domain vocabulary, architecture, campaign history, source map.
* **Design & Optimization Decisions**: [DECISIONS.md](DECISIONS.md) at the repository root — 2,252-line running decision log.
* **Changelog**: [CHANGELOG.md](CHANGELOG.md) — user-facing version history.
* **Architectural Decisions**: [docs/adr/0001-inertia-relief.md](docs/adr/0001-inertia-relief.md)
* **Agent domain docs**: [docs/agents/domain.md](docs/agents/domain.md)

## ── Essential Reads Before Any KTD.jl Session ────────────────────────

In order: `CONTEXT.md` → `DECISIONS.md` (last ~200 lines) → `handovers/` (most recent file) → `docs/plans/` (active plan).

## ── Developer Commands ────────────────────────────────────────────────

### Julia Package & Test Commands

* **Run Entire Test Suite** (23 test files):
  ```bash
  julia --project=. test/runtests.jl
  ```
  Use `script -q -c "julia --project=. test/runtests.jl" /dev/null` for live output (Julia buffers stdout).

* **Launch Interactive Dashboard** (GLMakie):
  ```bash
  julia --project=. scripts/interactive_dashboard.jl           # V1
  julia --project=. scripts/interactive_dashboard.jl --v2      # V2 cockpit
  ```

### DE Campaigns (V6.2 → V10)

* **Clear Julia cache** before any campaign (critical — stale .ji files cause silent errors):
  ```bash
  rm -f ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.ji ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.so
  ```
* **Run V10 campaign** (14-DoF, unified rotors):
  ```bash
  julia --project=. --threads=auto scripts/run_v10_campaign.jl
  ```
* **Verify a campaign result** against current code:
  ```bash
  julia --project=. -e 'using KiteTurbineDynamics; ... evaluate_design(...)'
  ```

### Controller & Headless Simulation

* **k_mppt bisection hunt** (finds P_rated operating point):
  ```bash
  julia --project=. scripts/hunt_kmppt_bisect.jl
  ```
* **Headless trace recording** (6 scenarios, open-loop vs soft-ramp):
  ```bash
  julia --project=. scripts/record_ramp_traces.jl
  ```
* **Publication charts** from ramp traces:
  ```bash
  python3 scripts/plot_ramp_traces.py
  ```

### Structural Diagnostics

* **Per-ring FoS sweep** (identify which rings buckle):
  ```bash
  julia --project=. scripts/sweep_v10_ring_detail.jl
  ```
* **3D design overlay** (compare 2+ TRPT designs):
  ```bash
  julia --project=. scripts/overlay_designs.jl
  ```

## ── Development Guidelines ────────────────────────────────────────────

1. **Run the test suite before committing.** 23 test files. Never commit with red.
2. **Physics conservatism.** The TRPT rotor model must conform to BEM-coupled v2/v5 formulations. Expansion rotor model uses simplified 2D blade-element. Setting `N_expansion = 0` must produce bit-for-bit identical results to v5 (FR4).
3. **Always use `run_canonical_sim!()`** for headless simulation — never hand-roll integrators.
4. **Idempotent scripts.** Report-patching scripts must remain fully idempotent.
5. **Progressive CSV saves.** Write each scenario's CSV immediately after completion, not all at the end.
6. **Clear Julia cache after src/ edits.** `rm ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.ji`

## ── Agent Skills (for Hermes Agents) ──────────────────────────────────

When working in this repo, load skills in this order:
```
/skill windswept-knowledge    ← Company knowledge, drive structure, campaign table
/skill awe-knowledge          ← AWE domain science, papers, SQLite index
/skill tdd                    ← Test-driven development
/skill ktd-simulation-workflow ← Dashboard/headless parity, controller tuning, TRPT physics
```

Additional skills load as needed: `ktd-headless-analysis`, `ktd-controller-analysis`, `ktd-v6-campaign-workflow`.

### Agent skills — repo configuration

Read by `to-tickets`/`to-issues`, `to-spec`/`to-prd`, `triage`, and `wayfinder`.

**Issue tracker.** GitHub Issues on `rodWindswept/KiteTurbineDynamics.jl`, driven by the `gh` CLI. Covers issue create/read/list/label/close, the PRs-as-triage-surface flag (currently off), and the `wayfinder` map-and-child-ticket operations. See [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md).

**Triage labels.** The five canonical roles, each label string equal to its name: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See [`docs/agents/triage-labels.md`](docs/agents/triage-labels.md).

**Domain docs.** Single-context. `CONTEXT.md` (vocabulary, architecture) and `DECISIONS.md` (running decision log) at the repo root; ADRs in `docs/adr/`. Agent onboarding — repo map, physics rules, quick start — is in [`docs/agents/domain.md`](docs/agents/domain.md). Also see [`docs/agents/instrument-trust-log.md`](docs/agents/instrument-trust-log.md) for sanity bounds and [`docs/agents/genome-glossary.md`](docs/agents/genome-glossary.md) for DE genome terms.

## ── Key Files ──────────────────────────────────────────────────────────

| File | Role |
|------|------|
| `src/simulation.jl` | `run_canonical_sim!` — canonical integrator |
| `src/soft_ramp_controller.jl` | RampController state machine |
| `src/objective_v10.jl` | V10 DE objective (rotor masks, tension gate) |
| `src/ring_forces.jl` | Rotor aero, generator torque, expansion forces |
| `src/initialization.jl` | Settle pipeline, equilibrium ω scan |
| `scripts/interactive_dashboard.jl` | Dashboard launcher |
| `scripts/hunt_kmppt_bisect.jl` | Bisection k_mppt hunt |
| `scripts/builders_util.jl` | GUI-free system builders |
| `DECISIONS.md` | 2,252-line decision log |
| `CONTEXT.md` | Domain vocabulary + architecture |
| `docs/agents/instrument-trust-log.md` | Fault ledger, sanity bounds, pre-flight checklist |
