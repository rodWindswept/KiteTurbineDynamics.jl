# Mass-model audit — big-hub / thin-tube / 3-line corner (2026-09-02)

**Status:** SCOPED, with initial findings from the 2026-09-02 session.  This is
the fresh-ticket context for the mass-model audit that gates the 5 kW winner.

**Why:** the 5 kW rotorcount campaign (`v13_5kw_masslift_len18.8_rotorcount`,
completed 2026-08-28) produced a global-best fitness of **9.618 kg**, but its
no-lifter airborne mass is **4.43 kg → φ 0.886 kg/kW**, below the Daisy anchor
(≈1.3).  A first-principles CFRP estimate of the ring set alone is ~2.6× that.
This document captures the repro case, the suspected causes, and what to audit
so the winner is either accepted as physical or re-run on a corrected law.

---

## 1. Repro case — island 1 (global best) genome

```
0.03, 0.0275, 0.513, 1.6, 4.314, 0.862, 2.722, 3.0, -0.173, 1.0, 1.173, 0.153, 0.635, 0.14
```

| gene | value | meaning |
|---|---|---|
| x1 Do_top | 0.03 m | hub tube outer dim 30 mm |
| x2 t_over_D | 0.0275 | wall = 2.75 % of Do |
| x4 Do_scale_exp | 1.6 | Do(r) = Do_top·(r/r_hub)^1.6 |
| x5 r_hub | 4.314 m | hub ring radius |
| x6 r_bottom | 0.862 m | transmission-cylinder radius |
| x7 target_Lr | 2.722 | ring slenderness target |
| x8 n_lines | 3 | triangle TRPT |
| x10 rotor_count | 1 | single rotor (n_active = 1) |
| x13/x14 blade_scale | 0.635 / 0.14 | blade linear scale |

Decoded: 6 rings total (5 transmission at r 0.862 + 1 hub at r 4.314), single
rotor at the hub, 3 lines, 3 blades.

## 2. The two "mass" numbers (not a contradiction)

- **Fitness 9.618 kg** = `expansion_airborne_mass(include_lifter=true)` — the
  airborne structure **plus a fixed 5.0 kg rotary-lifter estimate**.
- **4.43 kg** = `expansion_airborne_mass(include_lifter=false)` — the structure
  alone (what the audit quotes).

So `9.618 ≈ 4.43 + 5.0` (small instrument/rounding difference).  The lifter is
a constant offset; it does not change the DE's *ranking*, only the absolute
fitness label.

## 3. Scoring — what the fitness is (and what changed)

- **Current (V14, 2026-08-20):** `mass_min_fitness(P, FoS, cfg, mass)` =
  **pure `mass`**, with TWO hard reject gates — `FoS < fos_hard` (2.5) → Inf,
  and `P < p_floor` (5.0 kW) → Inf.  FoS and power are *gates*, not scored
  terms.  There is **no soft FoS term** and **no double-counting** here.
- **Previous (V12/V13):** `v12_fitness(P, FoS, cfg)` = `-P/(pw·fw)` where `pw`
  is the power-window penalty and `fw` is the FoS-target penalty (quadratic
  below target, linear above, hard reject below `fos_hard`).  This is the
  "power + FoS combined scoring" Rod recalls.  It scored POWER (more negative
  = better), not mass.

The switch (V14, "hard-constraint mass-minimisation") happened **2026-08-20**
(commit history; runner comment "Replaces the V13 power-scoring (v12_fitness)
with mass_min_fitness").  `mass_min_fitness` lives in `src/objective_v12.jl`.

## 4. Mass model — where the under-count is (investigated 2026-09-02)

The DE's structural mass is `expansion_airborne_mass` (`src/expansion_analysis.jl`):
tether + `(n_ring-1)·p.m_ring` + `n_blades·p.m_blade` + expansion assemblies +
blade-knuckles (`n_blades·0.050`) + lifter.

`p.m_ring` is a **single uniform average** computed in `build_system_from_v10`
(`src/objective_evaluator.jl` ~line 354):

```
r_avg = 0.5·(r_hub + r_bottom)
Do_avg = Do_top·(r_avg/r_hub)^Do_scale_exp
m_ring = n_lines · ρ · π/4·(Do_avg² − (Do_avg−2t_avg)²) · 2·r_avg·sin(π/n_lines)
```

**Finding A — no minimum tube diameter floor.** `Do(r) = 0.03·(r/4.314)^1.6`
gives the transmission rings (r 0.862) a tube of **2.3 mm diameter / 0.06 mm
wall** — 3 g each, physically unmakable.  The DE exploits the steep taper to
make the whole transmission cylinder ~15 g (5 rings × 3 g).  There is a
`t_over_D` floor (0.010) and a per-ring mass floor (0.05 kg applied to the
*average*, not per-ring), but **no minimum absolute Do**.

**Finding B — uniform average vs per-ring sum.**  For the winner the per-ring
true ring mass is:

| ring | r (m) | Do (mm) | wall (mm) | L (m) | mass (kg) |
|---|---|---|---|---|---|
| 1–5 | 0.862 | 2.28 | 0.06 | 1.49 | 0.003 each |
| 6 (hub) | 4.314 | 30.0 | 0.82 | 7.47 | 2.712 |

True summed ring mass = **2.728 kg** vs the model's uniform `5 × 0.317 =
1.586 kg` — a **1.72× under-count**.  The average is dominated by the tiny
transmission rings; the hub ring (2.7 kg) is under-weighted.  A realistic
minimum-Do floor would widen this further (the "crude 2.6×" estimate in
`regate_verdict.md` likely assumed a sane minimum tube size).

**Finding C — ring-vertex knuckles are unpriced in the DE.**  The DE counts
only *blade* knuckles (`n_blades·0.050`).  The line-attachment knuckles at the
ring vertices (≈ `n_rings × n_lines` of them) are priced in the STATIC
optimiser (`knuckle_mass_at_ring`, `src/trpt_optimization.jl`) and in the
economics model (`economics.jl`, 0.015 kg each) but **not** in
`expansion_airborne_mass`.  So the DE gets ring vertices for free.

**Finding D — n_lines = 3 is a triangle.**  A 3-line TRPT is a degenerate
polygon (see `docs/plans/fix_xvector_rerun_sweeps.md` "triangle3").  It is
inside the DE bounds `[3, 16]` but outside the geometry the structural model
(Daisy 6-line, polygon-frame buckling) was validated on.

## 4b. Blocking-consistency gap (found 2026-09-02 — separate from the mass law)

The 0.75× downstream de-rate is applied in the ODE force model
(`src/ring_forces.jl`) and in the rotor sizing (`design_from_vector_v10`), but
**NOT in the cold-start settle equilibrium scan** (`settle_to_operational_state`,
`src/initialization.jl` ~line 903–921).  That scan computes the starting `ω_eq`
from `P_aero_hub` and `P_aero_exp` using the **full** `v_mag` for every rotor,
ignoring `sys.rotor.wind_factor` / `er.wind_factor`.

Consequence: for multi-rotor designs the settle over-estimates aero power (it
assumes the blocked upper rotors see freestream), so it parks `ω` too high; the
ODE then decays from that overshoot to the true blocked equilibrium.  This is
the concrete mechanism behind island 3's gate 7.45 kW (5–30 s) → evaluator
tail5 5.37 kW (45–50 s) decay (the "settle-ODE gap").  Single-rotor winners
(n_active = 1, wind_factor = 1.0) are unaffected.

**Fix:** multiply the scan's `v_mag` by `sys.rotor.wind_factor` in the
`P_aero_hub` term and by `er.wind_factor` in the `P_aero_exp` loop, so the
settle starts from the blocked equilibrium.  This is a blocking-consistency
fix, not a mass-law change; it should land before any re-run is trusted.

## 5. Audit checklist (what the fresh session must decide)

1. **Minimum absolute tube diameter/wall** — floor `Do` (e.g. ≥ 10–15 mm) or
   `t` (e.g. ≥ 0.5 mm) so transmission rings cannot collapse to 2.3 mm / 0.06 mm.
2. **Per-ring mass summation** — replace the single `r_avg` with a sum over
   `ring_spacing_v5` radii (the decode already returns `radii`), so the hub
   ring is priced at its true 2.7 kg.
3. **Ring-vertex knuckle mass** — add `n_rings × n_lines` knuckles (or
   `knuckle_mass_at_ring`) into `expansion_airborne_mass`, matching the static
   optimiser.
4. **n_lines floor** — decide whether `n_lines = 3` (triangle) is admissible;
   floor at 4 or 5 if not.
5. **Re-derive the ring mass vs a CFRP supplier/tube table** at 30 mm / 0.82 mm
   wall and at the Daisy's ring, to anchor the law.

After the audit: fix the law → re-seed → re-run (or re-gate + re-seed), then
acceptance re-baseline.  Do NOT seed the 7 kW rung with island 1 before this.

## 6. Files / functions for the fresh session

- Mass: `src/expansion_analysis.jl` (`expansion_airborne_mass`),
  `src/objective_evaluator.jl` (`build_system_from_v10` ~line 354),
  `src/expansion_rotor.jl` (`expansion_blade_mass`),
  `src/trpt_optimization.jl` (`knuckle_mass_at_ring`, `OPT_KNUCKLE_MASS_KG`),
  `src/parameters.jl` (`M_BLADE_REF_KG = 0.420`).
- Scoring: `src/objective_v12.jl` (`mass_min_fitness`, `v12_fitness`),
  `src/objective_v11.jl` (`v11_fitness`).
- Blocking/clearance: `src/objective_v10.jl` (`design_from_vector_v10`,
  `lowest_rotor_clearance`), `src/ring_forces.jl` (ODE de-rate).
- Winner + verdict: `scripts/results/v13_5kw_masslift_len18.8_rotorcount/best_vector.csv`,
  `.../regate_verdict.md`.
- Campaign runner: `scripts/run_v13_5kw_masslift.jl`; seeds:
  `scripts/compute_seeds.jl`.
- Handover: `handovers/handover-2026-08-28-rotorcount-campaign-complete.md`.

## 7. Related open questions (from the 2026-09-02 discussion)

- **Single-rotor dominance** — re-confirm (it is real — fewer rings/lines/blades
  — but its *magnitude* is inflated by Finding A/B).
- **Island-3 settle-gap** (gate 7.45 kW vs evaluator tail5 5.37 kW) —
  `docs/plans/2026-08-22-settle-ode-gap-workstream.md`.
- **n_lines = 2 flown instability** — consider a stability / overtwist-margin
  term in fitness (separate workstream, see main discussion).
- **fast→ODE result-space mapping** — proposed parallel workstream to cut
  per-eval ODE cost.
