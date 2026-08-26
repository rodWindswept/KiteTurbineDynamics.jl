# Contributing to KiteTurbineDynamics.jl

KiteTurbineDynamics.jl is the primary TRPT kite-turbine dynamics solver. It is
MIT-licensed and actively developed. Contributions are welcome.

## How to contribute

Contributors work by fork and pull request. Nobody pushes to `master` directly.

1. Fork the repository on GitHub.
2. Clone your fork.
   ```bash
   git clone https://github.com/<your-username>/KiteTurbineDynamics.jl.git
   cd KiteTurbineDynamics.jl
   ```
3. Create a branch off `master`. Name it for the work, e.g. `bem-crossvalidation`.
4. Make your change. Run the tests below.
5. Push the branch to your fork.
6. Open a pull request against `rodWindswept/KiteTurbineDynamics.jl`.

Rod reviews and merges. Expect questions about physics before style.

## Set up

Julia 1.12. Instantiate the environment, then run the suite:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. test/runtests.jl
```

The fast suite is 1,964 tests across 44 files and takes about 3.5 minutes. It
must be green before you start. If it is not green on a clean checkout, open an
issue. That is a bug we want to hear about.

Run a single file directly:

```bash
julia --project=. test/test_ring_forces.jl
```

## Tests

Two suites, and the split matters:

- **`test/runtests.jl`**: fast static unit tests, ~3.5 min. Run before every
  commit. Never commit with a red suite.
- **`test/acceptance_runtests.jl`**: five slow ODE acceptance tests, ~18 min,
  run in parallel. Run these before any merge that touches `src/` physics.
  See `DECISIONS.md` [2026-08-20].

A test that runs an ODE window of 20 to 30 simulated seconds is an acceptance
test. Put it in `test/acceptance_runtests.jl`. Never put it in
`test/runtests.jl`.

State in your pull request which suites you ran and what they returned.

## Wiring new files

- Every new `src/` file gets a matching `include` in `src/KiteTurbineDynamics.jl`.
- Public names go in the `export` block.
- Every new static unit test gets an `include` in `test/runtests.jl`.

## Conventions

- **Physics conservatism.** Physical calculations must conform to the
  BEM-coupled v2/v5 solver formulations in `DECISIONS.md`. Do not substitute a
  different formulation without raising it first.
- **Expansion-rotor invariant (FR4).** `N_expansion = 0` must produce
  bit-for-bit identical results to v5. A change that breaks this is a
  regression, not a feature.
- **SI units.** Angles are in degrees at the API boundary. Match the existing
  conventions in `src/`.
- **Idempotent scripts.** Report-patching scripts must stay fully idempotent.
- **Formatting.** Run JuliaFormatter before committing. The config is
  `.JuliaFormatter.toml`, Blue style. This keeps diffs focused on logic.

## Writing discipline

Documentation, captions, and code comments follow ASD-STE100, the aerospace
simplified technical English standard:

- Use active voice.
- Use one name for one thing.
- Drop hedges. State the finding.
- Keep sentences short.
- Use no semicolons. Write two sentences.

Lint captions with `python3 ste-lint.py <file>`.

## Read before you start

1. **Domain and context**: `CONTEXT.md` explains the TRPT kite-turbine physics.
2. **Decisions**: `DECISIONS.md` documents every architectural choice from V6
   through V10, including the mistakes and the simulator-integrity audit of
   July 2026. We keep invalidated results visible. The drift history is part of
   the record.
3. **Architecture decisions**: `docs/adr/`, e.g. `0001-inertia-relief.md`.
4. **Campaigns**: the V10 Tight PCA landscape and the non-dimensional physics
   atlas visualise the 14-dimensional design space. See `scripts/`.
5. **Reproducibility**: `REPRODUCIBILITY.md`.

`AGENTS.md` holds the tool-agnostic working conventions. `CLAUDE.md` holds the
Claude-specific commands.

## Where help is most valuable

In priority order. These mirror the Known Limitations in the technical report:

1. BEM and lifting-line cross-validation of the constant-C_L expansion rotor model.
2. Wake interaction between rotors. Downstream rotors currently see freestream.
3. A dynamic-aware objective function for the DE optimiser. The static solver
   under-predicts dynamic `k_mppt` by about 3.3 times.
4. Structural blade design. Blade mass currently assumes a constant-thickness skin.
5. Hardware validation of anything. Every result here is simulation-only.

## Citing

Cite via `CITATION.cff`. The licence is MIT. See `LICENSE`.

## Questions

Email Rod Read at rod@windswept.energy, or open an issue. Direct email is
preferred for initial discussions.
