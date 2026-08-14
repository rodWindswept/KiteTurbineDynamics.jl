# Evaluator v13 — the test that identifies realistic KTD designs

**Date:** 2026-08-13
**Status:** IMPLEMENTED — acceptance tests B1–B5 green, full suite 1901/1901 (2026-08-13)
**Scope:** `src/objective_evaluator.jl` (ObjectiveConfig, ObjectiveResult, evaluate_windowed),
`src/objective_v12.jl` (v12_fitness), new `scripts/run_v13_5kw.jl`, `test/test_evaluator_v13.jl`.
No physics-model change — this is instrumentation + scoring, applying the 2026-08-13 lessons.

## What the 2026-08-13 diagnosis established

The gate re-instrumentation (`ode_gate_v13.jl`, A1–A4 green) found the three 5 kW regimes:

| Design | Gate verdict | Failure mode |
|---|---|---|
| 18 m winner | ❌ P_gen 1.41 kW @30 s | flywheel decay (single rotor, 3 rings) |
| 25 m winner | ❌ P_gen 0.86 kW @30 s | flywheel decay |
| island-1 winner | ❌ twist 169× limit | torsional collapse (inverted taper) |
| original seed | ✅ 4.12 kW @30 s | — healthy transmission |

The campaign evaluator that produced those winners has three defects, confirmed by source
reading (2026-08-13):

1. **No twist collapse detector.** `evaluate_windowed` samples power and ring FoS only
   (`objective_evaluator.jl:404-437`). Per-segment twist vs the crossing limit is never
   checked — the collapsing design evaluates `:ok` with 6.3 kW mean power.
2. **Above-ceiling penalty punishes genuine delivery.** `v12_fitness`
   (`objective_v12.jl:38-39`) applies a quadratic penalty when P_mean exceeds the rung
   ceiling. At 5 kW the seed genuinely delivers ~7.5 kW mean over the window and is
   PENALISED for over-delivery, while a flywheel design decaying through the [2.5, 5.0] kW
   window scores clean. Over-delivery at rated wind is headroom, not a flaw — the Betz
   ceiling gate (`objective_evaluator.jl:515`) already hard-rejects physical cheating.
3. **P_mean over a 10 s hot-settle window samples flywheel energy.** The window mean
   includes the first seconds after the idealized settle (~19 rad/s). The tail of the
   window is the only part that measures sustained transmission, and it is never gated.

## Change

Three additions, all opt-in via `ObjectiveConfig` (defaults preserve v12 behaviour exactly):

1. **Twist collapse rejection (hard).** New helper `twist_collapse_check(u, sys)` reading
   the RAW free-integrated α states (`u[6N+1:6N+Nr]`, no wrap — `capture_extended`'s
   `segment_twist` wraps mod 2π and cannot see multi-revolution wind-up). Per segment:
   Δα_i vs δα*_i = 2·asin(L_seg/√(2(L_seg²+2r_seg²))), r = max(r_i, r_{i+1}) (conservative).
   Checked every sample in the window callback; any crossing → reject.
2. **P_end power quantity.** `ObjectiveConfig.power_stat = :tail5` makes the fitness
   receive the mean of the LAST 5 samples of the window (sustained power), instead of the
   full-window mean. Default `:mean` = v12 behaviour.
3. **Ceiling penalty opt-out.** `ObjectiveConfig.penalize_ceiling = false` disables the
   above-ceiling quadratic in `v12_fitness` (floor penalty, FoS terms, and the Betz hard
   gate unchanged).
4. **Ring-FoS soft target off at 5 kW.** The 5 kW v13 config sets `fos_target = 1.5`
   (equal to `fos_hard`): the below-target quadratic — which currently pushes the DE
   toward light/unloaded structures whose FoS reads high (exploit-register rows 2, 6, 7) —
   is neutralised. Torsional safety is carried by the twist detector (change 1); the hard
   floor still rejects ring FoS < 1.5. Requires a divide-by-zero guard in `v12_fitness`
   when `fos_target ≈ fos_hard` (skip the below-target term; the hard gate covers it).
5. **Kickstart off in v13 (`kickstart_s = 0.0`).** The cold path's 2 s PTO motor kick
   (`k = −60`, ~115× the MPPT gain, ~21.7 kN·m at ω≈19) is a legacy escape from the
   ζ=1.5 reverse-torque stall. With ζ=0.05 (DECISIONS [2026-08-12]) the settle reaches
   the productive branch directly and the kick is unnecessary — and the B2/B3 acceptance
   failures showed the kick itself winds a healthy seed's chain past δα* while pumping
   the flywheel design's window power. Default `2.0` preserves v12 bit-for-bit; v13
   sets 0.0.
6. **Rated MPPT gain (`k_mppt = p.k_mppt`).** The v12 campaign evaluator silently ran
   every 5 kW eval with `ObjectiveConfig`'s default `k_mppt = 10.0` — the 50 kW-scale
   controller gain, ~5× the scaled system's rated gain (p.k_mppt ≈ 1.94 at 5 kW). The
   B2 acceptance failure exposed it: at k=10 the flywheel design's window power inflated
   (P_end 4.18 vs the gate's 2.26 at the system's own gain). The evaluator must load the
   machine with the gain it would be built with — `cfg.k_mppt = p.k_mppt` in v13.

`ObjectiveResult` gains two telemetry fields: `P_end` and `twist_crossed` (the collapse
signature becomes visible per eval row in campaign CSVs).

The v13 evaluator is then exactly: `ObjectiveConfig(window_s=20.0, p_floor_kw=2.5,
p_ceiling_kw=5.0, power_stat=:tail5, penalize_ceiling=false, fos_target=1.5)` + the twist
rejection — no new fitness function, the version seam (`fitness_fn`) is untouched.

Campaign side (`scripts/run_v13_5kw.jl`): same cold-start DE loop as v3, but telemetry logs
the COMPLETE genome vector + real decoded values + P_end + twist_crossed per row
(exploit-register row 9). `with_timeout` kept.

## Acceptance tests (`test/test_evaluator_v13.jl`)

| # | Test | Expected |
|---|------|----------|
| B1 | island-1 winner through the v13 config (L=21.2, window 30 s — collapse takes ~50 s to kill ω_gnd but twist crosses far earlier) | `:reject`, twist_crossed=true (master: `:ok`) |
| B2 | 18 m winner through the v13 config (L=18.0, window 20 s) | `:reject` OR P_end < 2.5 kW — and fitness worse than the seed's (master: `:ok`, competitive) |
| B3 | original seed through the v13 config (L=21.2, window 20 s) | `:ok`, twist_crossed=false, P_end ≥ 2.5 kW, fitness strictly better than B2's winner (master: seed loses on the FoS-below-target + ceiling penalties) |
| B4 | unit: `v12_fitness` with `penalize_ceiling=false` (5 kW knobs, w_ceiling=2) | fitness(7.5 kW, FoS=3) < fitness(3.5 kW, FoS=3) — more delivered power is strictly better (master: cfg kwarg unknown → error) |
| B5 | unit: `twist_collapse_check` | post-settle state → not crossed; same state with α wound +π on one segment → crossed (master: function undefined) |

## Blast radius

- `ObjectiveResult` field additions ripple to every constructor site (rejected_eval,
  evaluate_windowed, ramp evaluator) — grepped and updated together.
- v12 behaviour preserved under defaults: existing 1902-test suite must stay green, and
  the v12 warmstart adapter must produce bit-identical fitness for identical configs.
- The dashboard reads SimFrame (unchanged); `capture_extended` untouched.
- Previous campaign CSVs are not re-derived; they are historical record (provenance note).

## DECISIONS entry (drafted, pending green tests)

> **2026-08-13 — Evaluator v13: tail-window power, twist-collapse rejection, no
> over-delivery penalty.** The campaign evaluator crowned designs that the corrected gate
> rejects: it sampled P_mean over a 10 s hot-settle window (flywheel energy), penalised
> power above the rung ceiling (punishing the genuinely-delivering seed), and never read
> the twist state (the collapse design scored `:ok` at 6.3 kW). v13 evaluates sustained
> power as the window tail (P_end), rejects any per-segment twist past the geometric
> crossing limit δα*, and treats above-ceiling power at rated wind as headroom (Betz hard
> gate remains). Defaults preserve v12 bit-for-bit.

## Verification

1. `julia --project=. test/test_evaluator_v13.jl` — RED on master, GREEN after.
2. `julia --project=. test/runtests.jl` — existing suite must stay green (1902 tests).
3. Re-evaluate the three 5 kW designs + seed through v13: seed must be the only `:ok`.
