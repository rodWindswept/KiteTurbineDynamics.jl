# PRD 0006 Gate 2 — Constrained Control Map Re-run (v5)

**Status:** SPEC (2026-07-06 — spokes replace clamp, neutral-loading target)
**Parent:** [PRD 0006 — Blade Geometry Audit & Recovery](0006-blade-geometry-audit.md)
**Supersedes:** Gate 1 (defects #2, #3) · v1 (Mach root-find) · v3 (clamp) · v4 (SWL unsourced)
**Gate:** Centrifugal loads ✅ · Spoke ties 🟡 (Commit 2 held pending SWL fix — this spec)

Spoke SWL: 44.0 kN MBL × 0.90 splice × 0.50 creep/fatigue/UV = **19.8 kN**.
PROVISIONAL — Rod to supply actual reel MBL or make/model.

---

## Constraint envelope

| Constraint | Status | Binding? | Source |
|-----------|--------|----------|--------|
| Ring compression FoS | ✅ Implemented | Binding where net radial load is inward (load-dependent) | `_evaluate_trpt_design_impl` |
| Spoke FoS (7mm Dyneema, SWL 19.8 kN) | ✅ Implemented | TBD after SWL-sourced regeneration | `SpokeParams`, evaluator |
| Spoke drag (ODE, ~12 kW at 260 rpm, ω³) | ✅ Implemented | ~5-8% of design | `compute_ring_forces!` |
| Strut tension FoS | ✅ Implemented (CFRP 600 MPa) | Non-binding (~120 at 260 rpm) | `src/structural_constants.jl` |
| Knuckle at spoke-termination load | ✅ Pass-through (FoS_knuckle ≥ FoS_tension by design, Rod) | Non-binding | Rod (2026-07-06) |
| Blade-root bending FoS | ✅ Implemented (lumped-mass cantilever) | Non-binding (~118 at 260 rpm) | `src/structural_constants.jl` |
| Mach 0.7 / 0.85 | Caveat column | Non-binding | Verify-stage flag |
| V10 Tight instability | **Retired** — dynamic instability at all low-k values (second independent ground) | `scripts/diagnose_tight_transient.jl` |
| Hardware ω ceiling | Wrap rate **APPLICABLE** — rigidised pipe-shrouded lift line passes through top swivel bearing (stationary member on rotation axis). Swivel rated RPM = hardware ceiling (TBD — Rod to supply make/model or rating). Generator sized via gearbox, not design ceiling. Model limits bind: spoke FoS, stability, drag economics. |

**Rated FoS** (when envelope is complete): min over compression, spoke, strut tension,
knuckle, blade-root. Pending members marked absent from current envelope.

**Spoke engagement** replaces the old "clamp" concept. The clamp was a model
validity boundary (FoS reads ∞ when F_v < 0); spokes are a real structural
member with measured FoS, drag, and a design target.

---

## Reference spoke tensions (SWL 19.8 kN — generic 7mm SK78, provisional pending Rod's reel spec)

Regenerated 2026-07-06 from `scripts/verify_ring_radii.jl` output. SWL = 44.0 kN MBL
× 0.90 splice × 0.50 creep/fatigue/UV. Hunt gate at FoS 1.0, caveat flag at <1.5.

| Design | Wind | k | ω (rpm) | T_spoke (kN) | FoS (SWL 19.8) | Flag |
|--------|------|---|---------|-------------|-----------------|------|
| λ=0.69 | 15 | 3.0 | 337 | ~10 | ~2.0 | — |
| Tight λ=1.0 | 15 | 12.9 | 322 | ~10 | ~2.0 | — |
| Reinforced | 15 | 12.9 | 213 | ~3 | ~6+ | — |
| Tight @11 | 11 | 6.23 | 332 | ~12 | ~1.6 | <1.5 caveat |
| Tight @13 | 13 | 6.23 | 376 | ~14 | ~1.4 | <1.5 caveat |

With SWL 19.8 kN, the spoke FoS-1.0 crossing moves well above 376 rpm for all
three designs. Spoke drag (~12 kW at 260 rpm, ω³ scaling) is the tighter constraint
at high ω. The hunt constraint (gate at FoS 1.0) is non-binding; the caveat flag
(<1.5) fires at ~300-350 rpm depending on design.

---

## Hunt procedure

### Step 1 — Compute per-design spoke engagement curves

For each builder, sample T_spoke(v, k) via the evaluator across the wind band.
Output: `spoke_engagement_{design}.csv` with columns (v_wind, k, ω, T_spoke, spoke_fos).
Spoke engagement is load-dependent — no fixed-rpm threshold.

### Step 1b — ω_neutral(v) bisection

Per design, bisect on net radial load = 0 across the wind band. Output:
`omega_neutral_{design}.csv`. Overlay chart: ω_neutral(v) against the controller
operating line ω(v) from k_mppt. The gap between the MPPT line and the neutral
line is the power-vs-fatigue trade, quantified per design.

### Step 2 — Constrained peak-hunt per row (builder × wind)

Reuse Gate 1 machinery (`ControlMapHunt.hunt_control_map`) with:
- `max_power=true`
- Spokes enabled (`SpokeParams(enabled=true)`)
- Adaptive convergence: sliding 20s windows, cap 240s, windowed-mean P
- Record ω(t), FoS(t), spoke FoS(t), spoke drag power

### Step 3 — Verify at the chosen k

- Sliding-window convergence ✓
- Stability gate (variance bound) ✓
- Spoke FoS per ring, spoke drag power loss
- tip_mach_ss and tip_mach_max (caveat)

### Step 4 — CSV output

Columns: all Gate 1 plus `n_spokes_engaged`, `max_spoke_tension_N`,
`min_spoke_fos`, `spoke_drag_kW`, `standing_radial_load_N` (signed),
`sign_flip_gust_ms`, `tip_mach_ss`, `tip_mach_max`, `n_sims_hunt`,
`T_converged_s`, `stability_flag`.

Caveat flags:
- `min_spoke_fos < 1.5`: spoke FoS below design margin (hunt gates at 1.0;
  SWL already embeds deratings; gating at 1.5-on-SWL would double-margin)
- `sign_flip_gust_ms` within Rod's site turbulence band (band TBD; until
  supplied, flag if within ±2 m/s of row wind speed)
- `tip_mach_ss > 0.7`: drag divergence, power optimistic
- `stability_flag = fail`: P variance high
- `T_converged_s = 240`: hit time cap

---

## Generator spec output

| Parameter | Source |
|-----------|--------|
| Rated speed | ω at constrained optimum |
| Rated torque | Q_gen from verify stage |
| Rated power | P_kw at constrained optimum |
| Rated FoS | min over implemented checks |
| Standing spoke load | standing_radial_load_N at operating point |

---

## Pre-requisites

- [x] Rod: reel MBL or make/model (SWL currently 19.8 kN PROVISIONAL)
- [x] Rod: wrap-rate applicability confirmed — swivel rated RPM TBD
- [ ] Rod: swivel rated RPM value (make/model or measurement)
- [ ] Rod: FoS gate decision — gate hunt at 1.0 with 1.5 caveat (recommended),
      or gate at 1.5 and drop caveat
- [ ] Reference tables regenerated by script post-SWL-fix, provenance stamped
- [ ] Spoke ties Commit 2 landed with SWL fix + table regeneration
- [ ] Outward-load check commits (strut tension, knuckle, blade-root) — pending
- [ ] Static equilibrium parity (spoke drag in objective_v10) — deferred,
      objective_v10 errors if spoke enabled per parity guard
- [ ] Tripwire: assert Mach at ω=260rpm ∈ [0.30, 0.60]
- [x] V10 Tight t=57-59s transient investigated — **retired on two independent grounds**
- [ ] Gate at 4-5% windowed-P range (stable 1.2%, marginal 6.7%, unstable 11.8-20.4%)

---

## What replaces Gate 1

| Gate 1 | Gate 2 (v5) |
|--------|-------------|
| Unconstrained max-power | Constrained max-power (spoke FoS ≥ 1.0 gate, <1.5 flag) |
| 5s pre-sweep k-selection | Gate 1 machinery + adaptive converge |
| T_VERIFY = 60s fixed | Sliding-window, cap 240s |
| Last-slice P snapshot | Windowed-mean P |
| No ω(t), FoS(t) | Full ω(t), FoS(t), spoke FoS(t) |
| No spoke tracking | Spoke engagement, FoS, drag, sign-flip margin |
| No generator spec | Rated speed/torque/power/spoke load |
