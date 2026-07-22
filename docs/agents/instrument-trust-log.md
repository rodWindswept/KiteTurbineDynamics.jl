# Simulation Instrument Trust Log — shared cross-instance memory

**Purpose.** Two Claude/Hermes instances (Rod's laptop Cowork, the desktop
remote) cannot see each other's private memory. Git is the only shared channel.
This file is the single source of truth for *how far the simulator can be
trusted right now* and *which numbers are contaminated*. Update it by commit
whenever instrument state changes; read it at session start (add to CLAUDE.md
"Essential Reads"). Same discipline as the doc-staleness work: version-controlled,
one source of truth, no per-instance divergence.

**Rule of use.** Before quoting ANY absolute number (kW, FoS, ω) from a sweep,
check it against §2 (trust state) and §3 (sanity bounds). A number that violates
a sanity bound is an instrument reading, not a datum — no matter how converged
the run looked.

---

## 1. Current headline state (2026-07-22, laptop instance)

- The V10/V11 **integrator is NOT converged under timestep refinement.**
  DT/DT2/DT4 at k=60 diverge (post semi-implicit fix: 6 kW / 2216 kW / 5224 kW).
  **Do not run production sweeps or draw design verdicts until refinement
  converges (DT ≈ DT/2 ≈ DT/4).**
- Leading cause (high-confidence, code-read, not yet run-confirmed):
  `orbital_damp_rope_velocities!` (`src/initialization.jl:539`) applies a
  **per-step, dt-independent** velocity projection `v_orbital + lin_damp·v_osc`.
  Per-step operators diverge as dt→0 — matches the observed "worse with smaller
  dt" signature, which classic stiffness cannot produce.
- Confirming experiment (cheap, ~1 h): re-run DT/DT2/DT4 refinement with
  `lin_damp = 0`. If divergence-under-refinement vanishes → confirmed the
  damping operator. Fix = dt-scale the retention: `v_osc·(1 − rate·dt)` or
  `v_osc·exp(−rate·dt)`.
- **"Clean at production DT" ≠ trustworthy.** It is a single-point coincidence
  below the operator's tolerance, not a converged result.

## 2. Instrument fault ledger

| Fault | Location | Status | Commit |
|---|---|---|---|
| x-vector packing scramble (phantom triangle) | builders_util.jl | FIXED | cfd2128 |
| Expansion rotor: no induction + fixed CL (energy non-conservation) | expansion_rotor.jl | FIXED (default ON) | 234a722 |
| Blade inertia zero + mass missing n_blades | expansion_rotor.jl, ring_forces.jl | FIXED | Gate 2b |
| v11 fitness sign inverted (rewarded FoS failure) | objective_v11.jl:214,357 | FIXED | 9bd3f67 |
| Warm-start init missing orbital velocities (shock → false FoS floor) | objective_v11.jl | FIXED | 9bd3f67 |
| warmstart tuple-shift (8 returns, 7 unpacked) | objective_v11.jl | FIXED | 9029591 |
| Forward-Euler blowup on k·ω² braking (super-Betz, FoS floor) | simulation.jl / ring_forces | PARTIAL — semi-implicit at DT only | d285139 |
| **Per-step dt-independent rope damping (refinement divergence)** | initialization.jl:539 | **OPEN — leading suspect** | — |
| "settled" = endpoint drift<15% (passes designs oscillating >200 kW mid-window) | objective_v11.jl | OPEN — needs stationarity-of-windowed-stats | — |
| V10 gate axial-only FoS vs V11 combined axial+bending | objective_v10 vs ring_element_analysis | OPEN — δ̂_FoS must bridge; correction is large not small | — |

## 3. Sanity bounds (a violation = broken state, discard the sample)

- **Betz ceiling** (corrected physics): triangle ~97 kW @ 11 m/s / ~247 @ 15;
  12-gon ~62 kW @ 11 m/s. Any P above this is numerical, not aerodynamic.
  Log `P_aero` alongside `P_gen` so energy balance is checkable directly.
- **Tip speed:** ω·r_tip ≫ ~100 m/s is unphysical (30 rad/s on a 5 m rotor =
  ~900 m/s — the "get a grip" line). Kickstart ω targets must respect this.
- **FoS constant across varying k / P** = instrument floor, not structure
  (validated 3× this week). Real FoS varies with load.
- **k_best pinned to a bracket bound** = the bracket is selecting for failure or
  the optimum is outside the bracket — never accept a boundary optimum.

## 4. Canonical configuration (code intent — routines must match)

- Physics default: `EXPANSION_PHYSICS` ON. Legacy reproduction pins
  `LEGACY_PHYSICS_PRE_2026_07_18` (induction+inertia+corrected_mass all OFF).
  Every script reproducing a pre-234a722 CSV MUST pin; new work uses default.
- FoS = 1/utilisation, combined beam-column, min over airborne rings
  (`capture_extended → ring_fos`). Min-over-window aliases on limit-cycling
  systems — report windowed statistics (mean ± range) with drift checks, never
  a single snapshot.
- Credible dynamic FoS needs the full protocol (settle → kick → window), and
  now also a **converged** integrator (see §1).
- Every results CSV carries: git hash, physics-era, geometry fingerprint
  (n_lines, rings, r_hub, r_bottom, per-rotor blade count/tip/chord/area/mass).

## 5. Superseded artifacts (do not read as data)

- `scripts/results/recampaign/anchors.csv` — inverted fitness, shocked warm-start
  states, k-bracket selecting for failure. Evidence only; banner in place.
- All pre-234a722 absolute kW (kickstart/wind/catalog sweeps, headless_verify,
  dynamic_verification.txt) — pre-induction, inflated. Relative/qualitative
  findings survive; absolutes do not.
- Strathclyde-shared 117 kW figure: reproducible sim of a now-specified triangle,
  ~6× optimistic vs corrected ceiling. Follow-up drafted
  (`docs/outreach/strathclyde_followup_draft.md`).

## 6. Cross-check heuristics (Rod's, keep applying)

1. A metric uniform across conditions that should change it = broken instrument.
2. Any P > Betz anywhere in a trace = the whole trace is suspect.
3. Search existing CSVs before launching a new sweep.
4. Divergence-under-refinement = numerical; convergence-under-refinement = trust.
5. Both over-corrections are wrong: "design dead at any k" AND "just numerics,
   design fine." Fix the instrument, THEN ask what the design does.
