# V10 RE-CAMPAIGN PRE-GATES — three blocking scoping items

**Status:** DRAFT per Rod 2026-07-18. Three yes/no gates; sequencing 2 → 1 → 3
per Rod's call. Each gate is standalone-proposable but they share a dependency
chain in the implementation queue (mass/inertia lands before sensitivity runs,
sensitivity gates the re-campaign model, windowed objective gates the DE).

## GATE 2 — blade inertia + mass factor (BLOCKING, first in queue)

Two smaller-than-they-look fixes that are now first-order in winner
selection now that the free-energy term is dead (mass is half the objective).

### 2a. `expansion_blade_mass` missing `n_blades` factor

The function returns assembly mass per rotor, but the call site at
`builders_util.jl:100` passes it as `er.mass` (the per-rotor field) and
the objective sums that value. Verification:

### 2b. Zero blade inertia in the ODE

Per-rotor moment of inertia `0.5 · n_blades · blade_mass · (r_tip² − r_hub²)`
must be added to the ring's rotational state equation in `src/ring_forces.jl`
(one term per expansion rotor per step). Now that the free-energy ω² runaway
is killed, there is nothing left to mask missing inertia — designs that put
mass in the blades should pay for it in dynamics.

### Unified legacy toggle (Rod's catch #1)

Inertia is NOT behind `EXPANSION_INDUCTION` — it changes every simulation's
dynamics. The phantom gate and 10 pinned legacy scripts would go red the
moment it lands unless gated.

**Design:** replace the scattered per-feature toggles (currently just
`EXPANSION_INDUCTION`) with a single config:

```
struct ExpansionPhysicsConfig
    induction::Bool    # per-annulus induction + α model
    inertia::Bool      # blade mass in rotational ODE
    mass_fix::Bool     # n_blades factor in expansion_blade_mass
end
const EXPANSION_PHYSICS = Ref(ExpansionPhysicsConfig(false, false, false))
```

One setter: `set_expansion_physics!(induction, inertia, mass_fix)`.
The pinned scripts call `set_expansion_physics!(false, false, false)`
once; the default (post-gate-2) sets all true. The phantom-gate
bit-reproduction gate survives because it runs under the legacy config.

In scope: replace the 10 `set_expansion_induction!(false)` lines with
the unified call. Total touch: ~15 lines across pinned scripts.

### Implementation scope

- `src/ring_forces.jl`: one `J_rotor` term in the ring angular ODE (gated
  by `EXPANSION_PHYSICS[].inertia`)
- `src/expansion_rotor.jl:expansion_blade_mass`: `n_blades` parameter added,
  or return scaled by caller's `er.n_blades` (gated by `mass_fix`)
- `test/test_physics_toggle.jl`: new, unified — assert OFF matches legacy,
  assert ON changes output, assert phantom gate still PASS with all-off
  (grab the 117.4 kW assertion from `phantom_gate_test.jl`)

### Acceptance

1. Suite green with default all-false.
2. Phantom gate 117.4 kW PASS.
3. All-true vs all-false on triangle3 produce meaningfully different mass
   totals and dynamics (non-vacuous).
4. 12-gon @ 0.80 total blade mass is `n_blades`× what it was (assert
   after fix).

**ESTIMATED IMPLEMENTATION:** 2–4 hours.

---

## GATE 1 — α-constant sensitivity gate

The α-model constants are unanchored (Daisy proved non-discriminating:
the hub BEM is 93% of Daisy power, expansion slice invisible). Before
burning the DE budget for re-campaign, confirm that winner ranking is
stable under perturbation of the constants the α model actually touches.

### Candidates (Rod-specified, diversity on axes the constants govern)

1. **Triangle3 @ λ = 0.85** — 3 blades, low solidity, high-TSR regime
   (exercises the small-φ braking branch where dCL/dφ is steepest)
2. **12-gon @ λ = 0.80** — 12 blades, high solidity, current induction-ON
   regime where a sits near its equilibrium
3. **12-gon @ λ ≈ 0.45** — same geometry, light loading, a → 0 limit
   (must reduce to near-legacy — continuity gate exercised on a full system)
4. **Intermediate-n_lines design** — fish from the V10 campaign islands;
   desktop's choice via the dashboard's "V10 Island 51" decode path.
   (Rod: pick one with n_lines ∈ [4, 8], preferably one that was near the
   Pareto front under legacy physics so it's a credible competitor.)

### Perturbations (Rod's discipline: perturb constants, re-derive θᵢ each time)

| Constant | Baseline | Perturbations |
|---|---|---|
| TSR_design | 3.0 | 2.4, 3.6 (±20%) |
| slope | 2π | 1.2π, 3π (±30–50%: wider because the uncertainty is larger) |
| CL_max | 1.2 | 1.0, 1.4 |

**θᵢ re-derivation rule:** for each TSR_design/slope combination, recompute
`θᵢ = φ_design − CL_design/slope` where `φ_design = atan(1/TSR_design)`. This
keeps the design point CL = EXP_CL_DESIGN exactly, so sensitivity measures
only the off-design behaviour. Report sensitivity per-constant.

Each candidate evaluated at its known-viable (λ, k) pair ONCE (no sweep)
with the baseline and all perturbations: 4 × (1 + 6) = 28 cells, small ODE
commit, a day's compute if parallelised.

### RED criterion (Rod, sharper than Spearman)

**Any first-rank flip OR any pairwise sign change among the 4 candidates =
RED.** Spearman ρ reported as colour only (n=4 gives it minimal power).

If RED: the re-campaign model is not stable — α constants need calibration
before the DE can be trusted. Tulloch benchmarks / AeroDyn collaboration
becomes critical path (connects to Strathclyde: the follow-up Q&A on aero
models stops being a courtesy and becomes a dependency).

**ESTIMATED IMPLEMENTATION:** script is ~100 lines; compute ~8–24 h
serial, trivially parallelise over 4 Julia processes.

---

## GATE 3 — windowed objective with k in the genome

The corrected machine limit-cycles at low power; a snapshot-based DE
evaluator will reward whatever aliases well, just as the 60 s FoS snapshots
did. The convergence methodology from this week must be promoted into the
objective itself.

### Rod's design: k in the DE genome

`log₁₀(k)` becomes one more decision variable alongside geometry. Each
candidate is evaluated at its *own* best k by construction — the population
simultaneously optimises geometry and control — eliminating the MPPT scan
per candidate and the selection-bias risk of a fixed pre-pass k.

Post-campaign: a focused K-re-hunt around the winner's k (refinement only).

The genome already has ~14 variables; one more is cheap (the DE processes
it alongside them with zero extra evaluations). If there's a constraint in
the existing genome encoding that blocks an extra dimension, fall back to
a 3-point per-candidate bracket seeded by `k ∝ λ²` scaling — but genome-k
is strictly better.

### Window architecture

Per candidate:
1. Build system with geometry + λ from genome, k from genome.
2. Settle to equilibrium.
3. Kick + spin-up (single-k, no sweep — k is already optimal for this design).
4. MPPT window of stated duration (e.g. 30–90 s) with **1 Hz state snapshots**.
5. Score:
   - `P_score = mean(P_over_window)`
   - `FoS_score = min(FoS_over_window)`
   - `fitness = P_score` subject to `FoS_score ≥ FOS_DESIGN` (penalty or
     hard constraint — configurable)

The window captures the limit-cycling structure: a design that oscillates
between 10 and 30 kW earns ~20 kW mean; one that spikes at 50 but sits at
0 kW for 60% of the window is correctly penalised.

### Implementation scope

- `src/objective_v7.jl` (or `objective_v6` patched) — window-mode evaluator.
  Legacy snapshot mode preserved for backwards comparison.
- `test/test_objective_v7.jl` — assert that window-mean vs 60 s snapshot
  differ materially on the triangle (design that oscillates), proving
  the method is non-vacuous.
- DE genome: +1 variable (`log₁₀(k)`, bounds ∀{−2..3} covering the full
  range from triangle-k4 to 12-gon-k62).

### Acceptance

1. On a triangle candidate, window-mean P differs from a single-snapshot
   P by ≥ 10% (non-vacuous).
2. Re-evaluate the legacy 12-gon winner under the windowed objective:
   its fitness should drop materially (the aliased 326 kW FoS 2.15 is
   scored as the mean + min it actually is).
3. Twin runs of the DE with identical params but different RNG seeds
   converge on the same Pareto-front neighbourhood (window removes the
   aliasing randomness).

**ESTIMATED IMPLEMENTATION:** window logic 4–8 h; genome-k 1 h; DE
re-campaign compute ~days.

---

## Sequencing & gate interdependencies

```
GATE 2 (inertia + mass fix)
  │  inertia changes dynamics → mass moves rankings → must land first
  ▼
GATE 1 (α-constant sensitivity)
  │  if RED: constants need calibration before DE (Tulloch/AeroDyn critical path)
  │  if GREEN: model is stable, proceed (don't optimise constants further)
  ▼
GATE 3 (windowed objective + genome-k)
  │  the DE's scoring function — changes ranking as much as the physics
  ▼
V10 RE-CAMPAIGN (corrected objective on corrected physics)
```

## Yes/no questions for Rod

1. Gate 2: approve the `EXPANSION_PHYSICS` unified toggle design? (If yes,
   I implement gate 2 immediately — it's small and the phantom-gate
   protection closes the biggest risk.)

2. Gate 1: confirm the candidate diversity set (pick the Island-51 design
   yourself or let me fish from the dashboard? The "desktop's choice" you
   called for — if you want me to pull it, I need to know how to invoke
   that path.)

3. Gate 1: the "any first-rank flip OR any pairwise sign change" RED
   criterion — approve? (It's stricter than what I had and correctly so.)

4. Gate 3: genome-k — approve? The "log₁₀(k) as a DE variable" design is
   clean and eliminates the scan entirely; just confirming there's no
   known encoding barrier in the existing genome.

5. Delivery: the three gates as separate commits (2, then 1, then 3),
   each with acceptance tests, each gated by yourself before proceeding?
   Or build gate 2 now while gates 1 and 3 wait for sign-off?
