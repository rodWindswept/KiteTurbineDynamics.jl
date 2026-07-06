# PRD 0006 Gate 2 — Constrained Control Map Re-run (v4)

**Status:** SPEC (revised 2026-07-06 — spokes replace clamp, neutral-loading target)
**Parent:** [PRD 0006 — Blade Geometry Audit & Recovery](0006-blade-geometry-audit.md)
**Supersedes:** Gate 1 (defects #2 and #3) · Gate 2 v1 (Mach root-find — retracted) · Gate 2 v3 (clamp-boundary — superseded by spoke design)
**Gate:** Centrifugal loads ✅ · Spoke ties ✅ · FR4 + full suite ✅

---

## Constraint summary

| Constraint | Type | Binding? | Source |
|-----------|------|----------|--------|
| Spoke FoS (7mm Dyneema, SWL 10.5 kN) | Structural | **Yes** — crosses 1.0 at ~330 rpm | SpokeParams, `_evaluate_trpt_design_impl` |
| Spoke drag (ODE, ~12 kW at 260 rpm, ω³) | Parasitic loss | **Yes** — ~5-8% of design at 260 rpm, grows with ω³ | `compute_ring_forces!` |
| Ring compression FoS | Structural | Binding at low ω (<~200 rpm) | Existing evaluator (unchanged) |
| Mach 0.7 (drag divergence) | Model caveat | No — non-binding below 440 rpm | Caveat column only |
| Mach 0.85 (transonic) | Model caveat | No — non-binding below 500 rpm | Caveat column only |
| V10 Tight instability | Dynamic | TBD (t=57-59s transient) | Separate investigation |
| Hardware ω ceiling | Rod's call | TBD | Generator rpm, tether wrap rate |

**Spoke engagement** replaces the old "centrifugal clamp" concept. The clamp was
a model validity boundary (FoS reads ∞ when F_v < 0); the spokes are a real
structural member with measured FoS, drag, and a design target ("neutral radial
loading" — operate at small positive spoke tension, bias slightly outward).

---

## Spoke check at reference ω values

| ω (rpm) | T_spoke/vertex | FoS (7mm) | Regime |
|---------|---------------|-----------|--------|
| 150 (Gate 1 typical) | <2 kN | >5 | Compression-dominated, spokes slack |
| 191 | ~4 kN | 2.6 | Spokes begin to engage |
| 260 (Reinforced peak) | ~6.5 kN | 1.62 | "Fly-light" band — near neutral |
| 332 (Tight peak) | ~10.6 kN | 0.99 | Spoke FoS crosses 1.0 |
| 376 | ~13.6 kN | 0.77 | Spoke failure |

**Spoke drag:** ~12 kW at 260 rpm (~5-8% of 150-350 kW design), ~30 kW at
376 rpm (ω³ scaling). Drag may cap useful ω before structural FoS does.

**Neutral radial loading** (Rod 2026-07-06): operate at small positive spoke
tension — beams near-zero compression, spokes in light standing tension,
structure sized for cruise can be genuinely light. Bias slightly outward
(taut lines don't snap, sewn tabs tolerate steady low tension better than
slack-taut cycling). Guard: ramp transients (startup/shutdown) may dominate
sizing — check before betting a design on neutral cruise.

---

## Hunt procedure

### Step 1 — Compute per-design spoke engagement curve

For each builder, compute T_spoke(v, k) across the wind band. The spoke
engagement onset is load-dependent, not a fixed ω limit. Use the evaluator's
`max_spoke_tension_N` and `min_spoke_fos` per row.

### Step 2 — Constrained peak-hunt per row (builder × wind)

Reuse Gate 1 machinery (`ControlMapHunt.hunt_control_map`) with:
- `max_power=true` (unchanged)
- Spokes enabled (`SpokeParams(enabled=true)`)
- Adaptive convergence: sliding 20s windows, cap 240s
- Report **windowed-mean P**, never last-slice
- Record ω(t), FoS(t), spoke FoS(t) to distinguish settling from instability

### Step 3 — Verify at the chosen k

- Sliding-window convergence ✓
- Stability gate (variance bound) ✓
- Spoke FoS per ring (record `min_spoke_fos`, `n_spokes_engaged`)
- Spoke drag power loss (record per ring)
- tip_mach_ss and tip_mach_max (caveat, not constraint)

### Step 4 — CSV output

Columns: all Gate 1 columns plus `tip_mach_ss`, `tip_mach_max`,
`n_spokes_engaged`, `max_spoke_tension_N`, `min_spoke_fos`, `spoke_drag_kW`,
`standing_radial_load_N` (signed, per worst ring), `n_sims_hunt`,
`T_converged_s`, `stability_flag`.

Caveat flags:
- `min_spoke_fos < 1.5`: spoke FoS marginal
- `tip_mach_ss > 0.7`: drag divergence, power optimistic
- `stability_flag = fail`: P variance high
- `T_converged_s = 240`: hit time cap, may not be converged
- `abs(standing_radial_load_N) < 500`: near neutral — check dwell flag

---

## Generator spec output

| Parameter | Source |
|-----------|--------|
| Rated speed | ω at constrained optimum (rpm) |
| Rated torque | Q_gen from verify stage |
| Rated power | P_kw at constrained optimum |
| Rated FoS | min of compression FoS, spoke FoS |
| Rated spoke load | standing_radial_load_N at operating point |

---

## Pre-requisites before Gate 2 runs

- [ ] Stable t=57-59s transient investigated for Tight
- [ ] Static equilibrium parity (spoke drag in objective_v10) — deferred,
      ODE-only for Gate 2 runs
- [ ] Tripwire: assert Mach at ω=260rpm ∈ [0.30, 0.60]

---

## What replaces Gate 1

| Gate 1 | Gate 2 (v4) |
|--------|-------------|
| Unconstrained max-power | Constrained max-power (spoke FoS ≥ 1.5) |
| 5s pre-sweep k-selection | Gate 1 machinery + adaptive converge |
| T_VERIFY = 60s fixed | Sliding-window, cap 240s |
| Last-slice P snapshot | Windowed-mean P |
| No ω(t) or FoS(t) | Full ω(t), FoS(t), spoke FoS(t) |
| No spoke tracking | n_spokes_engaged, spoke FoS, spoke drag |
| No generator spec | Rated speed/torque/power/spoke load as outputs |
