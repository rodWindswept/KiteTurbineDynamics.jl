# V7 Campaign Plan — Dynamic-Structural Co-Optimisation

## Goal
Find a TRPT design that minimises total airborne mass while satisfying:
1. Static structural FoS at peak wind (25 m/s)
2. Dynamic rated power delivery (50 kW at 11 m/s)
3. Tether safety during operation (FoS ≥ 2.0 at peak tension)
4. Pitch depower survivability (bank angle ≤ 35°)
5. Ground transport constraint (r_bottom ≤ 5.0 m)

## What V6.2 accomplished (baseline)
- 11-DoF DE campaign, 60 islands × 10,000 iterations = 600,000 evaluations
- Optimum: n=12, 9 rings, β=−0.13, n_exp=1, bank=45°, mass=74.17 kg
- 58/60 islands converged to 70–75 kg
- Static structural only — no dynamic validation

## What V6.2 did NOT do (limitations discovered)
- Blade tip radius NOT a free parameter (fixed to main BEM rotor radius)
- Bank angle bounds [0,60]° — optimum at 45°, unsafe for pitch depower
- No dynamic tether tension check
- No dynamic power rating verification
- Expansion blade count fixed to n_lines (correct, but span untuned)
- No per-iteration parameter traces saved (only mass tracked)

## V7 design vector (12-DoF, +1 from V6.2)

| Index | Name | Bounds | Type | Notes |
|-------|------|--------|------|-------|
| x[1] | Do_top | [0.01, 0.20] m | continuous | beam OD at hub |
| x[2] | t_over_D | [0.01, 0.20] | continuous | wall thickness ratio |
| x[3] | beam_aspect | [0.15, 1.5] | continuous | elliptical b/a |
| x[4] | Do_scale_exp | [0.1, 1.0] | continuous | taper exponent |
| x[5] | r_hub | [1.0, 10.0] m | continuous | hub ring radius |
| x[6] | r_bottom | [0.1, 5.0] m | continuous | ground ring radius |
| x[7] | target_Lr | [0.2, 3.0] | continuous | slenderness |
| x[8] | n_lines | [3, 12] | integer | polygon sides |
| x[9] | density_profile | [−0.8, 0.8] | continuous | β |
| x[10] | n_expansion | [0, 6] | integer | expansion rotors |
| x[11] | bank_angle_deg | [5, 35] | continuous | **NEW: capped at 35°** |
| **x[12]** | **blade_tip_radius** | **[1.0, 15.0] m** | **continuous** | **NEW: free parameter** |

## New constraints

### 1. Bank angle cap (pitch depower safety)
```
x[11] ∈ [5, 35]°  (was [0, 60]°)
```
Rationale: at bank >35°, pitch depower creates back-wind that can reverse the radial force direction, collapsing the expansion ring. The static DE optimizer cannot detect this dynamic failure mode — we enforce it as a hard bound.

### 2. Dynamic tether safety
After static sizing, run a SHORT settle-to-equilibrium simulation (~1s settled) at rated wind + gust to extract:
- Peak tether tension T_peak per line
- Tether break strength = E_modulus × π × (diameter/2)²
- Constraint: T_break / T_peak ≥ 2.0

This replaces the implicit assumption that static peak thrust covers tether sizing.

### 3. Rated power verification
- Size BEM rotor for P_rated = 50 kW at v_rated = 11 m/s (static, fast)
- Verify: P_rated ≥ 50 kW and rotor radius ≥ 5m (BEM convergence lower bound)

### 4. Expansion blade count
- n_blades = n_lines (inherited — one blade per polygon vertex)
- Blade mass per expansion station = n_lines × m_blade

### 5. Per-iteration data logging (NEW)
Save one row per evaluation to a parameter trace CSV:
```
iteration, island, n_lines, n_exp, bank_deg, blade_tip, beta, r_hub, r_bottom, Do_top, mass_kg, fos_beam, fos_torsion, tether_fos, P_rated_kw, feasible
```
This gives us the per-parameter convergence data that V6.2 lacked.

## Objective function (revised)

```julia
function objective_v7(x, beam_profile, p)
    # 1. Build design from vector (static, fast)
    design = design_from_vector_v7(x, ...)
    
    # 2. Static structural check (same as V6.2)
    #    - FoS_beam ≥ 1.8 at 25 m/s
    #    - FoS_torsion ≥ 1.5
    #    - r_bottom ≤ max_ground_radius
    
    # 3. NEW: Dynamic tether safety
    #    - Quick settle sim (~1s, ~1000 steps at dt=4e-5)
    #    - Extract T_peak per tether line
    #    - FoS_tether = T_break / T_peak
    #    - Constraint: FoS_tether ≥ 2.0
    
    # 4. NEW: Rated power check (static BEM)
    #    - Constraint: P_rated ≥ 50 kW
    
    # 5. Mass computation (same as V6.2)
    #    beam_mass + knuckle_mass + tether_mass + expansion_mass
    
    # 6. Penalty for infeasible (same structure)
    
    return total_mass
end
```

**Performance concern:** The dynamic tether check adds ~0.1s per evaluation (quick settle sim). At 600K evaluations: +60,000s = ~17 hours. Total campaign: ~24-30 hours (manageable).

**Mitigation:** Apply dynamic check only after static FoS passes. Infeasible designs skip the settle sim entirely. Most evaluations will be infeasible early on → dynamic overhead only applies to near-feasible candidates.

## Campaign configuration

```
Algorithm: Differential Evolution
Islands: 60
Population: 80 per island
Max iterations: 10,000
Total evaluations: 600,000
Estimated runtime: ~24-30 hours (single machine, 8 threads)

Output directory: scripts/results/v7_campaign_50kw/
Files:
  - best_design.json       — best found at campaign end
  - convergence_history.csv — island, iteration, mass_kg (same as V6.2)
  - parameter_trace.csv     — NEW: per-evaluation parameter + constraint values
  - v7_campaign.log         — full stdout
```

## Parameter traces (what we've been missing)

The V6.2 convergence_history.csv only tracked mass. For V7, we log per-evaluation:

```csv
iteration,island,n_lines,n_exp,bank_deg,blade_tip,beta,r_hub,r_bottom,Do_top,mass_kg,fos_beam,fos_torsion,tether_fos,P_rated_kw,feasible,elapsed_ms
```

This enables post-hoc analysis of:
- Which parameter ranges each island explored
- When the optimum was first discovered (not just final mass)
- Which constraint was usually binding
- β sweep, n_exp sweep, blade_tip sweep — all from a SINGLE campaign

## Implementation steps

### Step 1: Add blade_tip_radius to design vector
- Add to `objective_v7.jl` as x[12]
- Update `design_from_vector_v7()` to pass blade_tip_radius to expansion config
- Update bounds in `search_bounds_v7()`

### Step 2: Cap bank angle at 35°
- Update bounds: bank_angle_deg ∈ [5, 35]°

### Step 3: Add dynamic tether safety check
- After static FoS check, if feasible:
  - Build KiteTurbineSystem from design params (fast, same as dashboard does)
  - Run settle_to_operational_state() (~1s simulation)
  - Extract peak tether tension
  - Add penalty if FoS_tether < 2.0

### Step 4: Add rated power verification
- Static BEM sizing already in V6.2 (rotor_radius_for_power)
- Add constraint: P_rated ≥ 50 kW

### Step 5: Add parameter trace logging
- Append one row per evaluation to parameter_trace.csv
- Use CSV.append for incremental writes
- Flush periodically to avoid data loss

### Step 6: Run campaign
```
nohup julia --project=. scripts/run_v7_campaign.jl > v7_campaign.log 2>&1 &
```

### Step 7: Post-campaign analysis
- Extract convergence patterns (as Phase 1 of analysis plan)
- Extract per-parameter sweeps from parameter_trace.csv (as Phase 2)
- Regenerate AWES forum diagrams with real dynamic data

## Test before full run
```bash
# Quick test: 5 islands, 100 iterations, ~30s
julia --project=. scripts/run_v7_campaign.jl --quick

# Full campaign (screen/tmux recommended):
screen -S v7
julia --project=. scripts/run_v7_campaign.jl
# Ctrl+A D to detach, screen -r v7 to reconnect
```

## Technical details — dynamic settle sim

### Settle configuration
```
Wind speed: 11 m/s (rated) + gust factor 1.4 = 15.4 m/s for tension check
Duration: 1.0s simulated (enough to reach steady state)
dt: 4e-5 s (standard TRPT timestep)
Steps: 25,000
Lift device: RotaryLifterParams (3.7, 0.05, 3, 0.12, 1.0, 0.20, 40.0, 25.0, 1.5e5, 5.0)
```
The settle runs at rated wind to establish equilibrium, then a short gust
simulation extracts peak tension. Total: ~0.1s wall time per evaluation.

### Error handling
```julia
try
    sys, u0 = build_kite_turbine_system(p; expansion_rotors=stack)
    u_settled = settle_to_operational_state(sys, u0, p, 9.5; ...)
    # Extract peak tension from last 0.5s of settle
    T_peak = maximum(abs, tensions)
catch e
    # Settle sim failed → penalty (infeasible design)
    @warn "Settle failed" exception=e
    return 1e9  # large penalty
end
```

### Thread safety
- Each evaluation creates a fresh local `KiteTurbineSystem` — no shared state
- `settle_to_operational_state` is single-threaded internally
- DE islands run in separate threads — each has its own system instance
- No locking required

### Tether FoS computation
```julia
T_break = p.e_modulus * π * (p.tether_diameter / 2)^2  # N
FoS_tether = T_break / T_peak
# Penalty if FoS_tether < 2.0:
#   penalty_mult = 2.0 / max(FoS_tether, 0.01)
#   penalty_mult clamped to 10× max (same as static FoS)
```

### Rated power verification
```julia
r_rotor = BEM.rotor_radius_for_power(50000.0, 11.0, n_lines)  # BEM-sizing
# Constraint: r_rotor ≥ 5.0 m (below this, BEM extrapolation unreliable)
# If r_rotor < 5.0: apply penalty
```

### Parameter trace I/O strategy
- Open file handle at campaign start, keep open
- Append one CSV line per evaluation using `println(io, ...)` — no CSV.jl overhead
- Flush every 1000 evaluations (every ~10s at full speed)
- Close on campaign completion or interrupt
- File size: ~600K rows × ~150 chars = ~90 MB — manageable

### Fallback: static-only mode
If the dynamic settle sim proves too unstable during testing, the campaign
can run in static-only mode (skip the settle, use static tether sizing from
V6.2). The parameter trace and new design variables still provide value.
Toggle via `--static-only` flag.

## Efficiency considerations

### Fast-reject path (most evaluations)
```
1. Unpack design vector → 0 μs
2. Static FoS check → ~1 ms
3. If infeasible: penalty + return → DONE (~1 ms)
```
~95% of evaluations will fail static FoS in early iterations. Only ~5%
(~30K evaluations) will reach the expensive dynamic settle.

### Dynamic path (feasible candidates only)
```
4. Build TRPT system → ~5 ms
5. Settle simulation (25K steps) → ~80 ms
6. Extract peak tension → ~1 ms
7. Compute mass + log trace → ~2 ms
Total: ~90 ms per feasible candidate
```

### Campaign time estimate
```
Infeasible: 570K × 1 ms  = 570s  = 9.5 min
Feasible:    30K × 90 ms = 2700s = 45 min
Overhead (migration, logging):       15 min
Total: ~70 minutes (NOT 24-30 hours!)
```

**Correction from initial estimate:** The fast-reject path dominates runtime.
The dynamic settle only runs on designs that pass static FoS, which is a
small fraction. Campaign should complete in 1-2 hours, not 24-30.

### Thread utilisation
- 8 threads × 60 islands = each thread handles ~8 islands
- Island evaluations are independent → near-linear speedup
- Migration (every 100 iterations) is a synchronisation point — minimal overhead
- Expected: ~8× speedup → campaign in ~10-15 minutes wall time

### Data safety
- Convergence CSV written every 1000 evaluations (survives crash)
- Parameter trace CSV flushed with convergence CSV
- Best design JSON written at migration points
- If campaign is killed mid-run, loss is at most 999 evaluations

## Success criteria
- [ ] Campaign completes without NaN/Inf crashes
- [ ] Best design converges (mass plateau)
- [ ] FoS_beam ≥ 1.8, FoS_torsion ≥ 1.5, FoS_tether ≥ 2.0 all satisfied
- [ ] P_rated ≥ 50 kW verified
- [ ] Bank angle ≤ 35°
- [ ] Blade tip radius free and optimised
- [ ] Parameter trace CSV complete and valid
- [ ] Test suite passes (`julia --project=. test/runtests.jl`)
