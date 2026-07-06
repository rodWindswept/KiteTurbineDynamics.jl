# PRD 0006 Gate 2 — Constrained Control Map Re-run (v3)

**Status:** SPEC (revised 2026-07-06 — Mach constraint non-binding, clamp binds first)
**Parent:** [PRD 0006 — Blade Geometry Audit & Recovery](0006-blade-geometry-audit.md)
**Supersedes:** Gate 1 (defects #2 and #3) · Gate 2 v1 (Mach root-find — retracted)
**Gate:** Centrifugal loads ✅ committed `e5b4886` · FR4 + full suite ✅ PASS

---

## Revised findings (2026-07-06 ring radius correction)

Expansion rotor ring radii are **2.2-3.0m** (RingNode.radius, verified via
`scripts/verify_ring_radii.jl`). r_tip = 4.6-5.8m across builders. Gate 1
peaked at Mach 0.54 — well subsonic. The handover's Mach 1.2-1.7 claim was
computed from wrong radii (~12m, confusing ring position with polygon radius)
and is **retracted**.

| Constraint | Threshold | Binding? | Source |
|-----------|-----------|----------|--------|
| Centrifugal clamp | ~191 rpm | **Yes** — model validity boundary | Beam+knuckle F_centripetal exceeds aero F_in |
| Mach 0.7 (drag divergence) | ~440 rpm | No — above clamp | Subsonic BEM polars become optimistic |
| Mach 0.85 (transonic) | ~500 rpm | No — far above clamp | Tip speed = a·0.85 |
| V10 Tight instability | t=57-59s transient | TBD | Low-k / high-ω, k=6.23 @ 11 m/s |
| Hardware ω ceiling | Rod's call | TBD | Generator rpm, tether wrap rate |

**Key fact:** the k-refinement power peaks (260-376 rpm) sit above the 191 rpm
clamp onset. The power-optimal regime is the unverified regime.

---

## Two options for Gate 2

### Option A: Clamp-free regime only (fast, verified physics)

- Hunt max P subject to ω ≤ 191 rpm (clamp count = 0 on all rings)
- Gate 1 + adaptive convergence + windowed-mean P + stability gate
- Every result stands on verified ring-compression physics
- Will report boundary-constrained optima — potentially well below true peaks
- ~2-4h runtime

### Option B: Full regime after outward-load check (slower, real optima)

- Build strut tension/bending + knuckle attachment check (existing ticket)
- Gate 2 can then explore the full ω range and find real optima
- Answers the question Rod actually cares about
- Requires src/ changes, test suite, commit → then Gate 2 runs

**Decision: Rod's call.** Option A is the default if no preference is stated.

---

## Hunt procedure (applies to either option)

### Step 1 — Compute per-design ω_ceiling

For each builder, compute ω at which clamp first fires on any ring with
expansion blade mass (not just beam+knuckle). This is tighter than the
191 rpm baseline since blade mass adds to F_centripetal. For Option A,
this becomes the hunt boundary. For Option B, it becomes a diagnostic flag.

### Step 2 — Constrained peak-hunt per row (builder × wind)

Reuse Gate 1 machinery (`ControlMapHunt.hunt_control_map`) with:
- `max_power=true` (unchanged)
- Adaptive convergence: sliding 20s windows, |mean(P_last20) − mean(P_prev20)| < 1%
  relative for two consecutive windows, cap at 240s
- Report **windowed-mean P**, never last-slice
- Record ω(t) and FoS(t) to distinguish settling from instability
- For Option A: constrain k search so ω ≤ ω_ceiling

### Step 3 — Verify at the chosen k

Same as Gate 2 v1 verify stage (spec §Step 4), minus Mach root-find:
- Sliding-window convergence ✓
- Stability gate (variance bound) ✓
- Record tip_mach_ss and tip_mach_max (caveat, not constraint)
- For Option A: assert n_clamped = 0. For Option B: record n_clamped with
  "outward load unverified" caveat flag.

### Step 4 — CSV output

Columns: all Gate 1 columns plus `tip_mach_ss`, `tip_mach_max`, `n_clamped_rings`,
`max_outward_N`, `n_sims_hunt`, `T_converged_s`, `stability_flag`, `omega_ceiling_rpm`.

Caveat flags:
- `tip_mach_ss > 0.7`: drag divergence, power optimistic
- `n_clamped_rings > 0`: outward load unverified
- `stability_flag = fail`: P variance high
- `T_converged_s = 240`: hit time cap, may not be converged

---

## Generator spec output

| Parameter | Source |
|-----------|--------|
| Rated speed | ω at constrained optimum (rpm) |
| Rated torque | Q_gen from verify stage |
| Rated power | P_kw at constrained optimum |
| Rated FoS | min_fos (with centrifugal loads) |

---

## Pre-requisites before Gate 2 runs

- [ ] Rod's decision: Option A or Option B
- [ ] Hardware ω ceiling from Rod (generator rpm, tether wrap rate) — if
      below 191 rpm, this becomes the binding constraint instead of clamp
- [ ] Tripwire committed to Gate 2 script: assert Mach at ω=260rpm ∈ [0.30, 0.60]
- [ ] Stable t=57-59s transient investigated for Tight (separate from Gate 2
      but may constrain it if low-k / high-ω is dynamically unstable)
- [ ] Clamp CSV columns spec'd and implemented
- [ ] Outward load path ticket created (if Option B)

---

## What replaces Gate 1

| Gate 1 | Gate 2 (v3) |
|--------|-------------|
| Unconstrained max-power | Constrained max-power (ω ≤ ω_ceiling) |
| 5s pre-sweep k-selection | Gate 1 machinery + adaptive converge |
| T_VERIFY = 60s fixed | Sliding-window, cap 240s |
| Last-slice P snapshot | Windowed-mean P |
| No ω(t) or FoS(t) | Full ω(t), FoS(t) for stability check |
| No Mach tracking | tip_mach as caveat column |
| No clamp tracking | n_clamped_rings, max_outward_N columns |
| No generator spec | Rated speed/torque/power as outputs |
