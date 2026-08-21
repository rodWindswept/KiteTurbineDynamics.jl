# Handover — 2026-08-20 (model-scaling audit + Daisy anchor + 5 kW re-run prep)

**From:** AI agent (KTD.jl repo)
**To:** next agent session
**Repo:** /home/rodbot/Documents/GitHub/KiteTurbineDynamics.jl (HEAD 4e26d29; worktree has uncommitted changes — see §Files)

## What this session accomplished

1. **Environment workaround.** Julia here is a snap whose wrapper fails
   (snap-confine); `~/.julia` is read-only and `/tmp` is ephemeral per
   command. The working setup: run Julia via
   `/snap/julia/current/bin/julia` with
   `JULIA_DEPOT_PATH=$PWD/.julia_depot:~/.julia`, and prepend
   `$PWD/.julia_depot/bin` to `PATH` (it holds a `julia` shim) so the
   acceptance runner's bare-`julia` subprocesses resolve. `.julia_depot/` and
   `.pylibs/` are gitignored.

2. **Grounded-economics investigation → found the 50 kW blade-mass
   contamination.** `build_system_from_v10` hard-coded `params_v5_50kw()`, so
   every 5 kW genome carried 12.0757 kg/blade (95% of mass, φ ≈ 18 kg/kW).
   Full analysis in `docs/reports/grounded-economics-v13.md`.

3. **Five physics fixes implemented + verified** (fast suite 1912/1912 green
   through all of them; DECISIONS.md [2026-08-20]):
   a. `base_params` kwarg on `build_system_from_v10` (rung-scaling; 50 kW
      default = legacy bit-identical).
   b. λ² blade-mass scaling (`m_blade = base_params.m_blade · λ_eff²`).
   c. λ reserved for TSR only — genome genes x13/x14 renamed
      `blade_scale_top`/`blade_scale_bottom` (decoder, runners, chooser,
      glossary, CONTEXT.md; backward-compat reads of historical CSVs).
   d. Main-rotor radius λ-blind bug fixed (was `5.0·le` → now the decoded
      hub-rotor tip).
   e. **Ring-anchored 70/30 annulus** for ALL rotors (decoder
      `blade_tip=+0.7·span`/`blade_hub=−0.3·span`, ODE swept area
      `π(r_out²−r_in²)` via `main_rotor_swept_area`, new
      `RotorSpec.blade_hub_radius`, and the `rotor_annulus_ok` gate =
      `r_ring ≥ 0.3·span`).

4. **Objective: hard-constraint mass minimisation.** Evaluator seam now
   `fitness_fn(P, FoS, cfg, mass)` with `mass = expansion_airborne_mass(sys,
   pc)`; `v11/v12_fitness` gained 4-arg overloads (backward compatible); new
   `mass_min_fitness` (Inf below FoS or power floor, else mass). Unit test in
   `test/test_objective_v12.jl`.

5. **Daisy anchor extracted and saved for posterity** —
   `docs/validation/tulloch-prototype-configurations.md`: Tulloch PhD
   Table 3.1 (9 configs, 120 h, May 2017–May 2020), geometry, masses, power
   records. Key: ring 1.52 m, tips 1.22/2.22 m (70/30), annulus **10.8 m² ≈
   measured 11.2 m²**, solidity 7.5%, NACA 4412, blade 420 g + 2 carbon rods
   (9 mm/0.5 mm) + 3D fuselage, **<2 kg at >1.5 kW (3-blade) → φ ≈
   1.3 kg/kW**, lengths 6.7–10.3 m (config 8 = 10.3 m), Cp_sys 0.15–0.18.

6. **NZTC carbon LCA extracted** (`Carbon Impact Model_v2.xlsx`): 50 kW
   scaled (NOT an anchor), 0.78 gCO₂e/kWh @ CF 0.528, IdeMat factors — note
   **carbon epoxy 88.9 kgCO₂e/kg vs Economics module's 24** (3.7× under-count;
   replace before quoting).

7. **Field-test proposal** — `docs/reports/field-test-proposal-draft.md`:
   Test A (mast re-run), B (5 kW), B2 (flown lift-kite), C (wind tunnel),
   Aiginish envelope (26 m AGL, <2 kg), Airborne Wind Europe certification
   route, lift-system R&D line (`CoaxialAutogyroStacking.jl`).

8. **5 kW re-run config assembled** — `docs/plans/2026-08-20-daisy-anchored-
   5kw-rerun.md`: Daisy-anchored seed (`compute_seeds.jl` now scales UP from
   Daisy, not down from 50 kW), runner `run_v13_5kw_masslift.jl` reconfigured
   (mass_min_fitness, FoS 2.5, power floor 5 kW, L=18.8 m).

## THE OPEN TASK — do this first

**The Daisy seed STALLS.** The smoke (`evaluate_windowed` on the Daisy seed,
mass_min config) returns `:reject`, 0 kW — rejected on the power floor. The
seed does not self-start / sustain rotation. **Do NOT launch the campaign.**
Primary suspect: `params_at_length` still theory-scales `k_mppt` and `i_pto`
from `params_10kw`; the Daisy operating point (146 rpm → ω ≈ 15.3 rad/s;
τ = P/ω ≈ 41 N·m → k ≈ 0.17 N·m·s²) is not anchored. Fix: add a Daisy-anchored
base params (tether 2 mm, k_mppt ≈ 0.17, i_pto from the Daisy drivetrain),
then re-smoke. Secondary: `kickstart_s=0` + ζ=0.05 cold-start; BEM-theory
rotor radius vs measured Cp_sys 0.16. See the plan doc §Validation/§Open.

## Other open items (priority order)

1. **Daisy seed stall** (above).
2. **Acceptance suite re-baseline** — currently expected RED: rope-break R3
   (seed ω band 12.19 vs 12.5–13.5), settle-drag A + D, evaluator B-tests —
   all calibrated on the old physics. Re-baseline on the re-run's winners.
3. **2026 full-scope LCOE/LCA workbook** — 10 kW L3 case structure, 2026
   re-pricing (CPI floor ≈ +23% since 2021), IdeMat carbon factors; replace
   `src/economics.jl` carbon factors (carbon epoxy 24 → 88.9, etc.).
4. **Mass exponent** — underdetermined (φ ≈ 1.3 kg/kW anchor; field tests).
5. The "corrected economics" and field-test proposal are DRAFT — no external
   quotes of any 5 kW number (the prior winners are VOID: 0 kW under the
   corrected physics).
6. **Working tree is NOT commit-ready** (acceptance red by design).

## Anchor facts (do not re-derive)

- Daisy (measured): ring 1.52 m, tips 1.22/2.22 m, annulus 10.8≈11.2 m²,
  solidity 7.5%, NACA 4412, blade 420 g + 2 carbon rods + 3D fuselage,
  <2 kg at >1.5 kW (3-blade), φ ≈ 1.3 kg/kW, lengths 6.7–10.3 m, Cp_sys
  0.15–0.18. Full record: `docs/validation/tulloch-prototype-configurations.md`.
- FoS floor = 2.5 at all points (Rod), until field trials/breakages.
- 50 kW BOM and 50 kW campaign numbers are NOT anchors (extrapolation).
- The 5 kW winners (7.68/8.24/8.32 kW) are superseded/void.

## Suggested skills

`ktd-simulation-workflow` · `diagnosing-bugs` (seed stall) · `tdd` (acceptance
re-baseline) · `windswept-knowledge` · `awe-knowledge`

## Files changed this session (uncommitted; `git status` / `git diff` for detail)

- **src/**: types.jl, initialization.jl, objective_v10.jl, objective_v11.jl,
  objective_v12.jl, objective_evaluator.jl, ring_forces.jl, sim_frame.jl,
  KiteTurbineDynamics.jl
- **scripts/**: compute_seeds.jl, run_v13_5kw_masslift.jl, run_v13_5kw.jl,
  run_v12_5kw.jl, run_v12_5kw_v3.jl, run_v10_campaign.jl,
  view_campaign_genomes.jl, recampaign_anchors.jl, ode_gate_v13.jl,
  report/grounded_economics_v13.jl (+ export/plot/diag rename touches)
- **test/**: test_blade_geometry.jl, test_builders_v10.jl, test_objective_v12.jl,
  test_physics_path_guard.jl, test_evaluator_v13.jl
- **docs/**: reports/grounded-economics-v13.md, reports/field-test-proposal-draft.md,
  plans/2026-08-20-daisy-anchored-5kw-rerun.md,
  validation/tulloch-prototype-configurations.md, agents/genome-glossary.md
- **root**: DECISIONS.md (three [2026-08-20] entries), CONTEXT.md, .gitignore

## Verification before anything new

```bash
cd ~/Documents/GitHub/KiteTurbineDynamics.jl && git pull --rebase   # multi-writer; laptop authoritative
export JULIA_DEPOT_PATH=$PWD/.julia_depot:~/.julia
export PATH=$PWD/.julia_depot/bin:$PATH
julia --project=. test/runtests.jl              # fast: expect 1912/1912
# acceptance: expected RED (old-physics expectations) until re-baselined
```
