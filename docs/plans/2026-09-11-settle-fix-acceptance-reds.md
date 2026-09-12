# Findings — the three acceptance reds after the 2026-09-11 settle fix

**Date:** 2026-09-11. **Scope:** diagnosis only; nothing under `src/` or `test/`
was modified. Scratch scripts are `scratch/diag_reds_*.jl`.

The 2026-09-11 change replaced the settle's "preload restore then twist"
initialisation with `_matched_place_twist` + `design_axial_preload`
(`src/initialization.jl:885`, `:938`, called at `:1118`/`:1126`), only on the
`lift_device !== nothing` path. Acceptance went 8/8 → 5/8. This note establishes,
for each red, what is asserted, what is now observed, and whether the assertion
is stale or the corrected state is harmful.

**Bottom line:** all three are downstream of the same fact — the settle now
returns the *true* twisted operating state (preload tension ≈ 265–289 N/line and
Δα up to 52–75°/segment on the loaded segments) instead of a ~7× under-twisted
one that wound up inside the measurement window.

- `test_gate_v13` A5 is a **stale trigger**: the rope-break latch is
  strain-based, physical, and still fires; only the test's chosen tether
  diameter no longer builds a line that breaks.
- `test_settle_lowk_honest` A3's *reported* symptom (`status=:reject`,
  `P_end=0.0`) is a **stale test config**: a mis-built genome (legacy 14-D index
  clamps applied to a 10-D genome) trips the twist-collapse detector, and that
  reject path **zeroes** P_mean/P_end/FoS. `P_end = 0.0` is a sentinel, not a
  stall — the machine makes 4.7–5.4 kW. But correcting the genome does **not**
  make A3 green: the documented seed then rejects on the same **real FoS
  shortfall** as P1.
- `test_physics_path_ode` P1 is a **real FoS regression**: power (`P_end =
  5.139 kW`) and twist (`crossed=false`) are healthy, but the windowed FoS reads
  **2.314**, below the 2.5 hard floor. The pre-fix 2.78 was inflated by the
  under-twisted start.

---

## 1. `test_gate_v13.jl` — A5 (rope-break latch)

### Assertion

```julia
# test/test_gate_v13.jl:88-92
check("A5: the broken machine's power/ω/clearance alone would pass the gate",
      rb.P_gen_final >= MIN_P_GEN_KW && rb.w_gnd_final > MIN_W_GND &&
      rb.clearance >= MIN_CLEARANCE)
check("A5: the rope-break latch is set", rb.line_broken)
check("A5: the gate rejects the broken-line machine", !rb.ok)
```

Reported failures: only lines 91–92 (`latch is set`, `gate rejects`). The first
check **passes**.

### Config

- `test/test_gate_v13.jl:82` — `p_thin = override_params(params_daisy(); tether_diameter=0.00025)`
- `:83` — `rb = gate_design(seed_genome(KW); L=L18, KW=KW, p2=p_thin)` — the raw
  canonical 10-D seed (`seed_genome(5.0)`; `bank_bottom = 0`, `blade_scale_bottom = 0.7`).
- Gate (`scripts/ode_gate_v13.jl`): settle `n_op=30_000` (`:137`), 10 s relax in
  two 5 s chunks (`:151-153`), then a 30 s window in 6 × 5 s chunks (`:157-168`),
  `stable_dt_for_system` (`:133`), `lift_for` const-tension lifter (`:36-37`).
- `mass_scale(...,1.5,5.0)` multiplies the diameter by `sqrt(5/1.5)`, so the
  override 0.00025 builds **d = 0.000456 m**, `EA_single = 1.636e4 N`.
- Latch threshold and definition: `src/rope_forces.jl:31`
  `const ROPE_BREAK_STRAIN = 0.035`, applied at `src/rope_forces.jl:370-377` to
  the **line-level** `(seg_pathlen − seg_restlen)/seg_restlen`, latching
  `sys.any_broken[]`; the gate's `ok` includes `!sys.any_broken[]` at
  `scripts/ode_gate_v13.jl:175-176`.

### Observed

Exact test run (command E1): `ok=true line_broken=false P_gen_final=6.35 kW
ω_gnd=14.15 clearance=2.89 m`. Diagnostic repeat (E4):
`thin 0.00025 ok=true line_broken=false P_gen_final=6.347 kW w_gnd=14.151
clearance=2.89 crossed=false max_ratio=0.864`.

The recorded pre-change baseline is in the test's own comment
(`test/test_gate_v13.jl:79-81`): *"Tuning (probe 2026-09-10, seed genome):
p2.tether_diameter 0.0005 → healthy (ok=true, P_gen 6.19 kW); 0.00025 → line
breaks, gate rejects."*

Strain arithmetic on the corrected settle (T_s = F_ax[1]/n_lines ≈ 283 N,
measured settled line tensions **288.7 … 269.8 N**, i.e. the intended preload):

| tether | scaled d (m) | EA_single (N) | design strain at 283 N | break strain |
|---|---|---|---|---|
| 0.00025 (test trigger) | 0.000456 | 1.636e4 | **1.73 %** | 3.5 % |
| 0.00020 | 0.000365 | 1.047e4 | **2.70 %** | 3.5 % |
| 0.00018 | 0.000329 | 8.48e3 | **3.34 %** | 3.5 % |
| campaign 0.00200 | 0.003651 | 1.047e6 | 0.027 % | 3.5 % |

Measured gate outcomes for the candidate triggers (E4, raw seed, same gate):

```
thin 0.00018  ok=false line_broken=true  P_gen_final= 9.077 kW w_gnd=15.943 clearance=2.89
thin 0.00020  ok=false line_broken=true  P_gen_final=10.318 kW w_gnd=16.638 clearance=2.89
```

Both would satisfy all three A5 checks (the first check only reads power/ω/
clearance).

### Verdict

**Stale pin** — specifically a stale *trigger*, not a broken latch and not a
regression of the gate.

- The latch is a **material strain limit** (`ROPE_BREAK_STRAIN = 0.035`, Dyneema
  SK99 ultimate strain, `src/rope_forces.jl:27-31`). It is defined on strain, not
  on tension, so it is *unchanged* by the preload dropping from 1947 N to 283 N.
  On the healthy line the new preload strain is 2.7e-4 — a 130× margin.
- The assertion was passing against the pre-fix dynamics, not against a
  threshold calibrated to 1947 N. The test's own tuning note records 0.00025
  breaking on 2026-09-10, when the settle was ~7× under-twisted and the whole
  first ~100 s was a wind-up transient. With the corrected settle there is no
  wind-up (the plan's direct measurement: Δα 277.4° → 299.7° over 60 s then
  flat), the thin line's design strain is only 1.73 %, and it never trips
  (measured: `line_broken=false` over the full 40 s gate run).
- The latch still fires when a line is genuinely over-strained — at 0.00020 and
  0.00018 the gate returns `line_broken=true` and `ok=false`.

### Recommended action

**Re-baseline the trigger** in `test/test_gate_v13.jl:82` from `0.00025` to
`0.00020` (verified `line_broken=true`, `ok=false`, and the power/ω/clearance
pre-check passes: 10.32 kW, 16.64 rad/s, 2.89 m). Caveat worth recording in the
test: at 0.00020 the line breaks during the settle, so the trace is frozen and
`crossed=true`; the pre-check reads the frozen post-break state. A more robust
fixture would lower `e_modulus` (or raise the design tension) so the line
survives the settle and breaks inside the window; the diameter knob sits in a
very narrow band (0.00025 survives, 0.00020 breaks at settle). This is a
**test-only** change — `src/` is correct.

---

## 2. `test_settle_lowk_honest.jl` — A3 (honest k sustains)

### Assertion

```julia
# test/test_settle_lowk_honest.jl:112-115
r = run_at(K_MPPT_5KW_HONEST)      # K_MPPT_5KW_HONEST = 2.24 (scripts/compute_seeds.jl:34)
@test r.status === :ok
@test r.P_end > 5.0
@test r.FoS_min > 2.5
```

Reported: `:113` (`reject === ok`) and `:114` (`0.0 > 5.0`) fail; `:115`
(`FoS_min > 2.5`) passes — because `FoS_min = Inf` on the reject path (see below).

### Config

- `run_at` (`:60-80`): `ObjectiveConfig(power_W=5000, v_rated=11, p_floor_kw=5,
  p_ceiling_kw=5, relax_s=5.0, window_s=20.0, fos_target=2.5, fos_hard=2.5,
  power_stat=:tail5, kickstart_s=0.0, k_mppt=2.24,
  tether_diameter=P_BASE.tether_diameter=0.003651, rotor_count_mode=true,
  power_split=0.6, blocking_factor=BLOCKING_WIND_FACTOR_5KW)`.
- Called `start_mode=:cold`, `lift_device=lift_for` (margin 1.5, v_ref 11,
  const_tension), `fitness_fn=appropriate_mass_fitness`.
- Genome `X_SEED` from `seed_genome_x()` (`:49-58`) — this is the defect, see below.
- No numeric baseline is recorded in the test any more: the previous
  `@test r.P_mean ≈ 6.25 atol = 0.15` was deleted in the 2026-09-10 re-baseline
  (`git diff test/test_settle_lowk_honest.jl`). The last green run is recorded in
  `handovers/handover-2026-09-10-r7-complete.md:93-99` ("Acceptance suite: 8/8
  green … `test_settle_lowk_honest.jl` A3 (honest k = 2.24…)").

### Observed

Exact result fields (E5) — this is the **twist-collapse reject path**, not a
stall:

```
A3  status=reject  fitness=Inf  P_mean=0.0000 kW  P_end=0.0000 kW  FoS_min=Inf
    T_lift=0.0 N  w_eq=14.3109  P_range=0.0000  drifted=true stationary=false
    twist_crossed=true  util_a=-1.000 util_b=-1.000
```

`objective_evaluator.jl:790-793` is the only path that returns
`(:reject, Inf, 0.0, Inf, …, twist_crossed=true)` — it **zeroes P_mean, P_end and
FoS on the first detected crossing**. So `P_end = 0.0` is a sentinel, not a
measured power, and `FoS_min = Inf > 2.5` is why line 115 passes.

The machine is not stalling. Settled state and window trace for `X_SEED`
(evaluator's own build recipe, `n_op = 150_000`, E6):

```
settle: w_gnd=14.3109 rad/s  k*w^3=6.565 kW
twist_collapse_check(settle): crossed=true max_ratio=1.156 worst_seg=4
seg  Δα(deg)  δα*_maxR(deg)  ratio   T_line(N)
 1    69.655        65.604   1.062     288.74
 2    71.172        65.333   1.089     286.03
 3    72.851        65.023   1.120     283.32
 4    74.745        64.660   1.156     280.61
 5    40.699        53.478   0.761     277.90
 6    18.805        55.656   0.338     275.19
 7    14.376        70.322   0.204     272.49
 8    13.243        70.355   0.188     269.78
window: t=1..20 s → P 4.7–5.4 kW, crossed=true (ratio 1.0–1.13) until t≈19 s
```

So the corrected settle places segments **1–4 past the detector's conservative
crossing limit** (`r = max(r_a,r_b)`, `objective_evaluator.jl:300-323`) and the
evaluator latches `twist_flagged` at the first post-relax sample → all telemetry
zeroed.

**Why this genome is over-twisted — a test defect.** `seed_genome_x()`
(`test/test_settle_lowk_honest.jl:49-58`) applies the **legacy 14-D** index clamps
`xr[8]` and `xr[10]` to the canonical **10-D** genome:

```julia
xr[8]  = Float64(round(Int, clamp(xr[8],  3, 16)))   # 10-D index 8 = bank_bottom       0.0 → 3.0
xr[10] = Float64(round(Int, clamp(xr[10], 1,  3)))   # 10-D index 10 = blade_scale_bottom 0.7 → 1.0
```

Measured (E7):

```
seed_genome(5.0) = [2.4, 0.5751, 2.0, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]
X_SEED (test)    = [2.4, 0.5751, 2.0, 6.0, 0.0, 3.0, 0.0, 3.0, 0.7, 1.0]
```

The fast guard `test/test_settle_preload_consistency.jl:49-51` clamps the
**correct** indices (`x[4]` = n_lines, `x[6]` = rotor_count). With the documented
seed the corrected settle gives (E8, tether 0.003):

```
collapse: crossed=false  max_ratio=0.922
seg Δα = 58.9, 59.7, 60.7, 61.7, 36.5, 17.1, 11.3, 9.1 (cumulative 315.1°)
T_line = 282.8 … 264.6 N
max_ratio over the whole window ≤ 0.904, crossed=false
```

i.e. **the documented seed does not cross**; only the mis-built `X_SEED` does.

### Verdict

**Stale pin, caused by a stale test config — but the file has a second, real
problem underneath.**

The reported `status=:reject` / `P_end=0.0` failure is not a power or physics
result at all: it is the twist detector latching on a genome that is not the
campaign seed, and the reject path zeroing the telemetry. `X_SEED` differs from
`seed_genome(5.0)` exactly at the two legacy-clamp indices (8 and 10), and it is
the mis-built genome that settles past the crossing limit (ratio 1.156 vs 0.922
for the documented seed). The corrected start state itself is *not* implicated:
for `X_SEED` it achieves the intended preload (288.7…269.8 N ≈ F_ax/n_lines, S1)
and the machine sustains 4.7–5.4 kW; for the documented seed it does not even
approach the crossing limit.

**However**, fixing the genome alone leaves A3 red. The A3 config (documented
seed, campaign tether 0.003651, relax 5, window 20) measures (E9):

```
A3-fixed  status=reject  fitness=Inf  P_mean=5.0744 kW  P_end=5.0442 kW
          FoS_min=1.3112  twist_crossed=false  util_a=0.624 util_b=0.138
```

So with the correct genome A3's first two assertions would pass
(`P_end 5.04 > 5`) but `@test r.FoS_min > 2.5` fails on a **real** measured FoS
of **1.311** — the same real shortfall as P1 (§3), only worse with the campaign
tether.

### Recommended action

1. **Fix the test config** — clamp the 10-D indices in
   `test/test_settle_lowk_honest.jl:53-54`:

   ```julia
   xr[4] = Float64(round(Int, clamp(xr[4], 3, 9)))    # n_lines
   xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))    # rotor_count_mode
   ```

   (as in `test/test_settle_preload_consistency.jl:49-51`). Do **not**
   re-baseline `P_end` or `status`: 0.0 is the collapse sentinel, and
   re-baselining it would pin the sentinel.
2. **Then treat the FoS assertion as the open defect** (shared with P1): the
   documented seed's 20 s window FoS is 1.311, far below the 2.5 hard floor.
   Do not relax `fos_hard` to make the file green; fix the design/sizing margin
   (§3).

---

## 3. `test_physics_path_ode.jl` — P1 (seed healthy under DEFAULT physics)

### Assertion

```julia
# test/test_physics_path_ode.jl:135-141
check("P1: seed is healthy under DEFAULT physics (status :ok, finite fitness)",
      !default_threw && default_result !== nothing &&
      default_result.status === :ok && isfinite(default_result.fitness))
```

### Config

- `const X = seed_genome(KW)` (`:84`) — the **documented** raw 10-D seed (no
  legacy clamp; this file does not have the `seed_genome_x` bug).
- `const P = params_at_length(L18)` (`:85`), campaign 5 kW base.
- `CFG` (`:67-82`): `power_W=5000, p_floor_kw=5, p_ceiling_kw=5, fos_target=2.5,
  fos_hard=2.5, power_stat=:tail5, k_mppt=K_MPPT_5KW_HONEST=2.24,
  rotor_count_mode=true, power_split=0.6, cone_slope_deg=22,
  rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW,
  relax_s=5.0, window_s=5.0`. Note: **`tether_diameter` is not set**, so the
  build uses the `ObjectiveConfig` default `0.003` (`objective_evaluator.jl:137`),
  not the campaign `0.003651` that A3 passes explicitly.
- `run_eval` (`:87-97`): `start_mode=:cold`, `lift_device=lift_for`,
  `fitness_fn=appropriate_mass_fitness`.
- Evaluator cold path: settle with **default `n_op=150_000`**
  (`objective_evaluator.jl:632-634`, `src/initialization.jl:1043`), then one
  continuous run of `total_n = (relax+window)/dt` at
  `dt = stable_dt_for_system` (E9).

### Observed

Exact test run (E2):

```
default status=reject  fitness=Inf  P_mean=5.139 kW  FoS_min=2.314
❌ P1: seed is healthy under DEFAULT physics (status :ok, finite fitness)
legacy  status=reject  fitness=Inf  P_mean=0.000 kW  FoS_min=Inf
✅ P2: LEGACY physics changes the ODE result
```

Exact result fields, same `evaluate_windowed` call (E9):

```
P1 exact  status=reject  fitness=Inf  P_mean=5.1390 kW  P_end=5.1390 kW
          FoS_min=2.3139  twist_crossed=false
          T_lift=453.2 N  w_eq=13.5303  P_range=0.2098
          drifted=false  stationary=true  util_a=0.431  util_b=0.001
```

So P1 is **FoS-driven, not power- or twist-driven**:

- Power is healthy: `P_mean = P_end = 5.139 kW` (above the 5 kW floor) — the
  `P_end` value is carried because this is the honest-reject path
  (`objective_evaluator.jl:915-926`), not the collapse sentinel.
- Twist is healthy: `twist_crossed = false`; the independent window probe on the
  same genome (E8) gives `max_ratio ≤ 0.904`, `crossed=false` for the whole
  window, `w_gnd ≈ 13.14–13.16`.
- `FoS_min = 2.3139 < cfg.fos_hard = 2.5`, and
  `appropriate_mass_fitness` returns `Inf` for `FoS_min < fos_hard`
  (`src/objective_v12.jl:149`). That alone forces `status = :reject`
  (`objective_evaluator.jl:915-916`). `util_a + util_b = 0.432 = 1/FoS_min`
  holds, so the value is self-consistent (axial-dominated, `util_b = 0.001`).

The tether-diameter mismatch matters here after all. Re-running the **same
documented seed** with the campaign tether (`0.003651`) instead of the default
(`0.003`), same relax/window (E9):

```
w5-camp   status=reject  P_mean=5.1380  P_end=5.1380  FoS_min=1.8332  crossed=false
A3-fixed  status=reject  P_mean=5.0744  P_end=5.0442  FoS_min=1.3112  crossed=false   (window 20)
```

`size_beams_closed_form` includes rope self-weight via
`DYNEEMA_DENSITY · π · (p_base.tether_diameter/2)²`
(`src/trpt_optimization.jl:443`), so the thicker campaign tether loads the rings
more and lowers FoS. P1's default-0.003 build is therefore the *more favourable*
of the two — with the campaign tether the seed's 5 s FoS is 1.83, not 2.31.

Recorded pre-change value: `docs/plans/2026-09-10-shaft-windup-workstream.md:9-10`
and `handovers/handover-2026-09-10-r7-complete.md` §6 record the seed as
`:ok` with **FoS 2.78** in the 5 s acceptance window (and `reject` with FoS 1.63
in the 40 s window) before the fix.

### Verdict

**Real regression** on the structural axis (not a stale numeric pin). The
corrected settle carries the true twist (Δα ≈ 58.9–61.7°/segment on segments 1–4
of the documented seed) and the true preload from t=0, so the ring
bending/helix/kink load is present in the 5 s window; the FoS reads **2.314**,
below the 2.5 hard floor. The pre-fix 2.78 was inflated by the under-twisted
start — the machine was still winding up, so the transmission was barely loaded
in torsion during the short window. Power is *not* the problem (`P_end = 5.139
kW`) and neither is twist (`crossed=false`).

This is the same underlying signal as §2's second issue: the seed is
FoS-infeasible once the start state is honest. A re-baseline to `:reject` would
pin the failure and delete a genuine safety signal, so it is not the right move.

### Recommended action

**Fix the code/config — do not re-baseline the assertion.**

1. The specific defect to chase is the seed's structural margin against the
   *corrected* window load. `size_beams_closed_form` sizes against a static load
   model with `SIZING_FOS_MARGIN = 1.3`; that margin was calibrated while the
   settle was under-twisted (`handovers/handover-2026-09-10-r7-complete.md` §2).
   The corrected window now shows FoS 2.31 (default tether) / 1.83 (campaign
   tether) at 5 s and 1.31 at 20 s, against the 2.5 floor.
2. Fix the config inconsistency in the test: `CFG` omits `tether_diameter`, so
   P1 builds a 0.003 m tether while the campaign and A3 use 0.003651 m. This is
   *not* FoS-neutral (measured above), so it should be aligned to
   `P.tether_diameter` before the number is used for any decision.
3. Before concluding the sizing margin is the defect, separate steady state from
   the still-imperfect settle transient (the plan's S4 first-frame residual is
   574 N vs a <50 N target). The 20 s A3 window (FoS 1.311) is below the 5 s
   window (FoS 1.833), so this is not merely a short-window phase artifact;
   but the FoS trace does oscillate (~2 s limit cycle, E8), so report a
   min-over-long-window figure rather than a single short window.

---

## Summary

| Test | Assertion (file:line) | Observed (current tree) | Pre-change | Verdict | Action |
|---|---|---|---|---|---|
| `test_gate_v13` A5 | latch set / gate rejects (`test/test_gate_v13.jl:91-92`) | `ok=true, line_broken=false, P=6.35 kW, w=14.15` (thin 0.00025) | comment `:79-81`: 0.00025 → line breaks, gate rejects (2026-09-10 probe) | **stale pin** (stale break trigger; latch threshold is physical) | re-baseline trigger `:82` 0.00025 → **0.00020** (verified `line_broken=true`, `ok=false`, P=10.32 kW) |
| `test_settle_lowk_honest` A3 | `status===:ok`, `P_end>5`, `FoS>2.5` (`:113-115`) | `reject, P_mean=0.0, P_end=0.0, FoS=Inf, twist_crossed=true`, w_eq=14.31 (collapse sentinel) | test file had `P_mean≈6.25` deleted; last green 2026-09-10 (handover) | reported symptom = **stale pin** (test-genome bug trips the twist detector; 0.0 is a sentinel). Corrected genome then: `P_end=5.044, FoS=1.311` → **real FoS regression** | fix `seed_genome_x` indices `:53-54` (`xr[4]`/`xr[6]`); then treat `FoS>2.5` as the open design defect |
| `test_physics_path_ode` P1 | `status===:ok` + finite fitness (`:135-141`) | `reject, fitness=Inf, P_mean=P_end=5.139 kW, FoS_min=2.314, twist_crossed=false` | FoS 2.78, `:ok` (windup workstream §1; R7 handover §6) | **real regression** (honest FoS 2.31 < 2.5 hard floor; 2.78 was the under-twist artifact) | fix code/config: seed structural margin / sizing margin; align `tether_diameter`; do not re-baseline to `:reject` |

Shared root fact: the settle now returns the true twisted state, which (a)
removes the wind-up that the A5 trigger was calibrated against, (b) makes the
test's mis-built `X_SEED` cross the conservative twist limit immediately (and the
collapse sentinel zero its telemetry), and (c) exposes the seed's windowed FoS at
1.31–2.31 — below the 2.5 hard gate in every window and tether measured.

## Evidence

### Files

- `src/initialization.jl:885` `design_axial_preload`, `:938` `_matched_place_twist`,
  `:1118` preload call, `:1126` matched solve; `:1043` settle `n_op` default 150_000.
- `src/rope_forces.jl:27-31` `ROPE_BREAK_STRAIN = 0.035`; `:370-377` line-level
  break detection / `any_broken` latch.
- `scripts/ode_gate_v13.jl:26-28` thresholds; `:133` stable dt; `:137` settle
  `n_op=30_000`; `:151-153` 10 s relax; `:157-168` 30 s window;
  `:175-176` `ok` includes `!sys.any_broken[]`.
- `src/objective_evaluator.jl:137` `tether_diameter` default 0.003; `:300-323`
  `twist_collapse_check`; `:632-634` cold settle (default `n_op`); `:686-704`
  twist flag sampling (only after `relax_s`); `:787` `P_end` = mean of last 5
  finite samples; `:790-793` **twist reject zeroes P_mean/P_end/FoS**; `:904`
  `P_score = P_end` for `:tail5`; `:915-926` honest reject carrying telemetry.
- `src/objective_v12.jl:149-150` hard gates: `FoS_min < fos_hard → Inf`,
  `P_score < p_floor_kw → Inf`.
- `src/trpt_optimization.jl:443` rope self-weight in the beam load model:
  `DYNEEMA_DENSITY · π · (p_base.tether_diameter/2)²` (why tether diameter moves FoS).
- `test/test_gate_v13.jl:79-83,88-92`.
- `test/test_settle_lowk_honest.jl:33-45,49-58,60-80,112-115`.
- `test/test_physics_path_ode.jl:67-97,120-141`.
- `test/test_settle_preload_consistency.jl:49-51` (correct 10-D clamps), `:70`
  settle `n_op=2_000`.
- `docs/plans/2026-09-11-settle-ode-coherence.md` §1, §2.1, §2.3, §4, §5.
- `docs/plans/2026-09-10-shaft-windup-workstream.md:9-10` (pre-fix FoS 1.63 / 2.78).
- `handovers/handover-2026-09-10-r7-complete.md` §2, §4, §6 (last green
  acceptance 8/8, 2026-09-10; seed reject FoS 1.63 in the 40 s window).

### Commands run

Let `J = JULIA_DEPOT_PATH="$PWD/.julia_depot:/home/rodbot/.julia" /snap/julia/165/bin/julia --project=. --startup-file=no`,
from the repo root.

- **E1** `PATH="$PWD/.julia_depot/bin:$PATH" $J test/test_gate_v13.jl`
  → FAILED: `A5: the rope-break latch is set, A5: the gate rejects the broken-line machine`
  (A1–A4 ✅; thin gate `ok=true line_broken=false P_gen_final=6.35 kW ω_gnd=14.15 clearance=2.89 m`).
- **E2** `PATH="$PWD/.julia_depot/bin:$PATH" $J test/test_physics_path_ode.jl`
  → `default status=reject fitness=Inf P_mean=5.139 kW FoS_min=2.314`;
  P1 ❌, P2 ✅.
- **E3** `PATH="$PWD/.julia_depot/bin:$PATH" $J test/test_settle_lowk_honest.jl`
  → `settle-lowk-honest: 11 pass, 2 fail`; A1/A2/A4 ✅; A3 fails at `:113`
  (`reject === ok`) and `:114` (`0.0 > 5.0`), `:115` passes.
- **E4** `$J scratch/diag_reds_a5.jl 0.00025`
  → `thin 0.00025 ok=true line_broken=false P_gen_final=6.347 kW w_gnd=14.151 clearance=2.89 crossed=false max_ratio=0.864`.
  `$J scratch/diag_reds_a5.jl 0.00018 0.0002`
  → `thin 0.00018 ok=false line_broken=true P=9.077`; `thin 0.0002 ok=false line_broken=true P=10.318`.
- **E5** `$J scratch/diag_reds_a3_p1.jl` (uses `X_SEED` for both, as
  `test_settle_lowk_honest` does)
  → `A3 status=reject fitness=Inf P_mean=0.0000 P_end=0.0000 FoS_min=Inf twist_crossed=true`.
- **E6** `$J scratch/diag_reds_window_probe.jl` (X_SEED settle + 1 s window trace)
  → settle table in §2; window `crossed=true` ratio 1.0–1.13, P 4.7–5.4 kW,
  ratio falls below 1 only at t≈19 s; FoS 0.86–2.33 throughout.
- **E7** one-liner printing `seed_genome(5.0)` vs the test's `seed_genome_x()`
  → differs at indices 8 and 10 only.
- **E8** `$J scratch/diag_reds_p1_raw.jl` (documented seed, tether 0.003, P1
  cold path) → settle `crossed=false max_ratio=0.922`; window `crossed=false`,
  `max_ratio ≤ 0.904`, `P ≈ 5.03–5.26 kW`, `w_gnd ≈ 13.14–13.16`; FoS trace
  1.75, 2.08, 2.50, 2.42, 2.62, 2.50, 2.69, 2.61, 2.60, 2.57 for t = 1…10 s.
- **E9** `$J scratch/diag_reds_p1_fields.jl` — exact `evaluate_windowed` fields:
  P1 exact (`status=reject, P_mean=P_end=5.1390, FoS_min=2.3139, twist_crossed=false,
  util_a=0.431, util_b=0.001`); documented seed + campaign tether, window 5
  (`P_end=5.1380, FoS_min=1.8332`); documented seed + campaign tether, window 20
  (`P_end=5.0442, FoS_min=1.3112`).

*(Note: E8's per-second trace is chunked 1 s runs; the authoritative P1 FoS
minimum is the E2/E9 value 2.314, sampled inside a single continuous run. E8's
pre-relax FoS minimum of 1.746 is excluded by the evaluator, which samples only
after `relax_s` — `src/objective_evaluator.jl:696`.)*
