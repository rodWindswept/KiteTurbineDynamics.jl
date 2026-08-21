# CONTEXT.md — KiteTurbineDynamics.jl

**Last updated:** 2026-08-09

## What this is

A Julia multi-body dynamics simulator for TRPT kite turbines — airborne wind energy systems harvesting power through a tensile rotary shaft. Developed by **Windswept & Interesting Ltd** for design optimisation, MPPT tuning, structural safety verification, and partner/paper communication.

The simulator sizes and stress-tests designs from **10 kW to 50 kW** via differential evolution campaigns. It feeds directly into design reports, conference papers, and engineering decisions.

---

## Core physical concept

The kite turbine is a mostly-tensile, lightweight, fast-deployable structure:

```
                    ┌─────────────────┐
                    │   LIFT KITE      │  ← Elevation support
                    │   (passive/rotary)│
                    └────────┬────────┘
                             │ lift line
                    ┌────────▼────────┐
                    │  LIFT BEARING    │  ← Swivel joint
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
    ┌────▼────┐         ┌────▼────┐         ┌────▼────┐
    │  ROTOR  │─────────│  TRPT   │─────────│ GROUND  │
    │ (blades)│  torque  │ (shaft) │  torque  │ STATION │
    │  ring   │─────────│ tethers │─────────│(gen+PTO)│
    └─────────┘         └─────────┘         └─────────┘
```

**Key components:**
- **Rotor:** Spinning ring of autogyro kite blades — generates torque from wind
- **TRPT:** Tensile Rotary Power Transmission — helical tether lines between polygon rings, transmits torque to ground via twist propagation
- **Ground station:** Generator + PTO — extracts power via `τ_gen = k_mppt · ω²`

**Critical failure mode — torsional collapse:** When applied torque exceeds geometric torsional capacity (Tulloch/Wacker criterion), the helical lines overtwist past their kinematic stability limit. Rings converge, lines cross and wind toward the axis, power transmission fails. This is geometric collapse, not material failure — and happens in seconds.

---

## Architecture: How we design

### Governing decision: Design for left-flank overspeed (2026-06-30)

The TRPT is fundamentally a **low-torque, high-speed** transmission. The P(k) curve is hump-shaped — P_rated crosses at TWO k values:

**Left flank:** low k, high ω, high thrust. The limiting factor on the left flank is torsional collapse margin — at high ω the TRPT twist accumulates faster and the system approaches the Tulloch collapse cliff. Line drag at high ω may act as a preserving torsional damper (pending assessment). FoS becomes limiting on the RIGHT flank where high generator torque reaction loads rings radially, placing ring beams in axial compression (Euler buckling).
- **Right flank:** high k, low ω, high torsion → collapse-margin-limited, dynamically unreachable

We design for the left flank: size blades so minimum power ≤ P_rated, size rings for thrust loads. Accept low k_mppt (2–20), high ω (150–300 rpm). Collapse margin is healthy (42–47°) on this flank.

### Rigid NACA 4412 beats soft kites (Ct/Cp analysis)

| Rotor | Ct/Cp | Why |
|-------|-------|-----|
| NACA 4412 (BEM) | 2.5 | Low thrust per unit power — optimal for ring sizing |
| Ram-air kite | ~8.3 | 3.3× more thrust — worse for TRPT |

Blade mass is negligible at 50 kW (thrust dominates 60:1). Rigid, high-TSR, low-solidity rotors are the left-flank optimum.

### Control-first design

Instead of "design a turbine, then hunt for a controller":
1. Sweep wind speeds 5–15 m/s for a given geometry
2. At each wind, bisection-hunt k_mppt that produces P_rated
3. Record FoS at each point
4. If min(FoS) ≥ 1.5 across all winds (hard floor) and FoS ≈ 3.0 at rated (target) → viable design + control law k(v) in one pass
5. If any point fails → geometry is infeasible, no controller can save it

**P_available(v) gate (2026-08-11):** Some wind speeds cannot physically produce P_rated. At 5 m/s, available power is only (5/11)³ ≈ 9.4% of rated. A `P_available(v)` gate implemented in `evaluate_windowed` checks `Cp × ½ρv³A ≥ P_floor × 0.8` — if the wind cannot reach the power floor, the evaluation is skipped rather than rejecting the geometry.

### Expansion rotors are co-equal generators

In AWE, smaller wings have better power-to-weight ratios and sweep tighter loops. The TRPT network of N rotors (1 hub + N-1 expansion) shares power equally — each ring's rotor is sized for P/N, not P. Never describe expansion rotors as "supplementary." They are co-equal generating rotors in a network, with a structural side-effect of spreading the rings.

---

## DE Campaigns: V6.2 → V10

All campaigns use differential evolution with collapse-reseed (≈720 random starts per campaign). Physics corrections applied at V6.2: tan→sin polygon resolution, cos³→cos²·⁶⁵ elevation exponent, coupled knuckle mass model. Pre-V6.2 results are **superseded**.

### Canonical V10 names

Two physically distinct V10 variants exist; disambiguate with these names:

| Name | Also called | Design | Spoke model | Status |
|------|-------------|--------|-------------|--------|
| **V10-DE** | V10, V10 Winner | 14-gon, 76.75 kg, hub+3 rotors, 8 gates | Centre-constraint | DE campaign winner |
| **V10-Spoke** | V10 Tight (corrected) | 12-gon, 49.2 kg, per-vertex Dyneema springs | Tension-only per-vertex | **Current work — Phase D/E active** |
| **V10-Tight (retracted)** | V10 Tight (old) | 12-gon, 49.2 kg, centre-constraint | Centre-constraint (artificially stiff) | Retracted 2026-07-13 |

The retracted V10-Tight used the centre-constraint spoke model which projected ring centres onto the shaft axis, artificially stiffening the structure and inflating FoS. **V10-Spoke** replaces this with physically correct per-vertex Dyneema spring spokes (tension-only). All Phase D/E design cards and charts use V10-Spoke.

When writing code, reports, or chart labels: use **V10-DE**, **V10-Spoke**, or **V10-Tight (retracted)**. Never use unqualified "V10" or "V10 Tight" alone.

| Version | Power | Mass | n_lines | n_exp | Key feature |
|---------|-------|------|---------|-------|-------------|
| V6.0 | 50 kW | 184.84 kg | 8 | 1 | Octagon baseline, 6/11 params on bounds |
| V6.1 | 50 kW | 179.27 kg | 8 | 1 | +tension stiffening (−3.0%) |
| V6.2 | 50 kW | 74.17 kg | 12 | 1 | sin formula, cos²·⁶⁵, coupled knuckle, dodecagon |
| V6.3 | 50 kW | 52.61 kg ⚠ | 7 | 6 | DYNAMICALLY IMPOSSIBLE — no parasitic drag model |
| V6.4 | 50 kW | 24.40 kg ⚠ | 3 | 12 | Further widened, also impossible |
| V6.6 | 50 kW | NONE feasible | — | — | Constraint too tight (hub-only Cd) |
| V6.7 | 50 kW | 54.91 kg | 9 | 14 | Relaxed drag, streamlined Cd, 53/60 feasible |
| V8.0 | 50 kW | 58.41 kg | 9 | 3 | Per-component physics, 57/60 feasible |
| V9.0 | 50 kW | 44.52 kg | 8 | 9 | Dynamic ω solve, 59/60, 3 bounds screaming |
| **V10** | **50 kW** | **76.75 kg** | **14** | **4** | **Hub+3 rotors, 8 gates, unified rotors** |
| V10 Tight | 50 kW | 49.20 kg ⚠ | 12 | 4 | DYNAMICALLY DEAD — k≈550 hits P=50 kW but FoS=0.75 |

⚠ V6.3–V6.5 and V10 Tight are dynamically impossible — the static equilibrium solver under-predicts dynamic k_mppt by ~3.3×.

**Mass reduction trend:** 259 kg (V6 baseline) → 74 kg (V6.2) → 45 kg (V9) → 77 kg (V10, robust).

---

## k_mppt Controller (Soft-Ramp)

The controller (`src/soft_ramp_controller.jl`) manages generator loading to track P_rated:

- **States:** IDLE → RAMPING → HOLDING
- **Ramp rate limited** by structural guards: FoS taper (full rate at 2.5 → zero at 1.5) and Tulloch collapse margin (full at 20° → zero at 5°)
- **dP/dk sign detection:** Accumulated-threshold method determines which flank the controller is on
- **k_min/k_max centred on slider setpoint** — searches both directions
- **Warm start:** Skips IDLE if already at operational ω after settle

---

## Dashboard

**V1 (interactive):** GLMakie 3D viewport + HUD. Launch via `scripts/interactive_dashboard.jl`. Supports V5–V10 configs, auto-ramp controller, config switching.

**V2 (cockpit refactor):** 6-row responsive grid with cockpit KPIs, bar charts (torque chain, ring health, tension chain), rotor power dials, 3D viewport. `--v2` flag. Work in progress — scenario controls not yet wired.

---

## K1 Knowledge Pipeline

**585 papers** (540 academic + 45 industry) ingested into a unified knowledge graph:
- **7,048 nodes, 9,775 edges** across 586 individual graph files
- **AWEC 2026 Porto materials:** Collaboration map, citation lineage, paper outline
- **Workspace:** `~/Documents/kites/` — extraction scripts, K1 4B model (RTX A4500 GPU)
- **All crons paused** as of 2026-06-23

---

## Domain vocabulary

| Term | Meaning |
|------|---------|
| **TRPT** | Tensile Rotary Power Transmission — helical tether shaft between polygonal spacer rings |
| **TSR (λ)** | Tip-Speed Ratio: blade-tip speed ÷ wind speed. **λ is reserved for TSR only (2026-08-20)** — the V10+ genome's blade-scale genes are named `blade_scale_top`/`blade_scale_bottom` (x13/x14), NOT λ. |
| **Cp** | Rotor power coefficient ≈ 0.22 at TSR 4.1 (BEM, NACA 4412) |
| **Ct** | Rotor thrust coefficient ≈ 0.55 at rated |
| **k_mppt** | MPPT gain: `τ_gen = k_mppt · ω²` (N·m·s²/rad²) |
| **FoS** | Factor of Safety: Euler buckling ≥ 1.8, torsional collapse ≥ 1.5 |
| **Collapse margin** | δα* − |Δα| — distance to torsional collapse cliff. Smaller = worse. Monotonic safety indicator. |
| **Force Ratio** | Tangential force / axial force at TRPT ring. Max ≈ 0.5 |
| **MTR** | Moment-to-Tension Ratio ≈ 0.05 |
| **DLF** | Design Load Factor — lumped envelope converting line tension to effective radial inward force per vertex. Computed from ODE statistics (`DLF_peak × 1.10`) in `trpt_optimization.jl`, calibrated via `scripts/calibrate_dlf.jl` on a 10 kW system across 6 load scenarios. The value 1.2 provides ~60% margin over the worst aero-only case (steady 11 m/s, DLF=0.83). Not a magic constant — recalibration needed for 50 kW and current spoke physics. |
| **Network rotor model** | N co-equal rotors sharing P/N each. Distributed per-ring loading. |
| **Windowed evaluator** | `evaluate_windowed` — the one ODE protocol for the objective family (build → start → window run → gates → score). Version objectives are adapters over it (2026-08-09). |
| **Objective config** | `ObjectiveConfig` — immutable per-eval tunables (k_mppt, relax/window horizons, V12 power-window knobs). Sweeps thread it per-eval; no module globals. |
| **Eval result** | `EvalResult` — named eval result with `status` (:ok/:reject) as the single reject channel. Never infer rejection from the fitness value. |
| **Minimal TRPT** | 1 flown bladed hub ring rotor + 1 ground ring = 2 rings. `expansion_params_from_rotors(..., minimal_hub=true)` maps it; builder geometry + A3 gate (n_rings ≥ 5) are the flagged follow-on. |

---

## Key source files

| File | Role |
|------|------|
| `src/types.jl` | `RingNode`, `RopeNode`, `KiteTurbineSystem` structs |
| `src/parameters.jl` | `SystemParams`, config factories (`params_10kw()`, `params_v5_50kw()`) |
| `src/initialization.jl` | Node builder, settle pipeline, equilibrium ω scan (includes expansion rotors) |
| `src/rope_forces.jl` | Sub-segment spring/damper; emergent torsion from geometry |
| `src/ring_forces.jl` | Rotor aero, generator torque (MPPT), expansion rotor forces, brake logic |
| `src/simulation.jl` | `run_canonical_sim!` — the canonical integrator. Always use this. |
| `src/soft_ramp_controller.jl` | RampController state machine, FoS taper, collapse margin, dP/dk detection |
| `src/objective_v6.jl` | V6 objective with network power sharing, distributed loading, +1e6 penalty barrier |
| `src/objective_v10.jl` | V10 objective — rotor masks, tension gate, slenderness gate, k_mppt λ² scaling |
| `src/objective_evaluator.jl` | **The windowed evaluator** (2026-08-09): `evaluate_windowed`, `ObjectiveConfig`, `EvalResult`, `with_k_bracket`, `build_system_from_v10` |
| `src/objective_evaluator_ramp.jl` | **Ramp-controller evaluator** (2026-08-11): `evaluate_ramp` — replaces the fixed-k bracket with a dynamically converging RampController. k_mppt is an output, not an input. |
| `src/sim_frame.jl` | `SimFrame`, `ExtendedSimFrame`, `capture_extended()` |
| `src/ring_spacing.jl` | v4/v5 ring spacing (constant L/r), `ring_spacing_v4()`, density profile |
| `src/trpt_optimization.jl` | `evaluate_design()`, structural FEA (Euler buckling + torsional collapse) |
| `src/ring_element_analysis.jl` | Per-ring space-frame FEA for buckling utilisation |
| `src/bem.jl` | BEM Cp/Ct lookup (AeroDyn, NACA 4412) |
| `src/lift_kite.jl` | Lift device models: single kite, stacked kites, rotary lifter |
| `src/structural_safety.jl` | `TETHER_SWL`, tether FoS |
| `src/economics.jl` | LCOE, carbon intensity |
| `src/visualization.jl` | GLMakie V1 dashboard |
| `src/dashboard_panels.jl` | V2 panel functions |
| `src/sim_runner.jl` | V2 `DashboardState` + `build_rerun!` |

### Key scripts

| Script | Role |
|--------|------|
| `scripts/interactive_dashboard.jl` | Launch interactive dashboard (`--v2` for cockpit) |
| `scripts/run_v10_campaign.jl` | V10 DE campaign runner (14 DoF) |
| `scripts/hunt_kmppt_bisect.jl` | Bisection-based k_mppt hunt with pre-sweep |
| `scripts/builders_util.jl` | GUI-free system builders |
| `scripts/record_ramp_traces.jl` | Headless trace recording (6 scenarios) |
| `scripts/plot_ramp_traces.py` | 7-figure publication charting suite |
| `scripts/sweep_v10_ring_detail.jl` | Per-ring FoS structural diagnostics |

---

## Known limitations

- **Static solver under-predicts dynamic k_mppt by ~3.3×.** DE campaigns use static equilibrium; dynamic verification must follow. Use `--conservative` flag (k_mppt_safety=3.0) for static campaigns.
- **Not yet fully parametric.** Node/ring/line counts derived from configurations rather than flowing entirely from `SystemParams`.
- **Elevation angle β fixed at 30°** in most campaigns. V9 freed it but others clamped it.
- **No blade pitch control.** Angle of attack is fixed. Bridling as control input not implemented.
- **Lift device has no trajectory dynamics.** Steady-state force each step via `lift_force_steady()`.
- **Static sizing only.** All campaigns size against peak static load. Cyclic fatigue, dynamic torsional loading, S-N curves not modelled.
- **Ring radial deformation not modelled.** Rings stay circular; only FoS margin is reported.
- **PCA-2 rotary lifter bug:** At elevation ≥ 90°, CL = 0 (α ≤ 0°). Physically wrong — fixed-ω rotor produces lift at any orientation.
- **CIFS symlink failures on NAS.** Claude worktree symlinks don't replicate. Expected, harmless.
- **Expansion rotor parasitic drag model** added at V6.6 — V6.3–V6.5 results are dynamically impossible artefacts of the mass-only objective.

---

## Numerical / toolchain

- **Julia 1.12.6**
- ODE: `DifferentialEquations.jl` (adaptive step, `run_canonical_sim!`)
- Optimisation: Differential Evolution (60 islands, collapse-reseed multi-start)
- Visualisation: GLMakie (V1 dashboard) + WGLMakie/Bonito (V2 cockpit)
- Structural: Analytic Euler buckling + thin-wall second moment of area + Tulloch collapse criterion
- **SI units throughout:** m, kg, Pa, rad, rad/s, N·m
- **Test suite:** see `test/runtests.jl`, run via `julia --project=. test/runtests.jl`

---

## Project room files (repo root)

| File | Purpose |
|------|---------|
| `01_source_inventory.md` | Every file: path, type, date, authority, limitations |
| `02_conflict_log.md` | 8 documented conflicts surfaced for review |
| `03_missing_context.md` | 10 identified gaps |
| `04_duplicates_report.md` | Version families (4 resolved, 5 open) |
| `PROJECT_ROOM.md` | Index + cleanup status + campaign metrics |
| `DECISIONS.md` | 2,252-line running decision log (latest: 2026-07-01) |
| `PLAN.md` | Implementation roadmap |
| `AGENTS.md` | Cross-tool agent entry point |
| `CLAUDE.md` | Developer commands + agent guide |
| `CITATION.cff` | Paper citation metadata |
| `README.md` | Project overview |

### Key subdirectories

| Directory | Contents |
|-----------|---------|
| `docs/adr/` | Architecture Decision Records |
| `docs/porto-2026/` | AWEC 2026 Porto — paper, collaboration map, citation lineage |
| `docs/plans/` | Implementation plans per campaign phase |
| `docs/reports/` | Analysis reports |
| `docs/awes-forum-diagrams/` | Diagram specs, generated PNGs |
| `handovers/` | Agent handoff documents (12+) |
| `scripts/results/` | Campaign outputs (V6.2–V10) |
| `references/` | Physics references, bug analyses, methodology docs |
| `scratch/` | 16 orphan test/debugging scripts |
| `archive/` | Superseded reports and diagrams |
| `.video/` | 4-minute explainer video project |
