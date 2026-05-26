# Team Direction & Ways of Working — 2026-05-12

Status: brainstorm, not yet implementation
Author: Hermes team (Aero, Robo, Builder, Sparks, Reviewer, Closer) for Rod
Scope: how we work together going forward on KiteTurbineDynamics.jl — not a code change

## Purpose

This is a teambuilding / planning doc, not a coding plan. We've been iterating fast
(see commit log around the Option B disc-tilt revert, bearing mass correction, and the
Sky Anchor node work). Before the next big push we want a shared view of what's
working, what isn't, and how the team should collaborate from here.

## Where we are (snapshot)

- Physics & geometry: strong. PCA-2 autogyro with apparent wind, bridle-tension-network
  tilt (Option B), shared `_build_kite_turbine_system_impl`, Tulloch/Wacker torsional
  analysis all in place.
- Controls & electrical: stub-level. Furl is an open-loop scripted ramp inside
  `_rerun!`. No generator model, no MPPT ceiling, no actuator dynamics.
- Tests: 382 pass, but they are static-geometry tests. Dynamic-stability regressions
  (Sky Anchor frame-1 jump, bearing-ring instabilities) are not caught.
- Repo hygiene: 13 stray `test_*.jl` scratch files at repo root, 4 unmerged plan docs,
  untracked CSV / DOCX artefacts, untracked `lcoe_dashboard.jl`.
- Commercial: LCOE module is clean and pure-functional, but there is no automated
  one-page partner spec sheet yet.

## What each role flagged

### Aero 🌪️
- Wind convention (+X = downwind) has bitten us at least three times. Wants a one-page
  ADR pinned at the top of `CONTEXT.md` so nobody re-derives it from commits.
- `TETHER_DRAG_CD = 1.0` is used everywhere; a furled rotor sees a different Reynolds
  regime. Sensitivity sweep before LCOE numbers are trusted downstream.

### Robo 🤖
- Safety state machine (`:idle / :simulating / :switching`) is the right pattern.
- Furl "controller" is not a controller — no feedback law, no actuator model, no rate
  limits, no saturation. Biggest gap between sim and a fly-able 50 kW system. Needs a
  proper control block diagram before any hardware conversation.

### Builder 🛠️
- v5 campaign 10 kW / 50 kW `power_W` bug (pitfall #11) means the headline "11.47 kg"
  winner was optimised against the wrong torque. 10 kW campaign needs re-running with
  `power_W = 10_000`.
- Knuckle stiffness is emergent from CFRP diagonal length preservation. Defensible but
  not measured — partners will ask for rotational stiffness data.

### Sparks ⚡
- Repo is pure mechanical / aero. No generator model, no MPPT τ = k·ω² ceiling, no
  inverter limits, no thermal model.
- The torsional cascade failure mode (pitfall #12) is literally caused by an unbounded
  MPPT controller. A ~200-line `src/electrical.jl` would let us actually model "what
  does the drivetrain do above rated?" — the whole reason we're modelling furl.

### Reviewer ⚖️
1. Test suite does not protect against the regressions we keep hitting. Need a
   dynamic-stability smoke test: 1s of sim, assert no NaN, hub excursion < 20 m, twist
   < 2π.
2. 13 stray `test_*.jl` files at repo root should move into `test/` or be deleted.
3. Four orphan plan docs in `docs/plans/` are untracked. We're writing plans faster
   than we're closing them.
4. Pattern observed: oscillating between physics models faster than we validate them
   (Option B reverted, bearing mass corrected, Sky Anchor mid-debug).

### Closer 💼
- `lcoe_dashboard.jl` is untracked, no exported figure.
- 10-4-1 partner pipeline needs a one-page automated spec sheet (rated power, AEP at
  partner's site wind class, LCOE, gCO2e/kWh, mass, footprint). Today this is a manual
  screenshot job. A make-target that produces a PDF from a config name would unblock
  outbound.

## Consensus themes

1. **Physics-rich, controls-poor.** Aero / structural / geometric models are excellent;
   control & electrical are stubs. The next big jump is a generator + controller block,
   not another tilt model.
2. **No regression net for dynamic behaviour.** Static tests pass while dynamic
   instabilities slip through. Need scenario-invariant tests before we touch the
   dynamics layer again.
3. **Repo hygiene drag.** Fast iteration is leaving artefacts behind. A 30-minute
   cleanup pass would pay for itself.

## Proposed ways of working

- **Physics-model gate.** Before merging any new physics model, the change must
  include: (a) a one-paragraph entry in `CONTEXT.md` saying what it replaces and why,
  and (b) at least one scenario-invariant test in `test/`.
- **Plan review.** Reviewer gets first look at every plan in `docs/plans/` before
  implementation starts. Rod's grill sessions already do this informally; formalise it.
- **Sparks mandate.** Stub out `src/electrical.jl` with a generator torque map, a
  current limit, and a basic thermal model before the next furl iteration.
- **Closer mandate.** Build the LCOE one-page spec-sheet script as the first
  commercial deliverable, calling into the existing LCOE module.
- **Dashboard as integration surface.** Every role's work must be visible in the
  dashboard. If it can't be seen there, it isn't done.
- **ADR for wind convention.** Aero owns a short ADR (`docs/adr/`) pinning
  +X = downwind, the lift-line attach convention, and the bridle-tilt sign.

## Suggested next concrete steps (not actioned yet)

1. Aero writes the wind-convention ADR.
2. Reviewer drafts the scenario-invariant test list (3–5 tests).
3. Sparks scaffolds `src/electrical.jl` interface (types + function signatures only).
4. Builder re-runs the 10 kW v5 campaign with the corrected `power_W`.
5. Closer drafts the partner spec-sheet template (markdown → PDF via pandoc).
6. Rod does a 30-minute repo-hygiene pass: move stray `test_*.jl` into `test/scratch/`
   or delete, close out the four orphan plan docs.

## Open questions for Rod

- Which of the six next-steps above is highest priority for you?
- Do you want Reviewer to be a literal pre-merge step (e.g. a checklist comment on
  PRs), or stay informal?
- Is the Sky Anchor work blocking, or can it be paused while we shore up controls /
  electrical / tests?
