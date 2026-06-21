# Dashboard Verification: V9.0 50kW Winner Failure Modes

**Date:** 2026-06-20  
**Dashboard:** `julia --project=. scripts/interactive_dashboard.jl --v9`  
**Config:** V9.0 50kW equilibrium (44.52 kg winner, n=8, n_exp=9, λ=0.40, bank=30°)

## 1. Observed Failures

The V9.0 campaign winner — which passed all `objective_v6` checks (structural
FoS, parasitic drag equilibrium, P_gen ≥ 50 kW) — **fails catastrophically** when
simulated in the dashboard under steady 11 m/s wind at 30° elevation.

| Metric | Campaign (expected) | Dashboard (actual) | Ratio |
|--------|-------------------|-------------------|-------|
| Power | ≥50 kW at ω_eq | **403.7 kW** (449 kW peak) | 8× rated |
| Rotor ω | Sustainable equilibrium | **85 rpm** (8.9 rad/s) | — |
| Tether FoS | Not checked | **0.3** (critical) | 10× below SWL |
| Peak tension | Not checked | **28,653 N** | 8.2× SWL (3,500 N) |
| Ring buckling | ≥1.8 | **65%** (marginal) | 1.54 margin |
| Torsional overtwist | Not checked | **!! RED ALERT !!** | Exceeded π |
| Slack events | Not checked | **38/500 frames (7.6%)** | — |

## 2. Three Constraint Gaps in `objective_v6`

The campaign objective checks:
- [x] Beam buckling FoS ≥ 1.8
- [x] Torsional FoS ≥ 1.5
- [x] Power balance: P_gen(ω_eq) ≥ 50 kW
- [x] Parasitic drag ≤ available aero power

**But does NOT check:**
- [ ] **Tether tension FoS** — the tethers are sized for static hub thrust at
  TSR=4.1, but dynamic forces from expansion rotors and the lifter can push
  tension 8× beyond SWL.  This is the most dangerous gap — tether failure is
  catastrophic (loss of structural integrity, potential free-flight of
  components).
- [ ] **Torsional overtwist** — inter-ring twist angle exceeding π (the
  "Tulloch limit") causes tether tangling and loss of torque transmission.
  The expansion rotor τ_net can produce enough torque at high ω to twist
  the shaft beyond safe limits.
- [ ] **Slack events** — momentary loss of tether tension destabilises the
  TRPT column.  The campaign's static force evaluation assumes all lines
  are taut; the dashboard reveals 7.6% slack frames even in steady wind.

## 3. ω Mismatch: Campaign Solver vs Dashboard Settle

The campaign's `solve_equilibrium_self_consistent()` finds a steady-state ω
where P_aero_total = P_par + P_gen.  The dashboard's `settle_to_operational_state()`
finds a **different** ω (85 rpm) where the expansion rotors inject ~350 kW of
net shaft power.

**Why they differ:**

1. **Coarse scan resolution:** `solve_equilibrium_omega` uses 30 logarithmically-spaced
   points from 1-300 rpm.  At high ω, the spacing is coarse (~20 rpm between points
   near 80 rpm).  The true equilibrium crossing might be missed if it falls between
   scan points.

2. **Different force models:** The campaign solver computes expansion rotor forces
   using `cumulative_thrust` from `peak_hub_thrust()` at the design TSR, which may
   differ from the actual ring tensions in the settled dynamic state.

3. **Lifter torque:** The campaign's equilibrium solve ignores the lifter's torque
   contribution.  The dashboard includes the rotary lifter, which can add significant
   shaft torque.

4. **k_mppt mismatch:** The campaign uses the `p.k_mppt` from `params_v5_50kw()`.
   The dashboard's `build_from_campaign` constructs new `SystemParams` which may
   have a different (or default) k_mppt.  This changes the generator load curve
   and the equilibrium ω.

## 4. Immediate Fixes Required

### For `objective_v6` (campaign gate):

```julia
# 1. Tether FoS check
T_per_line = cumulative_thrust[end] / n_lines
tether_fos = TETHER_SWL / max(T_per_line, 1.0)
if tether_fos < 3.0
    return mass * (3.0 / tether_fos) + 1_000_000.0
end

# 2. Torsional overtwist check  
# Per-ring twist must stay below 0.95π
max_twist = maximum(abs.(cumulative_twist))
if max_twist >= 0.95π
    return mass * 10.0 + 1_000_000.0
end

# 3. Slack check (harder — requires dynamic sim)
# For now: flag designs where any ring has thrust < 0 (decompression)
if any(thrust_per_ring .< 0)
    return mass * 5.0 + 1_000_000.0
end
```

### For the dashboard:

- Verify `k_mppt` matches between campaign params and `build_from_campaign`
- Increase `solve_equilibrium_omega` scan resolution from 30 to 100 points
- Add lifter torque term to `solve_equilibrium_self_consistent`

## 5. The Broader Lesson

The campaign objective is a **static structural evaluator** with a **1D power
balance check**.  It catches the dominant physics (beam buckling, parasitic drag
feasibility) but misses dynamic failure modes that only emerge when the full
ODE is run.  The dashboard is the ground truth — if the dashboard says the
design fails, the campaign objective needs another gate.

Every new constraint gap discovered through dashboard verification must be
added to `objective_v6` before the next campaign.  This is the validation
loop: campaign → dashboard → gap → constraint → re-campaign.

## 6. Impact on V9.0 Results

The V9.0 winner (44.52 kg) is **not a viable design** in its current form.
It passes the existing campaign gates but fails three unmodelled constraints.
With tether FoS, overtwist, and slack checks added, the feasible region will
shrink and the optimum mass will rise.  The 44.52 kg result remains scientifically
useful as **the best design within the modelled constraint set** — it tells us
the structural physics (beams, parasitic drag, equilibrium power) can reach
44.5 kg, but additional dynamic constraints will push that higher.

This is progress: each dashboard failure reveals a physics gap, which becomes
a new constraint, which makes the next campaign more realistic.  The V6.5
mass-only fantasy (17.7 kg) → V6.8 corrected drag (58 kg) → V9.0 equilibrium
(44.5 kg) → V10 with full dynamic constraints (TBD) is the arc of increasing
physical fidelity.
