# V9 — Dynamic Equilibrium Objective

**Date:** 2026-06-19  
**Implemented:** 2026-06-20  
**Status:** ✅ Implemented — `objective_v6.jl` (equilibrium solve), `scripts/run_v6_campaign.jl` (V9.0 mode). V9.0 campaign complete (44.52 kg winner). Dashboard verified. See `DECISIONS.md` entry [2026-06-20]. **Superseded by V10** (`docs/plans/2026-06-20-v10-full-dynamic-constraints.md`).  
**Supersedes:** V6.x static-TSR constraint, V7 dynamic-settle plan

---

## 1. Problem Statement

The V6.x objective function (`objective_v6`) evaluates every design at an
**assumed** operating point: ω = TSR=4.1 × v_wind / r_hub_rotor.  This is the
design tip-speed ratio for a NACA 4412 airfoil — the BEM code sizes the hub
rotor so that at this ω, it produces its share of the rated power.

The assumption breaks when parasitic drag is non-zero:

```
At ω_design:  P_aero(ω) ≈ 12.6 kW    (hub rotor, Cp near peak)
              P_par(ω)  ≈ 95.0 kW    (tether + beam + blade drag, ∝ ω³)
              P_net     = −82.4 kW   (ENORMOUS air brake)
```

The system would **never reach ω_design**.  It would settle at a much lower
ω where the torque from aerodynamic lift balances the torque from parasitic
drag and generator load.  This ω_eq is what actually matters — it determines
structural loads, power output, and whether the design is physically viable.

### 1.1 Why the V6.8 constraint is a counterfactual

The current check `P_parasitic ≤ 2 × P_aero_total` (at ω_design) asks:
"Would this design work IF it could somehow spin at TSR=4.1?"

The correct question is: "Does this design produce 50 kW at any ω?"

### 1.2 Evidence from V6.8 winner

The V6.8 winner (58.4 kg, n=9, n_exp=3, 27° bank) was accepted because at
ω_design=90 rpm, P_par/P_aero ≈ 2.0 — right at the constraint boundary.
But scanning ω from 0–100 rpm reveals **P_par > P_aero at every ω**:

| ω (rpm) | P_aero (kW) | P_par (kW) | P_net (kW) |
|----------|-------------|------------|------------|
| 10 | 0.3 | 1.5 | −1.2 |
| 30 | 1.8 | 4.9 | −3.1 |
| 50 | 5.1 | 17.5 | −12.4 |
| 70 | 9.6 | 45.5 | −36.0 |
| 90 | 12.6 | 95.0 | −82.5 |

The design is an air brake at all speeds — it can never spin, let alone
produce 50 kW.  The optimizer found a design that passes a broken check.

---

## 2. Physics — The Power Balance

At equilibrium, the shaft torque balance is:

```
τ_hub_aero(ω) + τ_exp_net(ω) − τ_parasitic(ω) − τ_generator(ω) = 0
```

In power terms:

```
P_hub_aero(ω) + P_exp_net(ω) − P_parasitic(ω) − P_gen(ω) = 0
```

Where:
- **P_hub_aero(ω)** = ½ρv³πR² × Cp(λ) — BEM power curve, λ = ωR/v
- **P_exp_net(ω)** = Σ τ_exp_lift_i(ω) × ω — expansion rotor lift contribution
- **P_parasitic(ω)** = P_beam(ω) + P_tether(ω) + P_exp_drag(ω) — structural drag
- **P_gen(ω)** = k_mppt × ω³ — generator load (MPPT law)

### 2.1 Key physics insight: ω³ vs Cp(λ) scaling

- P_parasitic ∝ ω³ (monolithic cubic from drag-on-cylinder formulas)
- P_gen ∝ ω³ (MPPT control law)
- P_aero ∝ Cp(λ) which peaks at λ≈4.1 and drops to near-zero outside λ∈[0.5, 8]

At high ω, parasitic drag ALWAYS wins (cubic runaway).  At low ω, parasitic
drag is low but Cp is also low (suboptimal TSR).  There is a **window** of ω
where P_aero > P_par + P_gen — or there isn't, and the design is infeasible.

### 2.2 The equilibrium solve

For a given design, we search for ω_eq satisfying:

```
P_aero_total(ω) = P_parasitic(ω) + P_gen(ω)
```

where P_aero_total includes expansion rotor power:

```
P_aero_total(ω) = P_hub_aero(ω) + Σ P_per_rotor × (τ_exp_lift_i(ω) / τ_exp_lift_i(ω_design))
```

Algorithm:
1. **Coarse scan:** Evaluate at 20 points from ω_min to ω_max
2. **Find crossings:** Locate intervals where P_aero_total − P_par − P_gen changes sign
3. **Refine:** Bisection in each crossing interval to machine precision
4. **Select:** Choose the HIGHEST ω_eq (stable equilibrium — system accelerates
   up to it from below, decelerates down from above if it overshoots)
5. If no crossing exists → **INFEASIBLE** (design cannot spin at any ω)
6. If P_gen(ω_eq) < 50,000 W → **INFEASIBLE** (below rated power)

### 2.3 Stability

The highest crossing is the stable one.  At ω < ω_eq, P_aero > P_par + P_gen
→ system accelerates.  At ω > ω_eq, P_aero < P_par + P_gen → system
decelerates.  The highest crossing is the attractor.

---

## 3. Objective Function Design

### 3.1 Primary objective

**Minimise total airborne mass** subject to:

1. **Dynamic feasibility:** ∃ ω_eq with P_gen(ω_eq) ≥ 50,000 W
2. **Structural integrity at ω_eq:** FoS_beam ≥ 1.8, FoS_torsion ≥ 1.5
3. **Tether safety:** FoS_tether ≥ 2.0 at peak operational tension
4. **Pitch depower safety:** bank_angle ≤ 35°
5. **Ground constraint:** r_bottom ≤ 5.0 m

### 3.2 Constraint penalty (same 1e6 barrier pattern)

```julia
if ω_eq === nothing || P_gen_eq < 50000.0
    # Dynamically infeasible
    penalty = max(total_mass, 1.0) * max(50000.0 / max(P_gen_eq, 1.0), 100.0)
    return penalty + 1_000_000.0
end

# Re-evaluate structure at ω_eq (loads are ω-dependent)
eval_result = evaluate_design(design; omega_rotor=ω_eq, ...)
if !eval_result.feasible
    # Structure fails at the actual operating ω
    fos_penalty = max(1.0, 1.8 / max(eval_result.min_fos, 0.01))
    torsion_penalty = max(1.0, 1.5 / max(eval_result.min_torsional_fos, 0.01))
    penalty_mult = min(fos_penalty * torsion_penalty, 10.0)
    return eval_result.mass_total_kg * penalty_mult + 1_000_000.0
end

# Feasible: return mass
return total_mass
```

### 3.3 Scaling: P_rated as a free parameter?

The current campaigns fix P_rated = 50 kW.  With the equilibrium solve,
P_gen(ω_eq) may exceed 50 kW for low-mass designs (lighter structure → less
drag → higher ω_eq → more power).  The constraint requires P_gen ≥ 50,000.

Option: make P_rated a search parameter.  "Find the lightest design that
delivers 50 kW" vs "Find the lightest design, then report what power it
actually delivers."  The former is a constrained optimisation; the latter
is a Pareto exploration.

### 3.4 Compute cost estimate

| Path | % of evaluations | Cost per eval | Dominant operation |
|------|-----------------|---------------|--------------------|
| Fast-reject (structural FoS) | ~95% | ~1 ms | FoS check at design ω |
| Equilibrium solve | ~5% | ~10 ms | 20–50 Cp + drag evaluations |
| Full objective | ~5% | ~12 ms | Solve + re-evaluate structure |

For 600,000 evaluations: 570,000 × 1 ms + 30,000 × 12 ms = 570 + 360 = **~930 s (16 min)**
for single-threaded.  With 8 threads: **~2–3 minutes**.

Compare to V6.8: 6m 41s.  V9 would be ~2–3× faster because the fast-reject
path skips the equilibrium solve entirely for structurally-infeasible designs.

### 3.5 Expansion rotor power at equilibrium

The expansion rotor lift torque τ_exp_lift(ω) scales with ω² (lift ∝ v_app²,
and v_app includes ω·r_mean).  We approximate expansion rotor power as:

```
P_exp_i(ω) = P_per_rotor × (τ_exp_lift_i(ω) / τ_exp_lift_i(ω_design))
```

using the same `expansion_rotor_forces()` function called at the scan ω.
This gives self-consistent expansion rotor contributions at each ω.

---

## 4. Multi-Objective Outputs

Once the equilibrium solve is the gate, the optimizer naturally produces
designs with known ω_eq and P_gen.  This enables post-hoc Pareto analysis
without additional campaigns:

### 4.1 Efficiency metrics

| Metric | Formula | Meaning |
|--------|---------|---------|
| Transmission efficiency | η = P_gen / P_aero_total | Fraction of aero power surviving parasitic drag |
| Power-to-mass ratio | P_gen / m_total | kW per kg airborne mass |
| Drag fraction | P_par / P_aero_total | Parasitic overhead |

### 4.2 Pareto frontiers

From the `parameter_trace.csv` (every evaluation saved), we can extract:
- **Mass vs P_gen** — the classic engineering trade-off
- **η vs mass** — efficiency penalty of lightweight designs
- **ω_eq vs n_lines** — does polygon count drive operating speed?

### 4.3 Failure mode diagnostics

Every infeasible design gets a failure tag stored in the trace:
- `NO_EQUILIBRIUM` — P_par > P_aero at all ω (air brake)
- `POWER_TOO_LOW` — equilibrium exists but P_gen < 50 kW
- `STRUCTURAL_FAIL` — structure fails at ω_eq
- `TETHER_FAIL` — tether FoS < 2.0

Post-hoc analysis reveals which constraint is binding for each design family.

---

## 5. Implementation Plan

### 5.1 New function: `solve_equilibrium_omega()`

**File:** `src/objective_v6.jl` (in the `objective_v6` function, or as a
separate helper)

```julia
function solve_equilibrium_omega(
    design, stack, p, n_lines, radii, zs;
    P_rated=50000.0, v_wind=11.0, elev_rad=π/6,
    n_scan=20
) -> Union{Float64, Nothing}
    # Returns ω_eq or nothing if no solution
end
```

Algorithm:
1. Determine scan range: ω_min = 0.5 rad/s, ω_max = 30 rad/s (0–286 rpm)
2. Uniform scan at n_scan points
3. At each ω, compute P_net(ω) = P_aero_total(ω) − P_par(ω) − k_mppt×ω³
4. Find sign changes in P_net(ω)
5. Bisection refinement at each sign change
6. Return the highest ω with P_net ≥ 0
7. If P_net(ω_max) < 0, the design is an air brake → return nothing

### 5.2 Modify `objective_v6()`

Replace the parasitic drag constraint block (lines ~494-558) with:

```julia
# ── Dynamic equilibrium solve ──────────────────────────────────────────
ω_eq = solve_equilibrium_omega(
    design, stack, p, n_lines, radii, zs;
    P_rated=power_W, v_wind=v_rated, elev_rad=elev_angle,
)

if ω_eq === nothing
    return max(total_mass, 1.0) * 100.0 + 1_000_000.0  # air brake
end

# Re-evaluate structure at equilibrium ω
eval_result = evaluate_design(design;
    r_rotor=r_hub_rotor, elev_angle=elev_angle, v_peak=v_peak,
    fos_req=fos_req, omega_rotor=ω_eq, v_rated=v_rated,
    P_rated=power_W, max_ground_radius=max_ground_radius,
    r_eff_override=r_eff,
    F_radial_per_ring=F_radial_per_ring,
    thrust_per_ring=thrust_per_ring,
)

if !eval_result.feasible
    # Structure fails at actual operating ω
    ...
end

# Check power output
P_gen_eq = p.k_mppt * ω_eq^3
if P_gen_eq < power_W
    return max(total_mass, 1.0) * min(power_W / max(P_gen_eq, 1.0), 100.0) + 1_000_000.0
end

return total_mass
```

### 5.3 Remove ad-hoc constraint

The following code is **deleted** — replaced by the equilibrium solve:
- `P_beam, P_tether, P_exp_blades, P_parasitic = parasitic_drag_power(...)`
- `P_aero_hub = 0.5 * p.rho * v_rated^3 * π * r_hub_rotor^2 * BEM.cp_bem(...)`
- `P_aero_exp_total` loop
- `if P_parasitic > 2.0 * P_aero_total` block

The `parasitic_drag_power()` function is retained — it's called inside
`solve_equilibrium_omega()` at each scan point.

### 5.4 Campaign runner

**File:** `scripts/run_v6_campaign.jl` → renamed or updated for V9.

Changes:
- Bump `TRPT_V6_DIM` if adding new DoFs (not required for V9 — same 12-DoF)
- Add failure tags column to parameter trace
- Add P_gen, ω_eq, η columns to parameter trace
- Update output directory to `v9_campaign_50kw`

### 5.5 Dashboard

Add `--v9` flag to `scripts/interactive_dashboard.jl`, displaying:
- ω_eq from campaign (not assumed TSR=4.1 ω)
- P_gen at equilibrium
- Transmission efficiency η

### 5.6 Files changed

| File | Change |
|------|--------|
| `src/objective_v6.jl` | Add `solve_equilibrium_omega()`, rewrite constraint block |
| `scripts/run_v6_campaign.jl` | V9 header, output dir, expanded trace columns |
| `scripts/interactive_dashboard.jl` | `--v9` flag + build logic |

No changes to: `src/expansion_rotor.jl`, `src/KiteTurbineDynamics.jl`,
`src/aerodynamics.jl`, `src/ring_spacing.jl`, `src/trpt_optimization.jl`.

---

## 6. Expected Outcomes

### 6.1 First campaign (V9.0)

**Bounds widened from V6.8:** n_lines [3,12]→[3,24], n_expansion [0,10]→[0,20],
r_hub [0.60×,1.50×]→[0.30×,8.00×], blade_scale λ lower bound 0.02→0.005.

**Actual results (50 kW):**
- Best mass: 44.52 kg (n=8, n_exp=9, λ=0.40, bank=30°)
- 59/60 islands feasible — fewer than V6.8's 57/60 (the equilibrium solve is stricter)
- ω_eq ≈ 79 rpm vs design TSR=4.1 ω of ~90 rpm

**Dashboard verification:** Revealed three unmodelled failure modes (tether FoS=0.3,
overtwist > π, 7.6% slack) despite passing all objective_v6 gates. These drive
the V10 constraint expansion plan.

**Key findings:**
1. **Higher mass than V6.8 fantasy** — the equilibrium solve forces designs to
   survive at their actual operating ω, not an assumed TSR=4.1. The self-consistent
   rotor sizing (iterating ω_eq ↔ R) closes GitHub issue #4.
2. **Lower ω_eq than design ω** — equilibrium typically 10–15% below TSR=4.1 ω
   because parasitic drag ∝ ω³ pulls the operating point down.
3. **Binding constraints:** Three parameters at bounds (t_over_D=0.01, target_Lr=3.0
   max, r_bottom=0.3 min) — these are widened further in V10.
4. **n_lines=8 unanimous** — not at bound, confirmed robust under equilibrium solve.

### 6.2 Subsequent campaigns

Multi-objective analysis from the trace data:
- Scan P_rated from 10–100 kW to find the mass-vs-power Pareto frontier
- Fix mass at 60 kg, optimise for P_gen
- Fix P_gen = 50 kW, minimise parasitic drag fraction η

### 6.3 Physics validation

The equilibrium solve closes the static-vs-dynamic rotor sizing mismatch
(GitHub issue #4).  The BEM rotor sizing at TSR=4.1 is still used as an
initial estimate, but the actual operating point is solved self-consistently.
Designs are evaluated at the ω they would ACTUALLY reach, not an assumed ω.

---

## 7. Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Equilibrium solve finds no designs | Medium | Widen bounds; relax P_rated to 30 kW initially |
| Cp evaluation at extreme TSR fails | Low | BEM tables cover λ∈[0.5, 12]; clamp outside |
| Expansion rotor power scaling wrong | Medium | Validate against full dynamic simulation for a few designs |
| Campaign too slow | Low | Fast-reject path skips 95% of evaluations |
| ω_eq solver finds wrong root | Low | Verify against full ODE settle for top designs |

---

## 8. References

- GitHub issue #4: "Rotor sizing: static BEM vs dynamic equilibrium mismatch"
- `V7_CAMPAIGN_PLAN.md` — earlier dynamic-settle approach (replaced by V9
  equilibrium solve)
- Tallak Tveide, `TetherDragODESolver` — tether drag ODE validation
- Abbott & von Doenhoff, "Theory of Wing Sections" (1959) — NACA 4412 data
  for expansion blade coefficients
- `DECISIONS.md` — TRPT physics conventions and design decisions
