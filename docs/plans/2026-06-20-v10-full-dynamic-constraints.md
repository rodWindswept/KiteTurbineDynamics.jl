# V10 Campaign Plan — Unified Rotor Architecture + Full Dynamic Constraints

**Date:** 2026-06-20  
**Predecessor:** V9.0 (dynamic equilibrium objective, 44.52 kg winner)  
**Trigger:** Dashboard verification + architectural unification

## 1. Architecture Change — All Rotors Are Expansion Rotors

The hub rotor special case is removed. Ring 1's rotor is just another
expansion rotor — it can have a bank angle (0° = axial driving rotor,
>0° = tip angled down toward ring 2). This unifies the code path: no
more hub-vs-expansion distinction in force computation, power sharing,
or structural evaluation.

### 1.1 Rotor placement — 60-pattern bitmask

Rotors are placed on the top 10 rings (rings 1–10 from hub). There must
be at least 2 bare rings between any two rotors (wake clearance). This
gives 60 valid bitmasks:

```
n_rotors=0: [0 0 0 0 0 0 0 0 0 0]                    ( 1 pattern)
n_rotors=1: any single bit set                          (10 patterns)
n_rotors=2: pairs with ≥2 zeros between                 (many)
n_rotors=3: triples with ≥2 zeros between               (several)
n_rotors=4: [1 0 0 1 0 0 1 0 0 1]                      ( 1 pattern)
```

Pre-computed at module load as `const VALID_ROTOR_MASKS`. Encoded as a
continuous proxy `x_rotor_mask ∈ [0, 60)` — same pattern as `n_lines`.

### 1.2 Blade scale gradient — λ_top, λ_bottom

Replaces the single `blade_scale`. Linear interpolation from top rotor
(position 1) to lowest active rotor: λ_i = λ_top + t_i × (λ_bottom − λ_top)
where t_i ∈ [0, 1] is the normalised ring position. This lets upper rotors
carry larger blades (clean air, stronger wind) while lower rotors use
smaller blades (wake/turbulence).

### 1.3 Bank angle gradient — bank_top, bank_bottom

Replaces the single `bank_angle_deg`. Same linear interpolation. Upper
rotors can stay shallow (more axial thrust) while lower rotors steepen
(more radial spreading). Ring 1 with bank=0° is a pure axial driving rotor.

### 1.4 Rotor radius — per-rotor BEM with wind shear

Power-law wind shear: `v_i = v_ref × (z_i / h_ref)^0.14` with α=0.14
over open water. For the TRPT at 30° elevation with 21 rings over 67m
tether, altitude spread is ~33m — top ring sees ~12.5 m/s, bottom ring
~9.5 m/s (25% spread at v_ref=11 m/s).

Each rotor is sized individually: `R_i = BEM.rotor_radius_for_power(P_per_rotor, v_i, n_lines)`.
All rotors share a common shaft speed ω via `solve_equilibrium_self_consistent`.

`P_per_rotor = P_total / n_active_rotors` where `n_active_rotors = popcount(rotor_mask)`.

## 2. Design Vector — 14 DoF

| Index | Variable | Type | Bounds | What it controls |
|-------|----------|------|--------|------------------|
| x[1] | _top | continuous | [0.01, 0.25] m | Beam OD at hub |
| x[2] | t_over_D | continuous | [0.005, 0.20] | Wall thickness ratio |
| x[3] | beam_aspect | continuous | [0.15, 1.5] | Elliptical b/a |
| x[4] | Do_scale_exp | continuous | [0.1, 1.0] | Beam taper exponent |
| x[5] | r_hub | continuous | [1.07, 28.62] m | Hub ring radius |
| x[6] | r_bottom | continuous | [0.1, 5.0] m | Ground ring radius |
| x[7] | target_Lr | continuous | [0.2, 3.0] | Segment slenderness |
| x[8] | n_lines | discrete proxy | [3, 24] | Polygon sides |
| x[9] | density_profile | continuous | [−0.8, 0.8] | Ring spacing bias |
| **x[10]** | **rotor_mask** | **discrete proxy → 60** | **[0, 60)** | **Which rings get rotors** |
| **x[11]** | **bank_top** | **continuous** | **[0, 35]°** | **Bank at ring 1 (top rotor)** |
| **x[12]** | **bank_bottom** | **continuous** | **[0, 35]°** | **Bank at lowest rotor ring** |
| **x[13]** | **λ_top** | **continuous** | **[0.005, 2.0]** | **Blade scale at ring 1** |
| **x[14]** | **λ_bottom** | **continuous** | **[0.005, 2.0]** | **Blade scale at lowest rotor** |

Changes from V9.0:
- `n_expansion` → `rotor_mask` (60-pattern bitmask)
- `bank_angle_deg` → `bank_top` + `bank_bottom` (gradient)
- `blade_scale` → `λ_top` + `λ_bottom` (gradient)
- Bank bounds widened: [5, 35] → [0, 35] (ring 1 can be axial)
- t_over_D lower bound: 0.01 → 0.005 (V9.0 was screaming at 0.01)

## 3. Constraint Gates (all in objective_v10)

Eight gates, checked in order — first failure returns penalty:

| Order | Gate | Formula | Penalty |
|-------|------|---------|---------|
| 1 | Rotor mask validity | mask ∈ VALID_MASKS | +1e6 |
| 2 | Beam buckling FoS | min_FoS ≥ 1.8 | mass × clamp(1.8/FoS, 10) + 1e6 |
| 3 | Torsional FoS | min_tors_FoS ≥ 1.5 | mass × clamp(1.5/FoS, 10) + 1e6 |
| 4 | **Tether tension FoS** | T_per_line / SWL ≥ 3.0 | mass × (3.0/FoS) + 1e6 |
| 5 | **Torsional overtwist** | max_twist < 0.95π | mass × 10 + 1e6 |
| 6 | **Slack guard** | min(thrust_per_ring) > 0 | mass × 5 + 1e6 |
| 7 | Power balance | P_gen(ω_eq) ≥ P_rated | mass × (P_rated/P_gen) + 1e6 |
| 8 | Parasitic drag | P_par ≤ P_aero_total | mass × (P_par/P_aero) + 1e6 |

All eight pass → return total airborne mass (kg).

## 4. Equilibrium Solver Upgrades

### 4.1 Scan resolution: 30 → 100 points
~5 rpm spacing near 80 rpm — catches equilibrium crossings that the
coarse 30-point scan missed.

### 4.2 Lifter torque term
Add `P_lifter(ω)` to the power balance in `solve_equilibrium_omega`.

### 4.3 Unified expansion rotor forces
The equilibrium solve and structural evaluator now share the same
force computation path — no more TSR=4.1 counterfactual.

### 4.4 Per-rotor wind speeds
`solve_equilibrium_self_consistent` passes per-rotor wind speeds from
the power-law shear model to the BEM rotor sizing.

## 5. Per-Island Headless Verification

After each island's DE loop completes, run a 10s steady ODE simulation
of the winning design to compare static predictions against dynamic truth.

### 5.1 What gets measured

| Metric | Static prediction | Dynamic measurement |
|--------|------------------|-------------------|
| Rotor speed ω | ω_eq from solver | mean(ω) from ODE |
| Generator power | P_rated (50 kW) | peak P_gen |
| Tether FoS | T/SWL from static | min FoS from ODE |
| Torsional twist | <0.95π | max twist from ODE |
| Slack % | 0% (assumed) | frames with slack / total |

### 5.2 Implementation

```julia
function headless_verify(design, stack, p, n_lines, radii, zs)
    # Build system from design vector (same path as dashboard)
    sys, u0 = build_system_from_design(design, stack, p)
    
    # Settle to operational state (headless — no GLMakie)
    u_settled, _, ω_settled = settle_to_operational_state(sys, u0, p)
    
    # Run 10s simulation at steady wind
    frames, peaks = run_headless_sim(sys, u_settled, p; duration=10.0)
    
    return (
        ω_avg    = peaks.ω_mean,
        P_peak   = peaks.P_gen_max,
        FoS_min  = peaks.tether_fos_min,
        twist_max = peaks.overtwist_max,
        slack_pct = peaks.slack_fraction,
    )
end
```

### 5.3 Cost
~60 islands × ~3 seconds per ODE sim ≈ 3 minutes added to campaign runtime.

### 5.4 Output
`verification_log.csv` — one row per island, comparing static vs dynamic.
Feeds into post-campaign analysis to calibrate the static model.

## 6. Campaign Checkpoints — Incremental CSV Output

To prevent data loss during long campaigns and enable mid-run inspection,
results are written incrementally rather than only at completion.

### 6.1 What gets checkpointed

| When | What | File |
|------|------|------|
| After each island | Island's convergence rows (appended) | `convergence_history.csv` |
| After each island | Island's best vector (appended) | `island_bests.csv` |
| After each island | Island's parameter trace (appended) | `parameter_trace.csv` |
| After each island | Updated if new global best | `best_design.json` + `best_vector.csv` |
| After each verification | Static vs dynamic comparison | `verification_log.csv` |
| Every 30 iterations | Progress line (overwritten) | `campaign.log` |

All CSV appends use `flush()` after write to ensure data hits disk even if
the process is killed.

### 6.2 Mid-run inspection

While the campaign runs, the user can inspect:
```bash
tail scripts/results/v10_campaign_50kw/campaign.log      # current island
tail scripts/results/v10_campaign_50kw/convergence_history.csv  # latest masses
cat scripts/results/v10_campaign_50kw/best_design.json    # current best
```

### 6.3 Crash recovery

If the campaign crashes at island 45/60, islands 1–44 are already saved.
The campaign runner can be extended with a `--resume` flag that reads
`island_bests.csv`, seeds the remaining islands, and continues.

## 7. Search Bounds

| Parameter | Bounds | V9.0 status | Change |
|-----------|--------|-------------|--------|
| n_lines | [3, 24] | Interior at 8 | — |
| rotor_mask | [0, 60) proxy | NEW | replaces n_expansion |
| λ_top, λ_bottom | [0.005, 2.0] | Interior at 0.40 | Split into gradient |
| bank_top, bank_bottom | [0, 35]° | Interior at 30° | Lowered from 5° to 0° |
| r_hub | [1.07, 28.62] m | Interior at 2.70 | — |
| r_bottom | [0.1, 5.0] m | At min bound (80%) | Lowered from 0.3 |
| t_over_D | [0.005, 0.20] | At min bound (100%) | Lowered from 0.01 |
| target_Lr | [0.2, 3.0] | At max bound (98%) | — |
| Do_top | [0.01, 0.25] m | Interior | — |
| density_profile | [−0.8, 0.8] | Interior at −0.12 | — |
| Do_scale_exp | [0.1, 1.0] | At max bound | — |

Two previously-screaming bounds (r_bottom, t_over_D) widened to unblock.

## 8. Expected Impact

| Change | Direction | Magnitude |
|--------|-----------|-----------|
| Tether FoS constraint | ↑ mass | Large — V9.0 winner at FoS=0.3 needs ~10× improvement |
| Overtwist constraint | ↑ mass | Moderate — limits expansion rotor τ_net |
| Slack guard | ↑ mass | Small — few designs decompress rings |
| Widened bounds (r_bottom, t/D) | ↓ mass | Moderate — V9.0 was screaming against these |
| Gradient λ and bank | ↓ mass | Moderate — more expressive design space |
| Per-rotor wind model | ↓ mass | Small — top rotors get more power per kg |

**Net estimate:** V10 optimum in range **45–65 kg** (vs 44.5 kg for V9.0).
The tether FoS constraint adds mass; the bound-widening and gradients
recover some of it.

## 9. Implementation Order

1. Pre-compute `VALID_ROTOR_MASKS` (60 patterns for 10 positions, ≥2 gap)
2. Add `bank_top`, `bank_bottom`, `λ_top`, `λ_bottom` to design vector
3. Implement rotor_mask decode + per-rotor geometry with gradients
4. Add power-law wind shear to equilibrium solve
5. Add per-rotor BEM sizing at local wind speeds
6. Add tether FoS, overtwist, and slack constraints to objective
7. Increase equilibrium scan resolution to 100 points
8. Implement headless verification function (`src/headless_verify.jl`)
9. Add incremental CSV checkpointing to campaign runner
10. Clear cache + quick test (5 islands)
11. Full campaign launch (60 islands)
12. **Dashboard verification of winner** (mandatory)
13. Analysis + diagrams + verification log review

## 10. Deliverables

- `src/objective_v10.jl` — new objective with 8 gates, rotor mask, gradients
- `src/headless_verify.jl` — ODE verification without GLMakie
- `scripts/run_v10_campaign.jl` — updated runner with checkpoints
- `scripts/results/v10_campaign_50kw/` — all CSVs + verification log
- `references/v10-campaign-analysis.md` — post-campaign analysis
- `docs/awes-forum-diagrams/` — updated diagrams
- Dashboard `--v10` flag

Updates to the campaign were made before running the script to tighten the bounds and validate the island optimums with a headless run of the steady settle 10s dashboard

## 11. Implementation Notes (2026-06-20)

These are the actual implementation details that diverged from the original plan above.

### 11.1 Bounds tightened from plan

| Parameter | Planned Bound | Implemented | Rationale |
|-----------|--------------|-------------|-----------|
| `Do_top` min | 0.01 m | **0.05 m** | 1 cm beam OD is below manufacturing floor for 50 kW |
| `r_bottom` min | 0.1 m | **0.5 m** | Ring below 0.5 m can't carry 3× tether attachment geometry |
| `n_lines` max | 24 | **16** | Strip theory Cp not validated above n=12; 16 already extrapolating |
| `λ_top`, `λ_bottom` min | 0.005 | **0.05** | λ=0.005 produced microscopic blades (blade tip → 0) — optimizer gamed this to functionally disable rotors |

### 11.2 Four bugs caught and fixed pre-launch

1. **Rotor at ground ring:** Mask positions mapped 1:1 to ring indices; position 10 mapped to ground ring. Fixed by clamping positions to top half (`n_rings ÷ 2`) and converting to ring index via `n_rings - p + 1`.
2. **λ=0.005 microscopic blades:** Lower bound let optimizer set blade scale near zero, functionally removing rotors. Raised to 0.05.
3. **Duplicate `ring_spacing_v4`:** Code called the spacing function twice, using stale `zs` values in second path. Removed duplicate.
4. **Wrong `zs` index for wind:** `pos` used directly to index `zs` after already being converted to ring index. Fixed by using `zs[pos]` directly.

### 11.3 Per-island validation gates added

Six gates in `_validate_island()` halt the campaign at the first failure — see
DECISIONS.md [2026-06-20] entry for full table.  This replaces the
"run all islands then post-mortem" approach; the halt-and-resume pattern
saves ~58 islands of wasted compute when a bug is caught at island 2.

### 11.4 Per-island CSV checkpointing

After each island: `convergence_history.csv`, `island_bests.csv`,
`parameter_trace.csv`, and `verification_log.csv` are appended with `flush()`.
Global best is atomically written to `best_design.json` + `best_vector.csv`.
`--resume` flag skips completed islands by reading `island_bests.csv`.

### 11.5 First campaign result

The first V10 launch (before bounds tightening to λ_min=0.05, Do_top=0.05,
r_bottom=0.5) produced a **49.1 kg winner** with n=12, 2 rotors, and
r_bottom=2.1 m (free — not on bound).  Scaled aerodynamic coefficients:
CL=0.7, CD0=0.010, k=0.05 (NACA4412, Abbott & von Doenhoff 1959).

### 11.6 Current status

A second launch with the tightened bounds is in progress (60 islands,
80 population, 10,000 iteration cap, elliptical beam profile only).
Dashboard verification of the winner is mandatory before citing results.
