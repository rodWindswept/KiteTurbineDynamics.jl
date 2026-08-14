# Handover — DE Campaign Parallelism & dt Stability Investigation 2026-08-11

## Session goal

Rod's question: *"Is there a way we can get the DE campaigns run multi core or on the GPU,
or is it just a function of these massive ODE jobs that they need to run single core threads?"*

This split into two threads:
1. Where the parallelism actually is in the DE campaigns (answered, actionable, **not yet implemented**).
2. What pins `V11_DT = 4e-5` (investigated, **one claim raised and then falsified** — read the
   retraction section before acting on anything).

**No `src/` files were changed this session.** One new diagnostic script and one results CSV.

---

## Part A — Campaign parallelism (solid, unimplemented)

### The ODE cannot be parallelised internally

`run_canonical_sim!` (`src/simulation.jl:100`) is a sequential fixed-step loop; step *n+1*
depends on step *n*. State vector is 2708 doubles for a 12-gon (447 nodes, 13 rings) — far
too small for intra-step parallelism to beat its own synchronisation overhead.

Cost per Phase-A genome: `relax_s=120 + window_s=30` at `dt=4e-5` → 3.75M steps, run 3× over
the k-bracket (`src/objective_evaluator.jl:606`), plus 3 more at the 30 s pre-check.
**≈15M Euler steps per genome.**

### Where the parallelism is, ranked by payoff

| # | Opportunity | Location | Status |
|---|---|---|---|
| 1 | **Island loop is fully sequential** — 60 islands × 80 pop, independent by construction (`Random.seed!(42+island-1)`, separate populations, compared only at the end) | `scripts/run_v10_campaign.jl:145` | **Untapped. Biggest win — close to free 32×.** |
| 2 | **`POP_SIZE = 6` on a 32-core box** — `@threads` is present and correct, but caps at 6 busy cores (~19% utilisation). Also below the 5–10×D DE guidance for a 14-D genome | `scripts/run_feasibility_phase_a.jl:17,288` | Raising to 24–32 buys convergence *and* utilisation |
| 3 | **k-bracket runs 3 independent sims serially** | `src/objective_evaluator.jl:606-618` | `Threads.@spawn` → 3×, composes with (1) and (2) |
| 4 | Use `@sync`/`@spawn` not static `@threads` — eval cost is wildly heterogeneous (`decay_30s` aborts after one phase; healthy designs run all six sims), so static scheduling leaves a long idle tail | `scripts/run_feasibility_phase_a.jl:288` | Scheduling fix |

### Thread-safety status

The evaluator consolidation (commit `1960d6a`) did make this thread-safe: `ObjectiveConfig` is
per-eval and immutable, `_warmstart_at_relax` carries the horizon in it rather than mutating a
module global, `CSV_LOCK` guards row writes, and the `compute_rope_forces` workspace buffers
(commit `a3e700a`) are function-local.

**Still to verify before trusting a wider rollout:** that `BEAM`, `P_BASE`, `SP`, `LIFT_DEVICE`
are genuinely read-only under concurrent access. `sys.k_mppt_ref[]` is mutated per-eval
(`src/objective_evaluator.jl:388`) — safe only while each thread builds its own
`KiteTurbineSystem`.

### Threads vs processes

Threads should be fine now that `a3e700a` drove per-step allocations to zero (GC contention was
the classic reason to prefer `Distributed`). If threading plateaus below linear, `pmap` over
genomes sidesteps GC entirely; ~1–2 GB/worker against 62 GB RAM is affordable.

### GPU — recommended against

- Only viable pattern is DiffEqGPU `EnsembleGPUKernel`: thousands of independent trajectories,
  one per GPU thread. Populations here are 6–80. Wrong order of magnitude.
- Requires the RHS to be GPU-compilable: StaticArrays, no allocations, no data-dependent
  branches, no `try`/`catch`, no `@warn`. Current RHS has `findall(!isfinite, ...)` guards,
  ring-buckling checks, BEM evaluation, structural FoS. That is a rewrite of the physics core,
  and it would fork it from the validated dashboard path (against the bit-for-bit rule in
  CLAUDE.md).
- Box GPU is an RTX A4500 — FP32-heavy, FP64 at 1:32. A system stiff enough to want `dt=4e-5`
  almost certainly needs Float64.

---

## Part B — What pins `V11_DT`? (**contains a retraction**)

### ⚠️ RETRACTED CLAIM — do not carry this forward

Mid-session I claimed **"the rope sub-segment `c_damp` term is what pins dt"**, based on a
lumped per-node analytic bound giving `dt_damp = 4.588e-5` against `V11_DT = 4e-5` (87% margin),
versus a spring bound of `1.947e-4` with 4.9× more room. I attached a predicted ~4–5× speedup
to it.

**A direct damping sweep falsified this.** Scaling `c_damp` over a 30× range moved the
divergence threshold **not at all**:

```
c-scale  zeta     dt_last_ok   dt_first_bad
1        1.500    1.345e-04    1.600e-04
0.5      0.750    1.345e-04    1.600e-04
0.25     0.375    1.345e-04    1.600e-04
0.1      0.150    1.345e-04    1.600e-04
0.033    0.050    1.345e-04    1.600e-04
```

If `c_damp` were binding, `dt_crit` would track `1/ζ`. It doesn't. The damping change was
definitely applied (Part 3 mean tension moved 8587 N → 12530 N between λ=1 and λ=0.5), so this
is not a no-op bug.

**The `4.588e-5 ≈ 4e-5` agreement was a coincidence**, over-read as causation. The lumped bound
misses the measured threshold (1.345e-4) by 2.9×.

**The converse is also NOT established.** The probe starts from a settled state with no seeded
perturbation, so an unstable mode must grow out of roundoff (~1e-16) to trip the 1e4 m/s cap
within 0.5 s — needing per-step gain >1.012. It detects only *violent* divergence. A marginal
instability quietly degrading accuracy passes silently. So **"1.345e-4 survives, therefore 3.4×
headroom" is not a supported conclusion.**

**What pins `V11_DT` remains an open question.**

### Facts that survive (arithmetic on the built system, untouched by the falsification)

- `zeta = 1.5` at `src/initialization.jl:97`, `c_damp = 2·zeta·sqrt(EA/L0 · m_sub)` — a single
  line with **no cited basis in the source**.
- Assembled effective damping ratios `ζ_eff = c_node / (2·sqrt(k_node·m))`:

  | node type | n | `ζ_eff` | |
  |---|---|---|---|
  | BearingNode | 1 | **6.084** | 608% of critical |
  | RopeNode | 432 | **2.121** | 212% of critical |
  | SkyAnchorNode | 1 | 1.443 | 144% |
  | RingNode | 12 | 0.134–0.368 | only sensibly-damped nodes |

  Rope nodes read 2.121, not 1.5, because a node carries two sub-segments: `ζ_eff = √2·ζ`. The
  source constant is *per segment*; the assembled node is 41% more damped than that line reads.

- **Documentation bug:** `src/initialization.jl:149` declares
  `BRIDLE_C_DAMP = 500.0  # N·s/m — ~80% of critical for bearing mass`. The assembled bearing
  node is at **608% of critical** — wrong by ~7.6×. With 12 bridles plus the cyan line
  converging on a 0.3 kg bearing, the per-line reasoning doesn't survive assembly. Not currently
  binding dt, but misleading to anyone tuning damping from it.

- Past `ζ = 1` there is no oscillation left to suppress (roots go real), and the slow root goes
  as `−ω_n/(2ζ)` — relaxation gets *slower*. Overdamping past critical is counterproductive on
  its own terms.

### Reframing

The `ζ` question is now a **physics-fidelity** question, not a performance one. The model is
~30–150× more damped than UHMWPE/Dyneema material damping (`η ≈ 0.01–0.05`, `ζ = η/2`) and
unphysically past critical. But the dt payoff I attached to fixing it **is not there**.

Counter-argument to weigh: sub-segments are a 4-node lumped discretisation, so inflated `ζ` may
be standing in for unmodelled line aerodynamic drag, or deliberately killing spurious
high-frequency discretisation modes. That justifies exceeding *material* damping — but not
exceeding *critical*, and `lin_damp` is the better-targeted tool for numerical modes.

### Integrator facts worth carrying forward

`run_canonical_sim!` is **not** plain explicit Euler (I got this wrong initially too):
- Translation is **semi-implicit / symplectic** Euler — velocity from `du`, then position from
  the *new* velocity (`src/simulation.jl:119-120`).
- Ring twist uses the same pattern.
- MPPT `k·ω²` is **already implicit** on the ground ring (`src/simulation.jl:135-146`).

So "switch to velocity-Verlet" is largely already done.

### Methods that did NOT work (don't repeat them)

1. **Single-step spectral radius by power iteration.** A symplectic scheme puts marginal
   eigenvalues *on* the unit circle, so `ρ ≈ 1.00 ± noise` carries no signal; the `ρ > 1`
   threshold produced non-monotonic garbage.
2. **Finite-time perturbation amplification.** The settled operating point is **chaotic** —
   per-step growth ≈1.005 essentially independent of dt, swamping any dt-dependent term. Every
   dt below 1.6e-4 read "UNSTABLE" including dt/2.
3. **dt ladder on the X12 reference genome.** `X12` (inherited from
   `scripts/diag_dt_refinement.jl`) **no longer spins up under current physics** — `P_mean = 0.00 kW`
   at `ω ≈ 0.1 rad/s` at *every* dt including baseline. Any accuracy comparison on it is void.
   Note this if `diag_dt_refinement.jl` is ever re-run — its conclusions may rest on the same
   dead genome.
4. **Ringing-vs-ζ at fixed dt.** Non-monotonic (0.53, 0.64, 0.74, 0.58, 0.72) — chaos again.

---

## Recommended next step

**Drop stability theory; measure what actually matters — does the campaign metric move?**

Run a convergence study on a design that genuinely spins. `scripts/results/recampaign/feasibility_phase_a_v4.csv`
has 17 rows; best by `f_feas` is **7.41 kW / 33.8 rpm / k=3812** (tier `stalled`, but it does
produce power). Compare `P_mean`, `FoS_min`, `ω_eq` at dt/4, dt/2, dt, ×2, ×4.

- Flat from 4e-5 to 1.6e-4 → headroom is real and decision-relevant.
- Drifts → you have the **accuracy** limit, which is the more useful number than the stability
  limit anyway.

This sidesteps both defects above: no perturbation-growth detection floor, no chaos dependence,
and it runs on a design that isn't stalled.

**Sequencing suggestion:** Part A item 1 (thread the V10 island loop) is independent of all of
Part B, is the largest single win, and carries no physics risk. It could land while the dt
question is still open.

---

## Artifacts

| Path | Status |
|---|---|
| `scripts/diag_dt_stability_budget.jl` | **New.** Part 1 (per-node `ζ_eff` audit) is sound and reusable. Parts 2–3 are the falsified/invalid measurements — rewrite or delete before relying on them. |
| `scripts/results/dt_stability_budget.csv` | **New.** Sweep + ringing output. |

Uncommitted. Nothing in `src/` touched. Test suite not run this session (no source changes to
regress).

---

## Part C — Hypothesis: does damping explain the BEM↔ODE reverse-torque gap?

Raised at end of session by Rod, connecting this work to another Hermes session's finding:
*"k=1.0 through k=28.7, margin or no margin, settle or cold start, ramp or kickstart — every
single test reverses to ω≈-0.2 rad/s. The ODE has a systematic torque pushing the rotor backward
that the BEM model doesn't capture."*

**This is an untested hypothesis reasoned from a session summary, not from that session's test
code. Falsify it before building on it.**

### Damping magnitude alone cannot be the source

A viscous damper gives `τ = −c·ω`, whose equilibrium is **ω = 0 exactly**, for any `c`. Raising
ζ changes the *rate* of approach, never the *fixed point*. Parking at ω = −0.2 rad/s requires a
torque still forward-pushing at ω < −0.2 — i.e. **a constant offset / symmetry-breaking term**.
Pure damping has none.

So `zeta = 1.5` is exonerated as the source — but is a strong candidate as the **gain** on
whatever the source is. Two asymmetries exist that damping multiplies:

### Asymmetry 1 — tension rectifier (`src/rope_forces.jl:18`)

```julia
return max(0.0, ss.EA * strain + ss.c_damp * vel_proj)
```

`max(0.0, …)` **rectifies**: the damper adds tension at full strength but is clipped when it
would subtract. Over an oscillation cycle this leaves a non-zero mean force — a DC bias, exactly
the offset torque required.

Scaling: at 1% strain the damper only competes above ~33 m/s relative velocity (negligible). Near
the slack boundary (ε ~ 1e-4) it competes at **~0.3 m/s**, which a spinning TRPT sees constantly.
At `ζ_eff = 2.121` the damper term is >2× physical, so the rectified bias is inflated by roughly
the same factor the damping is.

### Asymmetry 2 — orbital damping reference frame (`src/initialization.jl:517-550`) — LEADING SUSPECT

More concerning than `c_damp`, and it is a **velocity overwrite, not a force — so it never appears
in any force-balance instrumentation.** This may be why the other session's force-level hunt came
up empty.

It damps `v_osc = v − v_orbital`, which is well-intentioned, but `v_orbital` is idealised three
ways:

1. Uses `na.radius` / `nb.radius` — **static design radii**. This is an *expansion* rotor system;
   if rings drift or expand under load the reference velocity is systematically wrong.
2. Linearly interpolates between the two ring attachment velocities, but the line is **helical
   under twist** — true tangential velocity isn't the linear interpolation.
3. `pp1, pp2` computed **once from the hub ring** (`src/initialization.jl:502`) then applied to
   every rope node in every segment — but rings tilt independently (`ring_tilt_axis` is per-ring).

Any of these puts a *steady kinematic offset* into `v_osc` rather than pure oscillation.

**And the rate is extreme:** `rate = −log(0.05)/4e-5 ≈ 74,900 s⁻¹`, e-folding **13.4 µs**. Over one
step retention is `exp(−3.0) = 0.05` — **95% of `v_osc` destroyed every step.** That is not
damping; it is very nearly a hard kinematic constraint dragging rope nodes onto a possibly-biased
reference field. A constraint that strong onto a slightly-wrong field is precisely the shape of an
ω-independent reverse torque.

### Decisive tests (cheap; this IS the "instrument the ODE force components" step)

1. **`c_damp = 0`, re-run the reverse test.** If ω still parks at −0.2, damping is fully
   exonerated. `set_damping!` machinery already exists in `scripts/diag_dt_stability_budget.jl`.
2. **`lin_damp = 0`.** Isolates the orbital overwrite.
3. **Measure `L_z` (angular momentum about the shaft axis) immediately before and after
   `orbital_damp_rope_velocities!` each step, and accumulate.** If that sum is non-zero and
   systematically negative, the source is found outright — and it is a number **no force-level
   instrumentation would ever find**, because the overwrite bypasses the force path.

**Start with test 3.** Handful of lines; either a smoking gun or a clean rule-out.

---

## Open questions for Rod

1. **What is `zeta = 1.5` based on?** No basis in the source. Was it tuned to suppress something
   specific, or picked for stability headroom? This determines whether it can move at all.
2. **Should `ζ` be raised as its own issue?** It's now a physics-fidelity call, decoupled from
   performance — squarely Rod's decision, not an agent's.
3. Worth checking the AWE tether-damping literature (the `awe-knowledge` skill has a searchable
   paper index) for a defensible `ζ` for a lumped 4-node Dyneema tether segment, rather than
   taking the 0.01–0.05 material figure from an agent.
