# Handover — 2026-08-27: 5 kW re-seed + blocking + clearance (pre-campaign fixes)

**From:** agent session (continuation of the 08-26 recovery)
**To:** next session (and Rod, for the launch decision)
**State:** all pre-campaign fixes landed and validated. Fast suite **1991/1991
green**. Re-seeded genome smokes green (clearance 2.89 m, P 5.12 kW, FoS 10.6,
tension exact). **Campaign NOT yet re-launched** — see §3.

---

## 1. What landed (see DECISIONS [2026-08-27])

1. **Wake blocking, real + correct direction.** Wind flows up the shaft, so the
   UPPER (hub + middle) rotors are downstream and de-rated to 0.75× freestream
   power; the LOWEST rotor sees freestream.  Non-cumulative (each downstream
   rotor blocked once — Rod: "hub should only be blocked once").  Implemented as
   a per-rotor `wind_factor = 0.75^(1/3)` threaded from the decode into the ODE
   (`ring_forces.jl`), so it is a real P∝v³ de-rate in the slow solver, not a
   sizing placeholder.  The old code de-rated the wrong (lower) rotors and only
   the sizing.
2. **Clearance authority, geometrically correct.** New `lowest_rotor_clearance`
   (src) uses the ABSOLUTE tip radius and accounts for shaft elevation
   (`tip·cos(elev)`) and blade bank angle (`tip·sin(bank)` down-shaft).  Four
   duplicated offset-only copies replaced.
3. **Re-seed — r_hub 2.4 (was 2.775).** 3 rotors, blade_scale 0.7.  Measured on
   the fixed evaluator: clearance 2.89 m, P 5.12 kW, FoS 10.6, fitness 53.7 kg.
   The Daisy-scaled 2.775 m seed under-produced (4.37 kW) under blocking.
4. **Re-gate decode alignment.** `ode_gate_v13.jl` + `smoke_masslift_v13.jl`
   now decode with the campaign knobs (`rotor_count_mode`, `cylinder_cone`,
   `power_split=0.6`, `blocking_factor`), not the legacy bitmask/full-cone path.

Tests: `test/test_wind_blocking.jl` (new, wired into `runtests.jl`).  Suite
1991/1991.

## 2. Current seed (committed in `scripts/compute_seeds.jl`)

- 3 rotors, r_hub **2.4 m**, r_bottom 0.575 m, target_Lr 2.0, n_lines 6,
  blade_scale 0.7, Do_top 0.06.
- Single source constants: `K_MPPT_5KW_HONEST = 2.24`,
  `BLOCKING_WIND_FACTOR_5KW = 0.75^(1/3)`.
- Smoke (`scripts/smoke_masslift_v13.jl`): `status=ok P_mean=5.12 kW FoS=10.63
  T exact m_airborne=48.69 kg` → PASS.

## 3. Next steps (in order)

1. **Launch the re-campaign.** `v13_5kw_masslift_len18.8_rotorcount` results
   dir already exists (VOID).  Re-launch with a FRESH dir (the runner writes
   into the same `_rotorcount` path — move/archive the VOID dir first, or the
   new telemetry will mix with void rows).  Parallel mode:
   ```bash
   julia --project=. --threads=auto scripts/run_v13_5kw_masslift.jl --island 1 &
   julia --project=. --threads=auto scripts/run_v13_5kw_masslift.jl --island 2 &
   julia --project=. --threads=auto scripts/run_v13_5kw_masslift.jl --island 3 &
   ```
   then `julia --project=. scripts/combine_islands_v13.jl`.
2. **Re-gate winners** with `ode_gate_v13.jl` (now decode-aligned) +
   `analyze_campaign_winners.jl`; screen for the FoS=Inf signature.
3. **Acceptance re-baseline** on the winners (`docs/plans/2026-08-22-acceptance-rebaseline.md`).

## 4. Open items / for Rod

- **power_split=0.6** (top rotor gets 60%) now conflicts with the top rotor
  being the most-blocked.  Rod's 08-27 note addressed blocking cumulativity
  (single, confirmed), not power_split.  Consider re-sweeping power_split before
  or alongside the campaign — left at 0.6 for now.
- **Clearance formula** now uses elevation·cos + bank; Rod confirmed "must be
  geometrically correct".  The conservative `−tip` (no cos) form is retired.
- Ledger OPEN items (torque-cap law D4, lin_damp D1, etc.) are unchanged and
  still outstanding (see 08-26 recovery handover §1.6).

## 5. Repo hygiene

- Do NOT commit `scripts/results/preview_genome.png` or
  `scripts/results/v13_5kw_masslift_len18.8_rotorcount/*` (VOID telemetry) or
  `.claude/worktrees/*`.
