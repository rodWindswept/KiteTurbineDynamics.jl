# TRPT Soft-Ramp k_mppt Controller — v2

**Status:** Planned — Phase A ready to execute
**Date:** 2026-06-27
**Supersedes:** `docs/plans/2026-06-26-soft-ramp-kmppt.md`
**Context:** AWEC Porto 2026 — V10 Tight dashboard k_mppt hunting is manual and fragile

## Problem

The V10 Tight winner (49.2 kg, 4 rotors) can theoretically produce 50 kW at 59 rpm with
k_mppt_eff = 166 (static equilibrium). Dynamic verification shows it only reaches 12.1 kW
at 55.6 rpm with k_mppt = 62. The static solver overpredicts because it assumes instant,
lossless torque propagation through the TRPT shaft. In reality, torque propagates
sequentially through each ring pair's torsional spring-damper chain.

A too-aggressive k_mppt loads the generator before the rotor has spun up, stalling the
shaft. Too low and the rotor overspeeds. The sweet spot is narrow and drifts with wind.

## Goal

A closed-loop controller that:
1. Ramps k_mppt smoothly from a safe low value toward the rated-power target
2. Respects structural constraints (FoS ≥ 1.5 hard, soft intervention from 2.5)
3. Adapts to wind gusts and rotor speed changes
4. Finds and holds the maximum sustainable power point

## Physical Basis

### The Tulloch τ(δα) curve

From Tulloch (PhD thesis, University of Strathclyde), encoded in `scripts/torsional_collapse_check.jl`:

```
τ(δα) = n_lines × T_line × r² × sin(δα) / chord(δα)
       where chord(δα) = √(L² + 4r² sin²(δα/2))
```

The torsional stiffness k_sec = dτ/dδα is **non-monotonic**:

| Region | dτ/dδα | Physics |
|---|---|---|
| δα ≈ 0 | Low | sin(δα) ≈ δα — geometry is soft |
| Mid δα | Rising | Geometric hardening — helix engages |
| Near δα* | Peaks → 0 | Approaching max torque capacity |
| At δα* = 2·arcsin(L/√(2(L²+2r²))) | 0 | τ_cap = T_total × r² / √(L² + 2r²) |
| Past δα* | Negative | **Torsional collapse.** Lines cross, wind toward axis |

**Controller implication:** The segment nearest its δα* is the limiting one. Track
`margin_i = δα*_i − |Δα_i|` per segment. `min(margin_i)` is the constraint — not
the current k_sec value, which peaks near collapse and is misleading.

### Static-vs-dynamic power gap

The equilibrium solver finds ω_eq by balancing `P_aero = ½ρv³πR²Cp(ωR/v)` against
`P_gen = k_mppt × ω³`. It assumes the full rotor torque arrives at the generator
instantly. The multibody ODE models the TRPT as a distributed torsional spring-damper
chain — torque propagates sequentially, and the generator only "sees" rotor torque
after the torsional wave propagates. The 4.1× power gap exists because the equilibrium
solver doesn't model this dynamics.

**The PID's job is to bridge this gap by operating in the dynamic domain** — it doesn't
need to know the static prediction, only the live structural state.

## Design Decisions (2026-06-27 review)

### 1. Slack lines dropped as control signal
Polygon ring redistribution handles local slack naturally — the tension-only spring law
`T = max(0, EA·strain + c·damp·rate)` already models this correctly. 1–2 slack lines
between a ring pair is a symptom of geometry settling, not a failure trigger. Slack is
NOT used as a controller input.

### 2. k_mppt made mutable via Ref{Float64}
A `Ref{Float64}` is a single pointer dereference — one memory load per generator torque
evaluation. The ODE already uses this pattern (`sys.brake_engaged[]`). The rope force
computations (hundreds of `norm()`, `sqrt()`, spring-damper evals per step) dominate
runtime by 3–4 orders of magnitude. No measurable slowdown.

### 3. Halving k_mppt is wrong for protect
If FoS drops during a gust, halving k_mppt → generator pulls less torque → rotor
accelerates → more aero torque → more structural load. This is a positive feedback
loop toward overspeed. The correct action is to **hold or reduce ramp rate**, not
release the generator load.

### 4. FoS soft intervention at 2.5, hard floor at 1.5
A hard freeze at FoS = 1.5 creates a control discontinuity that could excite the
TRPT's torsional modes. Linear taper from FoS = 2.5 (full ramp rate) to FoS = 1.5
(zero ramp rate) gives a smooth approach to the structural limit:

```
ramp_rate = nominal_rate × clamp((FoS − 1.5) / (2.5 − 1.5), 0.0, 1.0)
```

### 5. State machine, not PID
The TRPT is a distributed nonlinear spring-damper chain. A single PID tuned at one
operating point would be suboptimal elsewhere. A state machine with proportional
ramp rate is simpler, more robust, and easier to tune manually. PID autotuning
(relay feedback, Åström-Hägglund) is a future option if the state machine proves
insufficient.

### 6. Margin to torsional collapse as the constraint metric
Rather than tracking k_sec (which peaks near collapse), track `margin_i = δα*_i − |Δα_i|`
per segment. The segment with the smallest margin is limiting. This is a direct
measure of distance to the Tulloch cliff — physically meaningful and monotonic.

## Architecture

```
  ┌──────────────┐    per-frame HUD data    ┌──────────────────────┐
  │    TRPT ODE   │───FoS, ω, P, margin────→│  Soft-Ramp Controller │
  │  (dynamics.jl)│                         │                      │
  │              │←──k_mppt_ref[] update────│  target: 50 kW        │
  └──────────────┘                         │  soft limit: FoS=2.5  │
                                           │  hard floor: FoS=1.5  │
                                           │  collapse: min(margin)│
                                           └──────────────────────┘
```

## State Machine

```
IDLE ──→ RAMPING ──→ HOLDING
  ↑                     │
  └─────(wind drop)─────┘

States:
  IDLE:     k_mppt = k_min (~20). Rotor spins up unloaded.
            Transition to RAMPING when ω > ω_min (e.g. 5 rpm for 5+ seconds).

  RAMPING:  k_mppt += Kp × (P_target − P_actual) × dt
            Ramp rate tapered by FoS: rate *= clamp((FoS − 1.5)/(2.5 − 1.5), 0, 1)
            Clamped to [k_min, k_max] where k_max is configurable.
            Transition to HOLDING when |P_target − P_actual| < ε for 3+ seconds.

  HOLDING:  k_mppt frozen at current value.
            Monitor FoS and power. If power drops >20% below target for 5+ seconds
            (sustained lull), transition back to RAMPING.

  PROTECT:  (Not a state — a rate modifier active in all states.)
            If any ring FoS < 2.5: ramp rate tapered linearly to 0 at FoS=1.5.
            If any ring FoS < 1.5: ramp rate = 0, k_mppt frozen.
            If min(margin_to_δα*) < 5°: ramp rate = 0, k_mppt frozen.
            FoS recovers above 2.5 and margin > 5° → resume normal ramp rate.
```

## Implementation Phases

### Phase A: Make k_mppt mutable (prerequisite)
**Files:** `src/types.jl`, `src/ring_forces.jl`, `src/initialization.jl`, `src/visualization.jl`

1. Add `k_mppt_ref::Ref{Float64}` to `KiteTurbineSystem` struct
2. Initialise from `p.k_mppt` in `build_kite_turbine_system()`
3. Modify `get_generator_torque()` to read `sys.k_mppt_ref[]` instead of `p.k_mppt`
4. Dashboard slider updates `sys.k_mppt_ref[]` instead of rebuilding params
5. Verify: existing tests pass, dashboard slider still works

### Phase B: State machine skeleton
**Files:** New `src/soft_ramp_controller.jl`, `src/visualization.jl`

1. Define `RampState` enum: `IDLE, RAMPING, HOLDING`
2. Define `RampController` struct holding state, k_min, k_max, Kp, P_target, FoS thresholds
3. Implement `update_ramp!(ctrl, frame_data, dt)` — the per-frame state machine
4. Wire into dashboard callback (runs at frame rate, ~40–60 Hz)
5. Dashboard: "Auto-Ramp" toggle button, state indicator label

### Phase C: Proportional ramp with FoS taper
**Files:** `src/soft_ramp_controller.jl`

1. Implement `Kp × (P_target − P_actual)` ramp rate
2. Implement FoS taper: `clamp((FoS − 1.5)/(2.5 − 1.5), 0, 1)`
3. Implement margin-to-collapse guard: `min(margin_i) < 5° → freeze`
4. Dashboard: FoS floor slider (default 1.5), soft-intervention slider (default 2.5)

### Phase D: Data recording for paper
**Files:** `scripts/record_ramp_traces.jl`, `scripts/plot_ramp_traces.py`

Record per-frame for both OLD (instant k_mppt step) and NEW (soft-ramp) systems:

| Channel | Symbol | Units | Purpose |
|---|---|---|---|
| Time | t | s | X-axis |
| k_mppt | k | N·m·s²/rad² | Control action |
| Generator power | P_gen | kW | Performance |
| Hub speed | ω_hub | rpm | Rotor state |
| Ground speed | ω_gnd | rpm | Generator state |
| Shaft slip | Δω = ω_hub − ω_gnd | rad/s | Torsional loading |
| Min ring FoS | min(FoS_i) | — | Structural margin |
| Min collapse margin | min(δα*_i − |Δα_i|) | ° | Distance to Tulloch cliff |
| Total stack twist | Σ Δα_i | ° | TRPT state |
| Peak tether tension | T_max | N | Tether loading |

**Comparison runs (both at v_rated = 11 m/s):**
- Canonical 5-line 10 kW system: instant step to k_mppt=11, vs soft-ramp
- V10 Tight 50 kW system: instant step to k_mppt=62, vs soft-ramp
- Wind ramp 7→14 m/s: both systems, to show the long TRPT spin-up time constant

**Paper figures:**
1. k_mppt(t) and P_gen(t) — old vs new, shows ramp eliminates overshoot/stall
2. FoS(t) with 2.5/1.5 intervention bands — shows the soft landing
3. margin_to_δα*(t) — novel constraint, shows approach to Tulloch cliff
4. Phase portrait: P_gen vs Δω — shows the operating trajectory
5. Table: time-to-rated-power, peak FoS excursion, min collapse margin

## Code Locations

| File | Role |
|---|---|
| `src/types.jl` | `KiteTurbineSystem` — add `k_mppt_ref` |
| `src/ring_forces.jl` | `get_generator_torque()` — read from ref |
| `src/initialization.jl` | `build_kite_turbine_system()` — initialise ref |
| `src/soft_ramp_controller.jl` | **New** — state machine, ramp logic, FoS taper |
| `src/visualization.jl` | Dashboard — Auto-Ramp button, state indicator, sliders |
| `src/dynamics.jl` | `multibody_ode!` — the plant (read-only) |
| `scripts/record_ramp_traces.jl` | **New** — headless trace recording |
| `scripts/plot_ramp_traces.py` | **New** — paper figure generation |

## Dependencies

None external. Uses existing ODE state, structural HUD data, and Makie callbacks.
Tulloch δα* computed analytically per segment from ring geometry — no additional simulation cost.

## Verification

After each phase:
- **Phase A:** `julia --project=. test/runtests.jl` — all 917 tests pass
- **Phase B:** Dashboard toggle — state indicator shows IDLE→RAMPING→HOLDING transitions
- **Phase C:** Run at rated wind — k_mppt converges to sweet spot, FoS never drops below 1.5
- **Phase D:** Generate CSV traces, produce PNG figures, confirm paper-ready quality
