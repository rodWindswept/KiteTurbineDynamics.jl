# Future work & reporting plan (2026-09-02)

Status of the 5 kW corrected campaign: **valid winner landed** (island 1,
fitness 18.49 kg — single rotor, n_lines 3, r_hub 4.32 m, P 5.41 kW, FoS 17.19,
no-lifter mass 10.94 kg).  See
`scripts/results/v13_5kw_masslift_len18.8_rotorcount/regate_verdict.md`.

This document captures the follow-on work Rod wants, in the order it should be
picked up.  Each item is a self-contained new-session seed.

---

## 1. Visual check — interactive dashboard

Look at the winner in the dashboards before reporting on it:

```bash
julia --project=. scripts/preview_genome_geometry.jl --headless        # PNG
julia --project=. scripts/preview_genome_geometry.jl                  # GLMakie 3D
julia --project=. scripts/interactive_dashboard.jl --v2               # V2 cockpit
```

`preview_genome_geometry.jl --csv scripts/results/v13_5kw_masslift_len18.8_rotorcount/best_vector.csv`
renders the specific winner.  Goal: eyeball the single-rotor / 3-line / r_hub
4.32 m form (the three-section geometry + the triangle TRPT) and confirm it
looks sane in 3D, not just numerically.

## 2. Structure over-conservatism (FoS 17) — note, do not re-run

The winner has FoS **17.2** against the 2.5 floor.  That suggests the baseline
30 mm OD / 2 mm wall is **over-conservative for 5 kW** — there is real room to
shed structure.  **Not worth a re-campaign yet.**  Just:
- record the finding (done in `regate_verdict.md`);
- when the structure is next touched, consider relaxing the 30 mm / 2 mm
  baseline (or making it a swept knob) rather than treating it as a floor.

## 3. Thorough reporting plan

Rod wants a full report on *how this result came about*, to the repo's best
charting + reporting standards.  Scope to plan (not write yet):

- **Narrative:** the chain from the 08-28 VOID winner → mass-model audit (three
  weight bugs + the settle-blocking consistency gap) → the fitness redesign
  (appropriateness + safety) → the corrected mass law (2 mm wall, per-ring sum,
  ring knuckles) → the re-seed (Do 0.08) → the re-run → the 18.49 kg winner.
- **Charts:** (a) the mass correction on the old winner (4.4 → 10.9 kg) before/
  after; (b) per-ring mass profile (the hub ring vs transmission rings) showing
  why the average shortcut under-counted; (c) island convergence (fitness vs
  generation, three islands); (d) the winner's geometry profile (radius vs
  shaft length).  Reuse `scripts/overlay_designs.jl`, `analyze_campaign_winners.jl`,
  and the `chart_style.py` conventions.
- **Decisions trail:** cite DECISIONS [2026-09-02], the audit doc, and the
  regate verdict.

## 4. 1.5 kW campaign (Daisy scale)

What would our method find at the Daisy's own scale?  The existing
`scripts/compute_seeds.jl` `seed_genome` already has a 1.5 kW path (`RUNGS`
includes 5.0 but the Daisy anchor is 1.5 kW; the runner's `--length` + `KW`
constants would need a 1.5 kW variant).  Scope: re-derive the 1.5 kW seed and
bounds from the Daisy reference (r_hub 1.52 m, tether 10.31 m, 6 lines) with the
corrected mass model, and run a small campaign as a validation anchor against
the measured machine.  This also sanity-checks the method against a real
field machine.

## 5. Tidal device (future, separate domain)

Rod's future-work sketch — capture verbatim so it is not lost:

> What system requirements does a neutrally buoyant kite turbine, axially
> aligned to tidal flow, with Ground Station attached to a buoy suspended in
> the water column (so that the blade tips sit 1.3 m under the surface), given
> the flow characteristics of EMEC in Orkney, have?

Key differences from the wind model to carry into scoping:

- **Fluid:** seawater (ρ ≈ 1025 kg/m³ vs air 1.225 — ~800× denser), so forces
  scale hugely; drag/tension models, Reynolds regime, and the aerodynamics
  (hydrodynamics) tables all change.
- **Flow:** tidal current (reversing, ~1–3 m/s at EMEC Orkney), not wind shear.
- **Buoyancy:** neutrally buoyant structure — buoyancy vs gravity replaces the
  lift-kite tension path; the "ground station on a buoy" changes the anchor/
  ground-ring boundary condition.
- **Depth constraint:** blade tips 1.3 m under the surface — a hard geometric
  constraint analogous to the ground-clearance gate, but with a free surface.
- **Site:** EMEC (European Marine Energy Centre, Orkney) — use its measured
  tidal-current statistics.

This is a new physics domain (BEM → marine hydrodynamics, lift-kite → buoyancy
trim).  It needs its own proposal and literature check before touching `src/`.

---

## Carrying into new sessions

Each § above is a separate new-session seed.  The state they all start from:
`master` HEAD with the corrected mass model + fitness + seed (commits
`cb12183` and earlier), the campaign results in
`scripts/results/v13_5kw_masslift_len18.8_rotorcount/`, and the acceptance
re-baseline in progress (see `docs/plans/2026-08-22-acceptance-rebaseline.md`).
