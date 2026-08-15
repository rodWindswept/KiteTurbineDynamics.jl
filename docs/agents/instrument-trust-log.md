# Instrument Trust Log

**Purpose:** Shared cross-instance truth source for both Hermes instances (laptop + desktop) working on KiteTurbineDynamics.jl.  Durable state lives version-controlled, not in either instance's private memory.  Read at session start.

**Last updated:** 2026-08-12

## Duplicate-Representation Audit

Constants or parameters defined in two places that must stay in sync:

| Item | Location A | Location B | Risk | Action |
|------|-----------|-----------|------|--------|
| ODE timestep | `control_map_hunt.jl:37` `DT=4e-5` | `objective_v11.jl` `V11_DT=4e-5` | **DUPLICATE, in sync** — two constants, same value, must not drift | Single source, or test asserting `DT == V11_DT` |

---

---

## Fault Ledger

Every confirmed instrument fault with its fix commit, so neither instance re-discovers a fixed bug.

| Date | Fault | Symptom | Root Cause | Fix Commit |
|------|-------|---------|-----------|------------|
| 2026-08-14 | **Hub-ring numerical divergence passed all ground-side metrics** | 18m v13 winner (fitness −6.66) shows ω_hub=3.5e66 within 5s of the gate, NaN-frozen state (identical checkpoints for 30s), while ω_gnd=16.41, P_gen=8.60 kW, twist ratio 0.0 | r_hub=0.474 (DE shrank toward the 0.2 bound), inverted taper, n_active=1 → tiny hub-ring inertia + freewheel + MPPT at ground → hub ring diverges; twist α NaN-freezes (reads 0), diverged ring's FoS filtered as NaN. Every instrument was ground-side. The Betz gate is OUTPUT-side: generator power (8.6 kW) was below the swept-area ceiling, so it passed — it never checks intermediate ring states | `tip_speed_sanity_ok(u, sys)`: every ring rim + every rotor tip ≤ 100 m/s (Rod 2026-08-14; design point ~44 m/s at TSR 4, 11 m/s). Hard reject in evaluate_windowed + gate. r_hub lo raised 0.2→0.7. Acceptance B6/B7 (7183f96, tightened same day) |
| 2026-08-13 | **Evaluator tested 5 kW designs at k_mppt=10.0** | 18m flywheel winner showed P_end 4.18 kW in the evaluator vs 2.26 kW at the system's own gain (gate) — window power inflated ~2× | `ObjectiveConfig.k_mppt` default (10.0) is the 50 kW-scale controller gain; the v12 5 kW campaigns never overrode it. ~5× the scaled system's rated gain (p.k_mppt ≈ 1.94) | v13 cfg sets `k_mppt = p.k_mppt`. Caught by acceptance test B2 |
| 2026-08-13 | **Kickstart winds healthy chains past δα*** | Seed evaluated `:reject, twist_crossed=true` in v13 while the gate (no kick) showed ratio 0.3 | Cold-path 2 s PTO motor kick (k=−60, ~115× MPPT gain, ~21.7 kN·m at ω≈19) is a legacy ζ=1.5 stall escape; post-ζ-fix the settle reaches the productive branch directly and the kick itself violates the collapse limit | `ObjectiveConfig.kickstart_s` (default 2.0 = v12; v13 sets 0.0). Caught by acceptance test B3 |
| 2026-08-13 | **Twist detector read the ω block, not the α block** | B1-B3 all flagged twist_crossed=true (even the healthy seed); B5 unit test showed max_ratio=0.0 on a +π-wound state | ODE state layout: α at `u[6N+1:6N+Nr]`, ω at `u[6N+Nr+1:6N+2Nr]`. The first detector draft read `u[6N+Nr+ri]` (ω block) — post-settle ω diffs ≈ 0 (ratio 0.0), window ω differentials (rad/s) compared against δα* (rad) → spurious collapse flags everywhere | Correct index: `Δα = u[6N+ri+1] − u[6N+ri]`. Test B5b (+π wound α) is the unit guard against the block confusion |
| 2026-08-13 | **Gate/evaluator read ω_hub, not ω_gnd** | 5kW designs "sustain" 6.34 kW at 20s but decay to ~2 kW by 60s; power budget shows P_gen→0 while hub freewheels | Gate P = k·ω_hub³ but generator extracts k·ω_gnd³ (Mode 0, ground ring). After t≈50s the torsional chain decouples: ω_gnd→0, ω_hub stays ~9 rad/s | `scripts/ode_gate_v13.jl` — P_gen = τ_gen·ω_gnd via `get_generator_torque` + per-segment twist detector vs δα* (acceptance tests A1–A4 green 2026-08-13; island-1 winner now FAILS: twist ratio 169×, P_gen 0.84 kW). See `docs/plans/2026-08-13-gate-reinstrument-twist.md` |
| 2026-08-13 | **Torsional collapse CONFIRMED at 5kW (top segment)** | Twist concentrates at ring10→hub: Δα grows to 22,425° (62 revs) vs 42.6° collapse limit; brake=false | Inverted taper (r_ground 2.5m > r_hub 0.65m): τ_cap ∝ r_min² → narrow hub end is weakest segment. DE shrank r_hub for mass | Static torsional gate was RIGHT (scored 0.31). Do not relax it for ≤7kW — re-enable as hard gate |
| 2026-08-12 | **ζ=1.5 rope damping + tension rectifier = DC reverse torque** | EVERY ODE test stalls to ω≈−0.2 rad/s regardless of genome/k_mppt/startup; BEM predicts 22 kW, ODE produces ~0 | `initialization.jl:97` hardcoded zeta=1.5 (~30-150× physical Dyneema). `max(0.0, EA·ε+c_damp·v)` rectifier in `rope_forces.jl:19` clips the damper asymmetrically → non-zero mean force (DC bias) that overwhelms aero torque | ζ promoted to `SystemParams.zeta` default 0.05; `initialization.jl` uses `p.zeta`. See DECISIONS.md [2026-08-12] + `handovers/handover-2026-08-12-zeta-damping-fix.md` |
| 2026-08-12 | ~~Static evaluator false-negative at 5 kW~~ **SUPERSEDED 2026-08-13** | `evaluate_design_v5` rejects ALL 5kW designs: torsional FoS < 1.5; ramp evaluator `solve_equilibrium_self_consistent` returns nothing | ~~τ_cap ∝ T_total ∝ P — 50kW-calibrated gates unreachable at small scale~~. The ODE later CONFIRMED the torsional gate: the 5kW winner's chain collapses at the top segment (Δα=22,425°). The gate was right; the ODE gate was reading the wrong ring (ω_hub not ω_gnd). Daisy tors=0.22 remains an open question (its geometry differs — 13 dense lower rings per Tulloch) | Re-enable torsional gate for ≤7kW; see fault row above |
| 2026-08-12 | settle_to_operational_state ω_rated_max clamp masks genome variation | 57-variant perturbation sweep: Δω=0.000 across ALL 14 dims | settle clamps ω at the `ω_rated_max` argument — passing 9.5 clamps every genome to the ceiling; true equilibrium ≈16 rad/s | Pass ω_rated_max=60 (or sky-high) when measuring equilibrium ω per-genome |
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
| `lin_damp` (rope damping rate) | 0.05 → rate=75,000 Hz | Per-step orbital velocity retention. At production DT damps rope oscillations in ~13 µs — near-rigid orbital slaving. Never physically calibrated. | **HIGH** — orbital damping ΔL_z measurement (2026-08-12) shows near-zero cumulative bias, exonerating it as the reverse-torque source. The "alive or dead" behaviour previously attributed to this rate was actually ζ=1.5 (see Fault Ledger 2026-08-12). Still unanchored, but no longer suspected of causing the stall. |
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

## Detection Pattern: Peak-Value Metrics Alias on Limit Cycles

A convergence or comparison gate built on `P_max` (or any single-sample peak) is
phase-sensitive: DT and DT/2 runs decorrelate in phase and hit different peaks of
the SAME physical limit cycle, so their peak ratio differs even when the integrator
is fully converged. **Symptom:** an isolated "valid" point flanked by "divergent" ones,
with the divergent points showing SMALL peaks (not exploding).

2026-07-22: this misclassified `lin_damp=0.5` as divergent in the damping-rate
sweep; the real valid band was 0.5–0.8. **Rule:** gate convergence on windowed
statistics (mean + range agreement), never on peaks. Genuine divergence *explodes*
the peak (thousands of kW); phase-noise jitters it by 1.5–2×.

Before launching any campaign, confirm that all convergence/promotion gates use
windowed agreement, not a peak or endpoint. A peak-based gate anywhere in the
objective pipeline would quietly reintroduce this error.

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
- [ ] `python3 scripts/kwarg_default_audit.py --check` — no undocumented HIGH-danger defaults
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
