# Workstream — TRPT shaft wind-up at steady rated operation

**Status:** diagnosed (Rod, 2026-09-10: investigate as its own workstream).
Date: 2026-09-10. Origin: the R7 re-baseline campaign blocked on it.

## 1. The finding

Evaluating the 5 kW seed at the honest operating point (k = 2.24, rated 11 m/s,
cold start, honest 40 s window), the windowed FEA FoS reads 1.63, below the 2.5
gate — even though a 5 s window reads 2.78. Traced with
`scratch/r7_window_fos.jl`: the shaft **winds up** over the window
(`twist_ratio` 0.52 → 0.81) while power and ω stay steady.

## 2. Diagnosis (steps 1–3 of the original plan, executed)

### 2.1 Torque budget (`scratch/r7_windup_budget.jl`, k = 2.24)

| t (s) | ω_gnd | ω_hub | Δα (deg) | twist_r | P_gen | ΣP_aero | τ_gen | τ_shaft(top) | τ_net |
|---|---|---|---|---|---|---|---|---|---|
| 5  | 13.14 | 13.31 | 194 | 0.520 | 5.03 | 6.92 | 382.6 | 518.0 | 137.0 |
| 25 | 13.19 | 13.22 | 273 | 0.747 | 5.09 | 6.77 | 385.6 | 602.5 | 126.5 |
| 50 | 13.12 | 13.23 | 291 | 0.809 | 5.01 | 6.67 | 381.6 | 523.5 | 122.3 |

`τ_gen = k·ω²` ≈ 385 N·m; the shaft transmits ≈ 520–608 N·m at the top; the
aero input (6.7–6.9 kW) exceeds the generator output (5.0–5.2 kW) by the
parasitic drag. A **persistent ≈ +120 N·m residual torque** acts on the
torsional DOF throughout the window.

### 2.2 k sensitivity — the residual is not a k-selection issue

Same seed at k ∈ {2.24, 3.0, 4.0, 5.39}: the residual stays +106…+142 N·m at
every k, and the twist **grows faster at higher k** (lower ω ⇒ more twist for
the same torque). At k = 4.0 and 5.39 the twist crosses the 1.0 collapse limit
within 50 s. The honest k = 2.24 is the mildest case, not the cause.

### 2.3 Does it saturate? — the twist does; the ring LOAD does not

300 s run (`scratch/r7_windup_long.jl`): Δα = 264° (t=20) → 287° (t=40) →
294° (t=60); the increments collapse (23° → 7° → …). The bulk twist saturates
at ≈ 0.82 of the crossing limit, so the machine is **not** torsional-collapse
unstable.

**But the ring load keeps oscillating.** A 150 s FoS trace
(`scratch/r7_windup_fos_long.jl`) shows the transmission-ring `N_comp` cycling
between ≈ 120 N and ≈ 200 N with a ≈ 10 s period, with `twist_ratio` flat at
≈ 0.83–0.84 — i.e. a **sustained limit cycle**, not a settling transient:

| t (s) | 10 | 30 | 40 | 50 | 60 | 80 | 90 | 100 | 110 | 120 | 130 | 140 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| FoS_min | 3.65 | 2.64 | 1.94 | 3.03 | 2.08 | 2.77 | 2.19 | **1.88** | 2.64 | 2.53 | 2.03 | 1.92 |
| N_ring2 (N) | 102 | 143 | 184 | 124 | 183 | 137 | 173 | **201** | 143 | 150 | 187 | 196 |
| twist_ratio | 0.62 | 0.77 | 0.80 | 0.81 | 0.82 | 0.83 | 0.83 | 0.835 | 0.836 | 0.837 | 0.838 | 0.838 |

So extending the relax does **not** restore FoS ≥ 2.5: the ≈ ±25–30 % load
cycle keeps the windowed trough at ≈ 1.9–2.1 indefinitely.

### 2.4 Numerical or physical? — the coarse dt was masking it

`scratch/r7_cycle_dt.jl` ran the same settled state for 60 s at `dt` and `dt/2`
(`stable_dt_for_system` = 2.04e-5):

| | N_ring2 mean | min | max | range |
|---|---|---|---|---|
| dt   | 140.1 | 83.9 | 209.3 | 125.4 |
| dt/2 | 178.0 | 84.9 | 328.5 | **243.6** |

Halving `dt` roughly **doubles** the cycle amplitude. A genuine numerical
instability would shrink as `dt` moves further inside the stability limit; here
the coarse step is *damping* a mode that the finer step resolves. Combined with
the cycle's ~10 s period (far below any rope-sub-segment frequency), this points
to an **under-damped physical load mode**, not an integration artefact.

### 2.5 Damping reduces it but does not clear the gate

`scratch/r7_cycle_damp.jl`, 60 s at `dt` for three bearing-damper factors
(`lin_damp`; nominal 0.05):

| `lin_damp` | N_ring2 mean | range | FoS_min | FoS range |
|---|---|---|---|---|
| 0.05 | 140.1 | 125.4 | 1.70 | 1.70–4.04 |
| 0.30 | 146.2 | 94.2 | 1.78 | 1.78–3.57 |
| 0.60 | 159.6 | 58.2 | 1.97 | 1.97–3.02 |

Damping clearly shrinks the cycle (range 125 → 58) and raises the trough
(FoS 1.70 → 1.97), so the mode is physical and only lightly damped in the
current model. But even at `lin_damp = 0.60` (12× nominal, not physical) the
trough stays below the 2.5 gate.

### 2.7 Damping audit (Rod's concern, 2026-09-10)

Rod asked whether the old "damping applied every step, so finer dt = more
damping" mistake has been reintroduced, and whether any damping lacks a physical
basis. Audit of every damping term on the live path:

| Term | Where | dt-scaled? | Physical? |
|---|---|---|---|
| Rope/line damper `lin_damp` | `orbital_damp_rope_velocities!` (init.:620-624) | **Yes** — `retain = exp(-rate·dt)`, `rate = -ln(lin_damp)/4e-5` | **No — artificial** |
| Rope sub-segment spring-damper `c_damp` | `rope_forces.jl:123,58`, inside the ODE force | Yes (ODE force, not a per-step rescale) | Yes (viscous line damping) |
| Settle velocity kill | `settle_to_equilibrium` (init.:485-487) | Yes (`exp(-rate·dt_use)`) | No (settle-only) |
| Bearing transverse `bearing_tr_damp` | legacy `simulate` only (init.:705-706) | Yes | Semi-artificial (legacy) |
| Angular `ang_damp` | legacy `simulate` only (init.:696) | **No** (`u .*= ang_damp` per step) | No — but default 1.0 (off), all callers pass 1.0 |

**Answer to the dt-scaling mistake:** it is **not** on the live campaign path.
`run_canonical_sim!` applies only the rope damper, and that is dt-scaled. The one
un-scaled line (`ang_damp`) is in the legacy `simulate`, is off by default, and
no caller enables it.

**The real problem is the rope damper's magnitude and basis.** `lin_damp = 0.05`
means "keep 5 % of the rope nodes' oscillating velocity every 4e-5 s" — a decay
time constant of ≈ 13 µs. It is a numerical stabiliser with no physical basis,
and it dominates the structural loads:

| `lin_damp` | dt | N_ring2 range (N) |
|---|---|---|
| 0.00 | dt | **95 – 606 (range 511)** |
| 0.00 | dt/2 | 126 – 553 (range 427) |
| 0.05 | dt | 90 – 217 (range 127) |
| 0.05 | dt/2 | 85 – 296 (range 212) |

Removing the artificial damper makes the ring load swing **~6×** (95 → 606 N).
So the ~10 s load cycle is a genuine feature of the model, and the artificial
damper is masking most of it — it is not a benign stabiliser. This is the real
concern to resolve before any campaign: the structural loads, and therefore every
FoS number and beam size, currently depend strongly on an unjustified damper.

Also note the parameter is named/documented as a "bearing damper" in
`evaluate_windowed`, but it damps the **rope/line** nodes — stale naming.

**Drag characteristics.** The formulas are the standard
`½·ρ·Cd·d·L·|v⊥|·v⊥`: line `TETHER_DRAG_CD = 1.0`, ring tube
`TUBE_DRAG_CD = 1.2`, blade profile `EXP_CD0_DESIGN = 0.010` rising to
`EXP_CD_STALL = 0.15` post-stall. Each ring-to-ring line is split into **4
sub-segments (3 moving nodes)**. The constants are the documented ones, but they
have **not** been checked against measured data, and the coarse line resolution
(vs the ~13 µs damper) is exactly the kind of thing that changes the load cycle.

### 2.9 The mode is shaft lateral wobble, not twist

`scratch/r7_mode_id.jl` samples `N_comp(ring 2)` against candidate state
variables over 30 s (artificial damper at 0.05) and correlates:

| variable | corr with N_ring2 | range |
|---|---|---|
| hub-ring lateral offset (ring 9) | **+0.65** | 0.058 – **0.485 m** |
| ring 6 lateral offset | +0.63 | 0.016 – 0.148 m |
| kite↔bearing distance | +0.61 | 29.2 – 29.7 m |
| ring 2 lateral offset | +0.61 | 0.0007 – 0.028 m |
| twist_ratio | +0.51 | 0.23 – 0.77 |
| ω_gnd | +0.43 | 12.0 – 13.2 rad/s |
| ω_hub | −0.28 | 13.2 – 13.4 rad/s |
| bearing radius | −0.53 | 24.2 – 24.7 m |

The load tracks the **shaft's lateral wobble** — the hub ring centre translates
up to **0.49 m sideways** — not the torsion. This is deliberate: the orbital
damper's own docstring says rings are left free to wobble because lateral ring
oscillation is "the suspected mechanism behind real-world TRPT collapses". So
the oscillation is an intended, physical feature of the model, and the static
closed-form strut sizing simply cannot cover the load at the wobble extremes.

### 2.10 Physical damping does not decay the wobble

`scratch/r7_phys_damp.jl`, 120 s, artificial damper off vs on:

| `lin_damp` | first-half N range | second-half N range | overall |
|---|---|---|---|
| 0.00 | 473 | 402 | 117 – 591 |
| 0.05 | 103 | 71 | 98 – 202 |

With only the model's physical damping (line ζ = 0.05 plus aerodynamic drag),
the wobble does **not** decay over 120 s. The artificial damper tames it to a
bounded ±50 N oscillation but does not remove it. So the model has no credible
damping for this mode: the artificial damper is the only thing holding it, and
it is not physical.

### 2.11 Line-resolution sweep — finer grid resolves MORE, not less

The rope discretisation is now parameterised (`ROPE_SUBSEGS` in `src/types.jl`,
default 4; Rod 2026-09-10). `scratch/r7_rope_res.jl`, 10 s from the same settle
(artificial damper 0.05):

| `ROPE_SUBSEGS` | n_total | dt | N_ring2 range | ring-9 lateral max | FoS_min |
|---|---|---|---|---|---|
| 4 (current) | 155 | 2.04e-5 | 43 | 0.246 m | 1.83 |
| 5 | 203 | 1.83e-5 | 54 | 0.223 m | 1.55 |
| 8 | 347 | 1.44e-5 | **256** | 0.195 m | **0.25** |

Refining the grid **increases** the resolved load swing and lowers the FoS. So
the oscillation is **not** coarse-grid jerkiness — the coarse grid's numerical
dissipation was *suppressing* a real oscillation. This is the same message as
the `dt`-refinement (§2.4), now confirmed on the spatial axis too. It also means
the current N=4 results under-state the loads.

Rod's suggestion was that more segments would make the motion less jerky; the
opposite turned out to be true here, and that is diagnostic: the missing piece is
not resolution but **physical line damping/drag**. Higher realistic line drag
would damp the wobble; the model's flat `Cd = 1.0` is the candidate to revisit
with the Dunker / Tevide / Labat data.

### 2.13 Lift-line audit (Rod's question, 2026-09-10)

Rod asked whether the lift-line tension really compensates the system mass, is
constantly applied, acts on the lift bearing, and points at a fixed/steady kite
point. Verified in source:

| Question | Answer | Where |
|---|---|---|
| Compensates system mass? | Yes — `T_ref = 1.5·m_airborne·g / sin(70°)`; vertical component = 1.5× weight (`m_airborne` excludes the lifter's own mass) | `lift_kite.jl:214-216` |
| Constantly applied? | Yes in wind speed (`const_tension=true` → flat `T_ref`), **but tension-only**: applied only while the lift line is taut (`line_dist ≥ 0.99·L`) | `lift_kite.jl:240`, `ring_forces.jl:494-505` |
| On the lift bearing? | Applied to the **sky-anchor** node, reaching the machine via sky anchor → cyan line → bearing → bridles → hub | `ring_forces.jl:504` |
| Fixed/steady kite point? | Direction is steady (local downwind + 70° elevation), but the point is **lagged** (τ = 3 s) and tracks the moving sky anchor | `simulation.jl:30-61` |

**Kite-lag test (round 6).** Set `KITE_TAU_S` to ~0 (instant following, so the
lift direction no longer responds to sky-anchor motion) and re-ran the wobble
probe: N_ring2 range 42 vs 43, hub lateral 0.249 vs 0.246 m, FoS 1.86 vs 1.83 —
**unchanged**. So the lift-line lag is *not* driving the shaft wobble; the
wobble is intrinsic to the tension structure. (Reverted immediately; fast suite
green.)

### 2.15 Can line drag damp the wobble? No — and that reframes the blocker

Rod's plan was to fetch line-drag data (Dunker / Tevide / Labat) to give the
model physical line damping. That is worth doing for the drag *power* and the
drag model, but it **cannot** damp the wobble. The arithmetic:

| quantity | value |
|---|---|
| line Reynolds number, rated wind (d = 2 mm, ν = 1.5e-5) | **≈ 1500** |
| line Reynolds number at the wobble velocity (0.16 m/s) | ≈ 20 |
| wobble mode: amplitude 0.25 m, period ≈ 10 s | ω ≈ 0.63 rad/s, v_peak ≈ 0.16 m/s |
| aerodynamic drag force at the wobble peak, all 6 lines, `Cd = 1` | **0.003 N** |
| linearised drag damping coefficient | ≈ 0.043 N/(m/s) |
| critical damping for the mode (m ≈ 30 kg) | ≈ 38 N/(m/s) |
| **drag damping ratio ζ** | **≈ 0.001 (0.1 %)** |

Drag is quadratic, so at a 0.1 Hz mode its velocity — and therefore its damping —
is negligible. This is physics, not a modelling gap: a lightly-damped tension
structure oscillating slowly is not damped by air. It also means the tether's
low Reynolds number (~1500) makes the current flat `Cd = 1.0` reasonable, so the
drag data will refine the drag model but **not** unblock the campaign.

**Consequence.** The campaign is blocked on a **wobble-policy decision**, not on
drag data: either (a) add a structural damping mechanism the model does not have,
(b) size the struts for the wobble envelope (a dynamic amplification factor), or
(c) gate on the wobble amplitude as a design failure. (a) is a model addition;
(b)/(c) need Rod's call because they set the mass/risk trade-off.

### 2.16 Root cause (ii) — the settle assumes RIGID ring positions

> **SUPERSEDED 2026-09-11.** The measurements below are correct, but the
> *mechanism* is wrong. The gap is not frame softness — it is the **axial
> preload**, and the ring motion that matters is axial (the shaft shortens),
> not lateral. Measured: the settle intends 283…265 N per line but achieves
> 1947…601 N, because the preload restore sets the axial gap for the
> *untwisted* line and the twist bisection then adds `Δα`, whose own
> `2r²(1−cos Δα)` chord growth is six times the intended preload strain —
> making the segment ~7× too stiff. Torque profiles are identical between the
> settle and the run; only tension differs (6.5×). See
> `docs/plans/2026-09-11-settle-ode-coherence.md` §1 for the corrected diagnosis
> and the closed-form fix. The "1.266 m vs 1.171 m chord" below is a real
> consequence, but of the axial inconsistency, not of lateral ring freedom.

`scratch/r7_settle_twist.jl`, immediately after
`settle_to_operational_state`:

```
settle   cumulative Δα = 42.5°   max per-seg ratio = 0.099
         per-seg twist (deg) = 6.6, 6.6, 6.6, 6.6, 5.6, 4.2, 3.4, 2.9
```

The running equilibrium is ≈ 294–300° cumulative, i.e. the first segment runs at
**48.8°** vs the settle's **6.6°** — a 7× gap — so the first ~100 s of every run
is a wind-up transient and the honest window sits inside it.

**The solve itself is not wrong.** `scratch/r7_torque_curve.jl` evaluates the
settle's `τ_fn_a` and the ODE's own `compute_rope_forces!` rope torque on ring 1
over a twist sweep: they agree to machine precision (identical curves). At the
settle's 6.6° the rope torque is **377.6 N·m = τ_gen** — a genuine equilibrium.

**What differs is the geometry, not the torque law.** At the *running* state
(`scratch/r7_balance.jl`) the ring-1 rope torque is **384 N·m = τ_gen** at
**48.8°** — also a genuine equilibrium. So the two states are both balanced, but
the running shaft is **~270× torsionally softer**: the settle's rigid design
geometry would need a **1.266 m** chord at 48.8° (stretching the line 0.093 m →
~25 kN), while the running shaft keeps the chord at **1.171 m** by *moving the
rings* (lateral/axial deformation) so the line never stretches.

The settle pins ring positions to the design preload
(`src/initialization.jl:1083-1087`) and only then solves the twist; the ODE lets
the rings deform. **`preload_ring_pos` is purely axis-aligned**
(`initialization.jl:994-1008`): it places every ring on the shaft axis with a
purely AXIAL stretch `F_ax/k_axial` — no lateral deflection, no twist coupling.
The running shaft deflects laterally and re-orients, which is what softens the
torsion. So the settle's twist is correct *for a straight, laterally rigid frame*
that does not exist in the run.

**Naive check ruled out (round 5).** Disabling the position pin entirely leaves
the twist at a steady 74.2° with no wind-up — but with an unphysical
distribution (0.4° on the loaded transmission rings, 35–37° on the lightly
loaded top), the signature of the rings **drifting numerically** (`dt²·(F/m)`
accumulation, exactly what the pin exists to prevent), not deforming in force
balance. So simply unpinning is not the fix; a real coupled equilibrium is.

The bisection's π/4 cap is **not** the issue (raising it to the segment's δα*
gives identical output), and `rope_helix_pos` is plain linear interpolation, so
node-placement is not the issue either.

**Implication for the fix.** "Match the settle to the ODE" means solving the
**coupled position + twist** static equilibrium, not just changing the twist
target: iterate ring-centre deflection (from the full static force balance) with
the per-segment twist solve, using the ODE's own force/torque kernel, until both
are consistent. A one-shot twist change cannot close a 7× gap caused by frame
flexibility.

## 3. What this means

- The bulk twist is stable, but the transmission-ring **load carries a sustained
  ≈ 10 s, ±25 % limit cycle** that the static closed-form sizing cannot cover.
- The settle gap (42.5° vs 294°) makes the first ~100 s worse still, so the
  honest 40 s window catches both the wind-up and the cycle trough.
- No beam-sizing *margin* fixes it cheaply: raising `SIZING_FOS_MARGIN` 1.3 → 2.0
  moved the dip only to 2.40 (the load grows with the tube).
- The 2026-09-04 winner passed because its heavier free-gene tubes carried the
  cyclic trough; the R7 load-derived tubes are lighter and do not.

## 4. Fix options (for Rod)

0. **Re-examine the artificial rope damper FIRST** (§2.7). It has no physical
   basis, it dominates the structural loads (removing it swings `N_comp` 95 →
   606 N), and every FoS and beam size currently depends on it. If the campaign
   is to mean anything, the line damping must be either given a physical basis
   (measured Dyneema hysteresis + aerodynamic line damping) or removed and the
   resulting oscillation designed for. Nothing else below is worth doing until
   this is settled.
1. **Decide how the model should treat the shaft wobble.** It is now named
   (§2.9): a lateral ring-centre oscillation (hub swings up to 0.49 m) driven by
   the tension structure, deliberately undamped per the orbital-damper
   docstring, and currently held only by an artificial damper (§2.10). Options:
   (a) add a physically-justified lateral damping mechanism (aerodynamic drag on
   rings/lines at low frequency is present but far too weak); (b) keep it and
   size the struts for the wobble envelope (a dynamic amplification factor); or
   (c) decide the wobble amplitude itself is a design failure and gate on it
   (e.g. a maximum ring lateral offset) instead of hiding it in FoS.
2. **Extend the cold-start relax** (`ObjectiveConfig.relax_s`) from 10 s to
   ≈ 120 s so the window starts after the wind-up. Config-only, ~2× per-eval
   cost, but **insufficient alone** while the wobble persists (§2.3).
3. **Fix the settle to match the ODE** (Rod's directive, 2026-09-10; no per-eval
   cost in principle). §2.16 shows this is **not** a twist-target tweak: the
   settle's torque law already matches the ODE exactly. The gap is that the
   settle assumes a **rigid frame** while the running shaft deforms. The fix is
   a **coupled static equilibrium**: iterate the ring-centre positions and the
   per-segment twist together (relax positions → solve twist → repeat) until
   both are consistent, using the ODE's own force/torque kernel. Removes the
   wind-up; does not remove the wobble. **Designed and baselined in
   `docs/plans/2026-09-11-settle-ode-coherence.md`** (first-frame residual today:
   3.05 kN / 87 N·m; `n_op` 30 k and 150 k are bit-identical, so the pin — not
   settle duration — is the cause).
4. **Line-resolution check.** 4 sub-segments per line is coarse; raise it and see
   whether the wobble amplitude/period converges. Cheap to test.
5. **Then** a dynamic amplification factor on the sizing load, so the static
   solve covers the wobble envelope.

Recommendation: (0) remove/justify the artificial damper, (1) decide the wobble
policy, then (3) + (5). Extending the relax (2) alone is not enough.

## 5. Acceptance for the workstream

A 5 kW seed held for 60 s at its design k with `twist_ratio` bounded (no
monotonic climb) and the windowed FEA FoS ≥ 2.5. Only then re-launch the R7
re-baseline campaign (`--tag r7rebase`).

## 6. Evidence files

`scratch/r7_windup_budget.jl` (torque budget + k sweep), `r7_windup_long.jl`
(300 s saturation), `r7_window_fos.jl` (window FoS trace),
`r7_settle_twist.jl` (settle vs equilibrium twist).
