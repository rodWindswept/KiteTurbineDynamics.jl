# PRD 0006 Gate 2 — Tip-Mach-Constrained Control Map Re-run

**Status:** SPEC
**Date:** 2026-07-06
**Parent:** [PRD 0006 — Blade Geometry Audit & Recovery](0006-blade-geometry-audit.md)
**Supersedes:** Gate 1 (defects #2 and #3 — see DECISIONS.md 2026-07-06 entry)
**Gate:** Centrifugal loads verified/added → Gate 2 runs → delta doc regeneration

---

## Motivation

Gate 1 has three compounding methodology defects:

1. **70/30 blade-offset** (geometry — fixed at `13f304a`)
2. **5s pre-sweep k-selection** (dynamics — systematically picks right-flank k)
3. **T_VERIFY=60s insufficient** (dynamics — P(t) unconverged for V10 Tight at low k)

P2 k-refinement revealed that the true steady-state P(k) peaks at much lower k
for all three designs, but those peaks produce ω = 260–376 rpm. At these speeds,
expansion rotor tips at outer rings see Mach 1.2–1.7 inflow — well beyond the
subsonic BEM model's validity. A tip-Mach constraint is required.

Gate 2 replaces the unconstrained max-power hunt with a **Mach-constrained
root-find** that simultaneously delivers the generator specification.

---

## Mach limits

| Limit | Value | Purpose |
|-------|-------|---------|
| ω_target | 0.85 × 340 / r_tip,max | Design operating point (root-find target) |
| ω_hard | 0.90 × 340 / r_tip,max | Transient ceiling (verify-stage gate) |

r_tip,max = max_ring_radius + 0.7 × blade_span (post-13f304a geometry), maximised
over all rings (excluding ground ring index 1). Per-design ceiling — each builder
has a different r_tip,max because blade spans differ.

## Per-design ω ceilings (computed at runtime)

Estimated (exact values from script):

| Design | r_tip,max (est.) | ω_target (est.) | ω_hard (est.) |
|--------|-------------------|-------------------|----------------|
| V10 Tight λ=1.0 | ~12–15 m | ~160–200 rpm | ~170–210 rpm |
| V10 Reinforced | same rings | same | same |
| λ=0.69 | ~11–14 m | ~175–220 rpm | ~185–235 rpm |

---

## Hunt redesign: root-find, not peak-hunt

**For each row (builder × wind):**

### Step 1 — Compute ω_target

Build the system, compute r_tip,max, set ω_target = 0.85·a / r_tip,max.

### Step 2 — Bisect on k to hit ω = ω_target

`k_mppt` and `ω` are monotone (higher k → lower ω). Bisect k ∈ [K_MIN, K_MAX]
at each wind, running `ControlMapHunt.run_capture(builder, wind, k, T_HUNT; ...)`
until |ω − ω_target| < 0.5 rpm.

For rows where ω(K_MIN) < ω_target (system can't reach target speed even at
minimum k), accept k = K_MIN and flag the row.

### Step 3 — Neighbour check: is the peak interior or boundary?

At k_boundary (the k that hits ω_target), run one additional verify at
k_boundary + δ (δ ≈ 10% upward in log space). Compare P:

- **If dP/dk < 0** (P drops as k increases): the unconstrained peak lies in the
  infeasible zone (k < k_boundary, ω > ω_target). k_boundary is the constrained
  optimum. Done for this row.
- **If dP/dk > 0** (P rises as k increases): the peak is interior and feasible
  (ω < ω_target at the peak). Fall back to bracketed peak search above k_boundary
  (golden-section or Brent on P(k)).

This is cheaper than peak-hunting every row — the root-find is bisection on a
monotone function (~10–15 sims), and the neighbour check is 1 extra sim. Only
rows where the peak is interior pay for the bracketed search.

### Step 4 — Verify at the chosen k

Run `ControlMapHunt.run_verify_timeseries` with adaptive duration:

1. **Sliding-window convergence:** every 20s, compute mean P over the last two
   20s windows. Converged when |mean(P_last20) − mean(P_prev20)| / mean(P_last20) < 1%.
   Cap at 240s. Report windowed-mean P, never last-slice.
2. **Stability gate:** within the final converged window, require variance(P) /
   mean(P)² < 1×10⁻⁴ (i.e., P fluctuation < 1% RMS). If variance exceeds this,
   flag the row with `stability=fail` and diagnose before accepting.
3. **Tip-Mach gate:** log tip Mach over the full trace; `tip_mach_max` must be
   ≤ 0.9 throughout. The steady-state operating point targets 0.85; transients
   get the 0.05 headroom.
4. **Record:** P_kw (windowed mean), ω_rpm, min_fos, collapse_margin, tip_mach_ss,
   tip_mach_max, convergence_flag, stability_flag.

### Step 5 — CSV output

Columns: all Gate 1 columns plus `tip_mach_ss`, `tip_mach_max`, `k_boundary`,
`interior_peak`, `n_sims_hunt`, `T_converged_s`, `stability_flag`.

Caveat flags:
- Rows with tip_mach_ss > 0.7: flag `tip_mach>0.7 — drag divergence, power optimistic`
- Rows where k = K_MIN (speed floor): flag `k_at_floor — cannot reach ω_target`
- Rows with stability_flag = fail: flag `stability_unconfirmed — P variance high`

---

## Generator spec output

Gate 2 deliverable includes:

| Parameter | Source |
|-----------|--------|
| Rated speed | ω_target (rpm) — the design operating point |
| Rated torque | Q_gen at boundary k, from verify stage |
| Rated power | P_kw at boundary k |
| Rated FoS | min_fos at boundary k (with full centrifugal loads) |

The generator requirement falls out of the run rather than being an input.

---

## Pre-requisite: Centrifugal blade loads (do before Gate 2)

### Audit current state

Check whether the FoS path already includes centrifugal blade terms:
`src/ring_forces.jl` or wherever expansion-blade loads feed the structural check.

- If YES → confirm with a test, record the finding, proceed.
- If NO → add blade-root centrifugal stress before Gate 2:

### Centrifugal load addition (if needed)

- **Load source:** m_blade × r_cg × ω² at each expansion rotor, feeding root
  bending and tension on the attachment ring.
- **Magnitude check:** at ω_target ≈ 184 rpm, blade CG at ~14m: ~500g on blade
  mass. This is likely a dominant structural load at these speeds.
- **Blade mass model:** verify a non-placeholder mass exists (the builder
  reports `mass=49.2kg` — confirm this includes blade masses, or add them).
- **Regression test:** ω → 0 must recover current results bit-for-bit.
- **Preventative test:** assert the centrifugal term is present (Phase 4 style).

### Commit discipline

1. Clear Julia cache
2. Full test suite green (`julia --project=. test/runtests.jl`)
3. Commit the centrifugal fix under its own hash
4. Gate 2 CSVs all carry this hash — provenance: post-centrifugal, post-70/30

**Consequence:** Reinforced's FoS ≥ 1.96 margin was computed without centrifugal
loads (if absent). Gate 2 FoS numbers may drop across the board.

---

## Winds and builders

Same as Gate 1: [5, 7, 9, 11, 13, 15] m/s × 3 builders:

| Gate | Builder | Parameters |
|------|---------|------------|
| 2A | V10 Tight λ=1.0 | `v10_tight_builder(blade_scale=1.0)` |
| 2B | V10 Reinforced | `v10_tight_builder(r_bottom_scale=1.30, tether_diameter=0.004, blade_scale=1.0)` |
| 2C | λ=0.69 | `v10_tight_builder(blade_scale=0.69)` |

---

## Script: `scripts/hunt_gate2_mach_constrained.jl`

Single Julia script that:

1. `include`s `hunt_kmppt_bisect.jl` and reuses `ControlMapHunt` (builder
   wrappers, run_verify_timeseries, GIT_HASH auto-detect)
2. Computes per-design ω_target from system geometry
3. For each builder × wind: bisects k to hit ω_target, checks neighbour,
   verifies with adaptive convergence
4. Outputs `gate2_mach_constrained_summary.csv` and per-row timeseries
5. Reports generator spec table

CSVs carry: `code_state:<git-hash>` (post-centrifugal commit), `mach_limit:0.85`,
`mach_hard:0.90`, `selection:root-find`.

---

## What replaces what

| Gate 1 | Gate 2 |
|--------|--------|
| Unconstrained max-power (P_peak) | Mach-constrained optimum (ω = ω_target) |
| 5s pre-sweep k-selection | Bisection root-find on ω(k) |
| T_VERIFY = 60s fixed | Adaptive: converge when windowed-mean P < 1% drift |
| Last-slice P snapshot | Windowed-mean P over converged window |
| No tip-Mach tracking | tip_mach_ss + tip_mach_max columns |
| No stability check | Variance gate + ω(t) trace |
| No generator spec | Rated speed, torque, power as outputs |
