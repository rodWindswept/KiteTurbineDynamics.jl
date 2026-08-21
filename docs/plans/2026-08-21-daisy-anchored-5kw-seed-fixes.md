# Daisy-anchored 5 kW seed fixes — plan + record (2026-08-21)

**Status:** implemented on desktop; k sweep in flight; re-smoke pending sweep result.
**Scope:** resolve the Daisy-seed stall that blocks the 5 kW mass-min re-run
(handover 2026-08-20-model-scaling-daisy-anchor.md, "THE OPEN TASK").

## Diagnosis (reproduced on desktop, scripts/diag_daisy_seed_stall.jl)

The seed does NOT stall in the ODE sense — a ω trace shows ω_gnd settling from
the settle's 15.45 rad/s to a **sustained 7.87 rad/s equilibrium**. The
generator gain was the killer: `params_at_length` theory-scaled k_mppt from
`params_10kw` (10 kW DRR design) → k = 1.94, so the machine sat at
P = k·ω³ ≈ **0.95 kW** — an order of magnitude below the 5 kW floor.

Additional defects found en route (all Rod-approved fixes):

1. **`r_bottom` decoder clamp** `clamp(x[6], 1.5, 8.0)` (src/ring_spacing.jl) —
   50 kW-era floor silently forced every small-rung genome to r_bottom = 1.5 m
   (Daisy seed gene 0.575). → floor lowered to **0.1 m** (Daisy r_bottom 0.315).
2. **Runner/smoke reference-tension path** built `build_system_from_v10`
   without `base_params` → default `params_v5_50kw()` → phantom 81.36 kg
   (m_blade = 12.076 kg, the 50 kW contamination the handover said was fixed).
   The evaluator itself passed `base_params=p` correctly; only the scripts'
   T_exp reference chain was contaminated. → `base_params=p_base` added.
3. **Lifter mass in tension sizing** — `sized_lifter_for` used
   `expansion_airborne_mass` including the flat 5.0 kg lifter. Rod: the lifter
   provides its own lift; its mass must not drive the required lift-line
   tension. → `expansion_airborne_mass(; include_lifter=false)`; tension sizes
   on the machine only. (The runner PROVENANCE note claimed the opposite of
   the code — now true.)
4. **Annulus area audit** — ODE (main_rotor_swept_area), settle scan and the
   per-rotor window Betz all use the correct π(r_out²−r_in²). Fixed:
   - the false identity comment `A = 2π·r_ring·L` (only valid for a 50/50
     split; understates the Daisy annulus by 12%);
   - the **Betz ceiling** used base-theory hub radius + blade-tip OFFSETS —
     now the same annulus areas the ODE sweeps;
   - the **expansion per-rotor Betz** used full disk — now the annulus.
5. **Anchor** — new `params_daisy()` (src/parameters.jl): measured Tulloch
   config-8 values (ring 1.52 m, tips 1.22/2.22 m, blade 420 g, TRPT 10.31 m,
   6 lines, 3 blades, tether 2 mm, k = 0.175 @ 624 W/146 rpm, Cp_sys 0.16).
   All rung scaling now goes through `mass_scale(params_daisy(), 1.5, KW)` —
   never the 10 kW DRR theory or the 50 kW BOM (Rod 2026-08-21).

## k_mppt sweep (in flight)

Script: `scripts/sweep_k_mppt_5kw.jl` — runner path (cold start, mass-min,
L=18.8 m), k ∈ [0.5 … 9.0] bracketing:
- Daisy 6-blade anchor scaled: 0.175 × (5/1.5)^2.5 = **2.24**
- Daisy 3-blade anchor scaled: 0.42 × (5/1.5)^2.5 = **5.39**
- old theory: 1.94

Pick the k with sustained P_end ≥ 5 kW at productive TSR, sane FoS, no twist.
Output: `scripts/results/k_sweep_daisy_5kw.csv`.

## Open items

- **i_pto** placeholder 0.3 kg·m² in params_daisy (Daisy drivetrain inertia
  not measured — thesis dynamic-model tables are image-rendered; pull when
  needed).
- **n_blades = n_lines (Gate 1c) vs Daisy's measured 3 blades on 6 lines** —
  the builder forces one blade per line, doubling blade mass vs the anchor.
  Flag for a decision before quoting φ from this campaign.
- **φ anchor**: Daisy <2 kg at 1.5 kW (φ ≈ 1.3) vs P^1.35 mass scaling gives
  φ ≈ 2.1 at 5 kW — the mass exponent itself is underdetermined (field tests).
- Acceptance suite still red by design until re-baselined on the re-run winners.

## Verification sequence (this session)

1. Fast suite after fixes — expected green (1 test updated: StackedLifter
   const-tension now asserts lifter-excluded tension, Rod's ruling).
2. k sweep → choose k → set `cfg.k_mppt` in run_v13_5kw_masslift.jl.
3. Re-smoke (smoke_masslift_v13.jl, mass-min config, L=18.8) — seed must pass.
4. Only then: 1-length DE, then the full 5 kW re-run.
