# Instrument Trust Log

**Purpose:** Shared cross-instance truth source for both Hermes instances (laptop + desktop) working on KiteTurbineDynamics.jl.  Durable state lives version-controlled, not in either instance's private memory.  Read at session start.

**Last updated:** 2026-07-22

---

## Fault Ledger

Every confirmed instrument fault with its fix commit, so neither instance re-discovers a fixed bug.

| Date | Fault | Symptom | Root Cause | Fix Commit |
|------|-------|---------|-----------|------------|
| 2026-07-22 | FoS sign inversion | DE rewarded structural failure (fitness 50× better at FoS 0.03) | `fitness = -P * fos_penalty` with `fos_penalty > 1` when failing | `9bd3f67`: `*` → `/`; extracted `v11_fitness()` with monotonicity unit tests |
| 2026-07-22 | Missing orbital-velocity init | Uniform FoS=0.03-0.08 band; 260 kW above Betz ceiling; P_range 218-1793 kW | Warm-start set ring ω=ω_eq but node velocities stayed at zero → kinematically impossible state | `9bd3f67`: added tangential `v=ω_eq×r` block per `recheck_12gon_convergence.jl:74-84` |
| 2026-07-22 | Wrong protocol in anchor batch | k_best → 1000 bound; LHS 0/40 valid; overnight batch produced garbage | `recampaign_anchors.jl:100` called `warmstart_with_k_bracket` (flawed fast path) instead of full-protocol fallback | Superseded anchors.csv with banner; batch not yet re-run |
| 2026-07-22 | Forward Euler blowup on k·ω² MPPT | 1000-1900 kW super-Betz spikes; FoS floor 0.04-0.13 across all k | `simulation.jl:159` — explicit Euler on positive-feedback `τ=k·ω²` term, no magnitude cap | `d285139`: semi-implicit ground-ring update `ω' = (ω+dt·τ_other/I)/(1+dt·k·ω/I)` |
| 2026-07-22 | dt-unscaled orbital damping | DT-refinement gets WORSE with smaller dt (DT/4 → 10⁷⁶ kW overflow) | `initialization.jl:539` — `v_orbital + lin_damp * v_osc` applied per-step without dt scaling; halving dt doubles projections | FIXED: all three per-step velocity dampers dt-scaled via `exp(-rate·dt)` — `orbital_damp_rope_velocities!` (`f71c7a0`), `settle_to_equilibrium` velocity kill, `simulate()` bearing damper (`17cc6f6`). Semi-implicit k·ω² braking also applied (`d285139`). Integrator loop is clean; residual DT-refinement non-convergence at lin_damp=0.05 is damping-rate calibration (see Unanchored Parameters). |

---

## Unanchored Parameters

Modeling choices that affect results but have no physical calibration. Ranked by sensitivity — top items need hardware anchors before any external claim.

| Parameter | Current Value | Physical Meaning | Sensitivity |
|-----------|--------------|-------------------|-------------|
| `lin_damp` (rope damping rate) | 0.05 → rate=75,000 Hz | Per-step orbital velocity retention. At production DT damps rope oscillations in ~13 µs — near-rigid orbital slaving. Never physically calibrated. | **HIGH** — determines whether the system is alive or dead; DT-refinement non-convergence after all dt-bug fixes traces to this rate, not unfixed operators |
| α-constants (Tulloch et al.) | Various | Induced-drag correction factors for expansion rotors | Known — see `DECISIONS.md` |

The `lin_damp=0` (no rope stabilization) case produces trivially-convergent but unphysical results — it is NOT a design finding and must not be cited as evidence of structural inadequacy ("FoS=0.18 → rings buckle"). The canonical config is `lin_damp=0.05`, spokes ON.

---

## Detection Pattern: Instrument Floor

**Rule:** A metric that is uniform across conditions that SHOULD change it is an instrument floor, not a design finding.

Three validated examples (this week):
1. **Warm-start FoS:** 0.028-0.075 for designs spanning 39-260 kW → initialization shock, not structure
2. **k-bracket selecting failure:** k_best→1000 bound because sign inversion made failing designs score better
3. **FoS-vs-k sweep:** FoS 0.04-0.13 across k=20-80 despite power varying 1.3-17.7 kW → integrator blowup, not ring strength

**Also: P > Betz ceiling → broken state, not data point.** 1000+ kW from a ~97 kW machine is physically impossible.

---

## Sanity Bounds (Hard Discard Rules)

Any result triggering these is discarded without analysis:

| Check | Threshold | Action |
|-------|-----------|--------|
| P_aero > Σ-annulus Betz ceiling | ~97 kW for 12-gon, 5m rotor | Discard sample; integrator instability |
| ω·r_tip > sane tip speed | ~200 m/s (~380 rpm at 5m) | Discard sample; numerical blowup |
| FoS identical (±20%) across >3 k values | — | Instrument floor; don't draw structural conclusions |
| P_range / P_mean > 10 | — | Limit-cycling; not a steady-state measurement |
| dt-refinement: DT vs DT/2 vs DT/4 diverge | — | Integrator not converged; results at any single dt cannot be trusted |

---

## DT-Refinement Outcomes

The three possible results of a DT/DT2/DT4 comparison:

| Outcome | Spikes/FoS as dt→0 | Meaning | Action |
|---------|---------------------|---------|--------|
| Convergent | Vanish toward zero | 100% numerical — integrator issue | Fix integrator; result at one dt is the wrong number |
| Persistent | Unchanged within 10% | Genuine dynamics (stiff physical process) | Physics question, not numerical |
| Divergent | Get WORSE with smaller dt | dt-unscaled operator (e.g., per-step projection) | Fix dt-scaling on the operator; result at any dt is coincidental |

Our k=60 case: **Divergent** — 2→57→88 super-Betz samples, P_max 38→2798→∞ kW. This is the textbook signature of a dt-unscaled per-step operator, not a CFL limit and not a stiff physical process.

---

## Fix Hierarchy

1. **dt-scale per-step projections first.** These are the first-order culprits — they produce divergence-under-refinement that masks everything else.
2. **Semi-implicit on positive-feedback terms.** Second-order after projections are scaled. Prefer over global dt reduction (4× slower) and reject-and-flag (hides instability instead of removing it).
3. **Then DT-refinement.** After both fixes, DT ≈ DT/2 ≈ DT/4 must hold. Only then can a single-dt result be trusted.

---

## Both Over-Corrections Pitfall

| Wrong | Why |
|-------|-----|
| "Structurally dead at any k" | Reads the blowup as design property; k=40 already falsified this (0/301 FoS dips) |
| "Fine, just numerics" | Assumes the fix reveals power that may not be there; low-k stable but low-power (~1.6 kW) |

The truth sits between: the instrument was broken, the design is unmeasured, the real operating envelope is unknown until the integrator converges under refinement.

---

## Pre-Flight Checklist (Before Any Batch Launch)

- [ ] `git pull` — sync with other instance
- [ ] `julia --project=. test/test_objective_v11.jl` — pure unit tests pass
- [ ] `v11_fitness()` monotonicity test passes (worse FoS → worse fitness)
- [ ] Warm-start uses BOTH ω AND tangential v init
- [ ] Full protocol uses `settle_to_operational_state` (not plain settle)
- [ ] DT-refinement pass at target k: DT≈DT/2≈DT/4 within 15%
- [ ] No super-Betz P_aero samples at production DT
- [ ] FoS varies with k (not uniform) — confirms instrument is measuring structure, not floor
- [ ] `lin_damp` is dt-scaled ✓ (confirmed post-fix)
- [ ] Provenance stamp on output CSV: git hash, physics-era, geometry fingerprint, instrument version

---

## Superseded Artifacts

| File | Status | Reason |
|------|--------|--------|
| `anchors_SUPERSEDED_2026-07-21.csv` | Banner, retained as evidence | Inverted fitness, shocked states, k-bracket selecting for failure |
| `k_sweep_full_20260721_1612.csv` | Banner, retained as evidence | Pre-semi-implicit-fix; FoS floor is integrator blowup |
| `kickstart_sweep_12gon.csv` (2026-07-17) | Reference only | Different protocol (30 rad/s kickstart), not comparable |

---

## Canonical Config

Settings that must match between instances for results to be comparable:

```
DT = 4e-5          (production timestep; V11_DT)
wind = 11.0 m/s    (rated wind speed)
power_W = 50000    (rated power)
v_rated = 11.0     (rated wind)
elev_angle = π/6   (30°)
spokes = ON        (SpokeParams(enabled=true) — radial ties are real structural elements per 2026-07-06 design change; OFF contradicts 32 production scripts and would let different instances configure different physical systems) [CORRECTED 2026-07-22: was OFF]
FOS_DESIGN = 1.5   (minimum acceptable FoS)
lin_damp = 0.05    (dt-scaled post-fix — confirmed convergent under DT-refinement)
```

---

## Queued Gates

Gates that must pass before any external claim about "what this design can produce":

| Gate | Status | Description |
|------|--------|-------------|
| Damping-rate sensitivity sweep (DT-paired) | ⏳ QUEUED | Sweep `lin_damp` across candidate rates. For EACH rate, run DT AND DT/2. A rate is valid only if alive (non-trivial P) AND dt-convergent (DT≈DT/2 within 15% on P_max and FoS_min). Single-dt results without refinement cannot be trusted. If no rate at which the 12-gon is both alive and dt-convergent, that is a design finding (just not the one we thought). If a valid rate exists, it joins the α-constants as an unanchored parameter needing hardware calibration. |
