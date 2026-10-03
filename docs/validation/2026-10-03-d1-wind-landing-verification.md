# D1 site-wind landing — independent verification (2026-10-03)

**Validator:** @software-validator (Hermes profile `software-validator`)
**Verdict up front:** the landing is real and correctly described in shape; the *reason*
the L/r = 2.0 fixture went red is **not** a wind re-anchor at the fixture's operating
point. It is a **sizing-chain re-baseline that lands as a −38 % line preload**. Detail below.

## 1 · Revisions gated

| item | value |
|---|---|
| main tree HEAD | `4d1b6c9` (branch `bank-derate-cos2p65`), WIP modified in `src/objective_evaluator*.jl` (+ 10 tracked files), untouched by this verification |
| branch under test | `d1-site-wind-landing` @ `6f4cdbe` — **not** an ancestor of `master` or `bank-derate-cos2p65` |
| commit shape | 7 files, **+185 / −29** (`KiteTurbineDynamics.jl`, `objective_evaluator.jl`, `objective_evaluator_ramp.jl`, `objective_v10.jl`, `parameters.jl`, `wind_profile.jl`, `test_bem_unified.jl`) — matches the claim |
| control arm | `4d1b6c9` (parent of `6f4cdbe`) |
| test worktree | `~/Documents/GitHub/ktd-d1-sv-check` (detached; created and removed by this pass) |
| env | `JULIA_DEPOT_PATH=<main-repo>/.julia_depot:$HOME/.julia`, `scripts/ktd-julia` |

Working tree left as found — no staging, no commit.

## 2 · Suite verdicts (measured)

| gate | revision | claim | measured |
|---|---|---|---|
| fast suite totals | `6f4cdbe` | 2412 pass / 13 fail / 1 error | **2412 / 13 / 1 / 2426, 2m45.1s** ✓ exact |
| red sites | `6f4cdbe` | all in `test_trpt_realisability.jl` | **all 14 sites (13 fail + 1 error) in that file**; every other testset has an empty Fail column ✓ |
| fixture file alone | `6f4cdbe` | — | 5 pass / 13 fail / 1 error |
| fixture file alone | `4d1b6c9` | green | **32 / 32 pass, exit 0** ✓ |

`test/test_trpt_realisability.jl` is wired into the **fast** suite (`test/runtests.jl:56`),
so "land D1, then sweep" leaves a permanently red fast suite behind the sweep.

## 3 · What actually moved in the fixture — measured, both arms

Probe: `scratch/sv_probe_wind_anchor.jl` (built `params_5kw_188()` → `build_case(SEED_LR20)`
→ `design_axial_preload(…; realisability_margin=1.0)` → `trpt_matched_place(…;
raise_on_unrealisable=false)`, i.e. the fixture's own call sequence).

| quantity | pre-D1 `4d1b6c9` | post-D1 `6f4cdbe` | ratio |
|---|---|---|---|
| **decoder / sizing wind at the 5 kW hub** | **8.7066 m/s** | **11.0097 m/s** | **×1.2645 (+26.5 %)** |
| **ODE-side hub wind (the fixture's own `wf` closure)** | **11.0000** | **11.0097** | **+0.088 %** |
| fixture `wf` at 5.155 / 9.412 / 15 m | 10.0936 / 11.0000 / 11.7574 | identical | 1.0000 |
| `params_daisy().v_wind_ref` | 11.0 | 10.1025 | −8.2 % (this is where the re-anchor really lands) |
| `params_5kw_188().h_ref` | 9.41170 | 9.41170 | 1.0000 |
| `τ_eq = k_mppt·Ω_seed²` | 377.59767 N·m | 377.59767 N·m | **1.0000** |
| **`F_ax[end]` (line preload)** | **1116.10 N** | **688.85 N** | **0.6172 (−38.3 %)** |
| `F_ax` segments 1–8 (N) | 1533.37 … 1116.10 | 938.57 … 688.85 | 0.6076 … 0.6172 — **uniform** |
| ring-weight increment (F1−F2) | 5.41 N | 4.67 N | 0.8632 |
| **max demand** (`sin Δα`) | **0.88123** | **1.44592** | **1.6408** |
| demand[4] (binding) | 0.88123 | 1.44592 | 1.6408 |
| twist at binding segment | 61.79° | **90.00° (saturated)** | — |
| `τ_carry[1..6]` | 377.60 | 377.60 | 1.0000 |
| `τ_carry[7]` | 326.10 | 349.61 | 1.0721 |
| `τ_carry[8]` | 238.93 | 301.52 | 1.2620 |
| demand[8] | 0.17843 | 0.36480 | 2.044 |

### The chain the numbers give

The D1 slice retired `wind_speed_at_ring(ring_z, hub_altitude, v_ref, h_ref=50.0, shear_exp=0.14)`
and replaced the decoder's call with `wind_at_altitude(v_rated, p.h_ref, ring_altitude)`
(`src/objective_v10.jl:346`). `v_rated` defaults moved 11.0 → `p.v_wind_ref` (≈ unchanged
at 11.0097), but the **reference height moved 50 m → `p.h_ref` = 9.4117 m**. So the
*decoder's* wind went 8.7066 → 11.0097 m/s (×1.2645; ×2.022 on v³ — the "2.02×" figure).

That is a **sizing** change, not an operating-point change. The fixture's own wind function
is a hand-rolled closure in `test/settle_case_builders.jl:70`:

```julia
wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
```

— it already read **11.0 m/s at `p.h_ref`, α = 1/7, in both arms**. So the ODE side never
saw the 8.7. Sized for 11.0 instead of 8.7, the machine comes out smaller and lighter
(ring/axial increment −14 %), the lifter's tension target falls with it, and the whole
preload profile drops **uniformly ~38 %**. The fixture pins the operating **torque**
(`τ_eq`, identical to the last digit), so a lower tension on the same torque is a higher
twist demand: **0.88123 → 1.44592, ratio 1.641**, against a tension ratio of 0.6172⁻¹ =
1.620 — the residual is the expansion-rotor torque re-split (`τ_carry[7]` +7 %, `[8]` +26 %).

So the correct one-line diagnosis: **D1 did not give the fixture a stronger wind; it gave
it a smaller machine.** The direction is physically sound (a machine sized for 11 m/s is
smaller than one sized for 8.7) — but the fixture re-baseline therefore re-pins the whole
design point, not one wind number.

### Exponent vs anchor (confirms the room's reading)

At the fixed 50 m anchor, α = 0.14 → 8.7066 vs α = 1/7 → 8.6652 m/s, **+0.48 % on v**.
The anchor (50 m → 9.4117 m) carries the whole 26.5 %. Anchor defect, not exponent defect.

## 4 · Consequence for the axial-length work

- The fixture red **is** a physics-consequence-of-a-physics-correction, and Rod's
  re-baseline call is the right one — but the fixture should be re-baselined against the
  **−38 % preload / re-sized machine**, not against a wind change at 9.4 m. Two of its
  assertions move in *opposite* senses (`F_ax[end]` down, `τ_carry[7..8]` up), so a naive
  "re-pin to the new wind" pass will mis-state it.
- The −38 % sits in the **sizing chain** (`design_from_vector_v10` → `size_beams_closed_form`
  → `sized_lifter_for`), which any L-variant sweep runs through. "Wind-front-wise the L
  sweep is unblocked" is therefore true only as *the tree no longer double-sheets one
  machine*; the sweep's **baseline convention is still open** until this fixture is ruled
  on, or every L variant inherits the re-baselined tension and the cliff.

## 5 · Hardening note (not part of the verdict)

`params_5kw_188` is defined **four times** in `test/` — `settle_case_builders.jl` (canonical,
pins `EA_back_line = 707_000.0` post-`mass_scale`) and three copies in
`test_mass_model_2026_09.jl`, `test_settle_blocking_2026_09.jl`,
`test_beam_sizing_closed_form.jl` that **omit the EA pin** and therefore carry the
1.826-scaled back-line stiffness. The fixture consumes the canonical one, so the reds above
are not affected — but the three copies are a live drift trap, and the canonical file's own
header names exactly this failure mode.

## Evidence

- `~/.hermes/profiles/software-validator/cache/scratch/sv-logs/fast_suite_d1_full.log` — full fast suite on `6f4cdbe`, totals `2412 / 13 / 1 / 2426`, 2m45.1s
- `~/.hermes/profiles/software-validator/cache/scratch/sv-logs/trpt_realisability_d1.log` — fixture alone on `6f4cdbe`
- `~/.hermes/profiles/software-validator/cache/scratch/sv-logs/trpt_realisability_prefix_4d1b6c9.log` — fixture alone on `4d1b6c9`, 32/32
- `~/.hermes/profiles/software-validator/cache/scratch/sv-logs/derive.py` — the arithmetic in §3, re-runnable
- probe: `~/.hermes/profiles/software-validator/cache/scratch/sv-logs/sv_probe_wind_anchor.jl`
  — include it from a worktree of the revision under test and run with `scripts/ktd-julia`
  (it `include`s `scripts/compute_seeds.jl` and `test/settle_case_builders.jl` relative to that worktree)
