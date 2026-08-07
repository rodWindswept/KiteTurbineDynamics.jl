# Handover — 2026-08-07: Phase A v2 DE audit fixes (F4b/F1/F5/S1–S3)

**For the desktop session: pull, read `handovers/findings-2026-08-07-phase-a-v2-de-audit.md` (the audit this fixes), then run the campaign. Full suite green on this commit.**

## TL;DR

The 2026-08-06 campaign's "44.2 kW best" was an artifact of two bugs:

1. **F4b — `analyse_ring` campaign path disagreed with the design path.** The
   `design === nothing` branch hard-coded the tube taper exponent to 0.5 and
   floored t_over_D at 0.05, while the design branch used the genome's
   `Do_scale_exp` (x4) and raw t_over_D. The campaign simulated tubes ~10×
   stiffer and 7.5× heavier than the genome specified → FoS 165–654 with
   util_axial ≈ 1e-5. **Fixed**: sys carries `ring_Do_scale_exp` + `ring_r_hub`
   refs; both branches now compute the same Do(r) = Do_top·(r/r_hub)^exp.
2. **F1 — the seed was outside its own search box in 5 of 15 dims** (x1=0.06
   vs Do_lo=0.20, x3, x5, x11, x12) and made 0.39 W. Every DE trial clamped to
   the boundary. **Fixed**: reseeded with the best in-box genome (`79e2d24b`,
   P=44.2 kW) and made resume era-filtered so stale pre-fix fitness can't be
   reused.

Also fixed while in there: F5 (stationarity penalty + 120 s relax), S1 (dead
x15 gene removed from search), S2 (k clamp widened + degenerate-bracket skip),
S3 (lift_tension_N column now real newtons).

**No number in the old CSV is quotable.** The next run is the first under
corrected physics.

## What changed (all committed on master)

### F4b — analyse_ring branches reconciled (`src/`)
- `src/types.jl` + `src/initialization.jl`: `KiteTurbineSystem` gains
  `ring_Do_scale_exp` and `ring_r_hub` refs (defaults 0.5 / 0.0 → legacy √R).
- `src/objective_v11.jl` (`build_system_from_v10`): populates the refs from
  the genome; ring-mass calc now uses `design.Do_scale_exp` (was hard-coded √R).
- `src/builders_util.jl`: tight-builder path populates the refs (x[4], x[5]).
- `src/ring_element_analysis.jl` + `src/dynamics.jl`: campaign branch uses
  `(R/r_hub)^Do_scale_exp` with raw t_over_D — identical to the design branch.
- **Audit correction**: the audit's "radius mismatch" claim (p.trpt_hub_radius
  vs design.r_hub) is WRONG for the campaign — `build_system_from_v10` rebuilds
  `pc` with `trpt_hub_radius = design.r_hub`, and the sim/analysis get `pc`.
  The real disagreements were the exponent and the t_over_D floor.
- Test: `test/test_ring_element_analysis.jl` Test 10 — both branches agree on
  N_crit/M_el; x4 has an effect.

### F1 — reseed + era-filtered resume (`scripts/run_feasibility_phase_a.jl`)
- `X_V10` (outside box in 5 dims, 0.39 W) → `X_SEED` = `79e2d24b` (in-box,
  verified against `search_bounds_v11`).
- `PHYSICS_ERA` → `post-4894787_f4b-taper-reconcile`.
- `load_existing_hashes` filters by `physics_era` — a resume can no longer
  reuse pre-fix fitness values. (Also fixes the audit's S9 resume trap.)

### F5 — stationarity (`src/objective_v11.jl`, `src/objective_feasibility.jl`)
- `WARM_RELAX_S[] = 120.0` set in the **launcher only** (source default stays
  10 s so the test suite doesn't run 3.75× longer — learned the hard way).
- Stationarity soft penalty: excess swing beyond the gate's 20%-of-mean adds
  λ=10 per unit to `v11_fitness` AND to `objective_feasibility` (the function
  the DE actually ranks on). A steady 40 kW now outranks a swinging 44.2 kW.

### S1 — x15 removed from search (`src/objective_v11.jl`)
- `TRPT_V11_DIM` 15 → 14; `search_bounds_v11` = v10 bounds.
- The **k-bracket stays** (Gate-1 lesson: never trust a single k). k is owned
  by the bracket's λ²-scaled prior × {0.5, 1, 2}; the objective's internal
  x[15] channel receives the bracket's k. 15-D legacy vectors still accepted
  (sliced). CSV x15 column records `log10(k_chosen)`.
- PRD 0007 + genome-glossary updated to match.

### S2 — k clamp + degenerate bracket (`src/objective_v11.jl`)
- `K_MPPT_MAX` 1000 → 5000 (both cold and warmstart clamps).
- Bracket skips duplicate k_try (when k_prior·0.5 > ceiling, all three points
  collapsed to one → three identical ~10-min sims for one data point).

### S3 — lift_tension_N is real newtons (`src/objective_v11.jl`, launcher)
- `objective_v11_warmstart` collects per-sample `T_lift` and returns its mean
  (falls back to the sized device's `T_ref`); bracket threads it through;
  launcher writes it to `lift_tension_N` (was the dimensionless LIFT_MARGIN=1.5
  constant). The sim always sized lift per-genome — only the CSV column lied.

## Verification

- **Full suite: 1861/1861 pass** (this commit). 21 min.
- F5 unit checks: swinging 44.2 kW ranks below steady 40 kW; backward-compat
  when P_range omitted.
- Seed smoke test: decodes (4 rotors, 15 lines, 11 rings), builds, refs
  populated, inside box.

## What the desktop should do

1. `git pull`, read this + the findings doc.
2. **Run the campaign**: `julia --project=. scripts/run_feasibility_phase_a.jl`
   (48 evals, ~7 h at 120 s relax — the era filter starts it fresh, and the
   seed re-evaluates under corrected physics).
3. When it finishes, **re-run the altitude trace** on the best genome:
   `julia --project=. scripts/trace_altitude_torque.jl <best-hash-prefix>`
   — the spin-down verdict from the old-era genomes has NOT been verified on
   the corrected physics. This is the key open question: does the machine hold
   steady state at 120 s now that the structure is real?
4. Check `lift_tension_N` in the CSV — should now be per-genome newtons
   (~6,000 N for the seed's 388 kg airborne), not 1.5.

## Known limitations / next candidates

- **F5's 120 s relax × 48 evals is expensive** (~7 h). If the first gens are
  all dead again, the conclusion is verdict-B (sampled envelope non-viable),
  not a measurement artifact — that's a search-space conversation, not code.
- `POP_SIZE = 8` in a 14-D space (audit S7) — structurally confined to ≤7-D
  affine subspaces; consider 10×D ≈ 140 if the next run also struggles.
- Test suite is ~21 min (mostly warmstart ODE tests) — Rod flagged CI
  optimisation as a separate task; don't fold into the campaign.
- `docs/agents/exploit-register.md` rows may need updating for the fixed x4
  (no longer dead) and the reseed.
