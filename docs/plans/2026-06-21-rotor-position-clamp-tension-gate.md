# Fix V10 rotor-position clamp and add tension-distribution gate

> **Goal:** Remove the artificial `n_rings ÷ 2` clamp that kills rotors at lower ring positions, and add a tether-tension-distribution gate to `objective_v10` that rejects designs where any tether segment goes slack at the equilibrium operating point.

**Root cause (from dashboard investigation):** The V10 winner (76.75 kg, 1 rotor at hub) produces 0 kW dynamically despite passing all 8 static constraint gates. The dashboard shows 144 slack lines, −2 rpm, and a bouncing lift kite. The single hub rotor concentrates all thrust at the top ring, pulling upper tethers slack while lower ones go tight — torque can't transmit to the generator at the ground ring.

**Why the DE couldn't find a 2+ rotor design:** `design_from_vector_v10` contains a `max_positions = n_rings ÷ 2` clamp (line 144) that throws away rotor mask positions beyond the top half of rings. For the V10 winner's 7-ring design, only position 1 (hub) survives — positions 4, 7, 10 are all killed. A 2-rotor design (hub + 3 rings down) would distribute thrust more evenly and could maintain tension, but the campaign was never allowed to try it.

**Architecture:** Two changes to `src/objective_v10.jl`:
1. Remove the `max_positions` clamp — allow all rotor positions from the bitmask through, clamped only to `1:n_rings`
2. Add a tension-distribution gate after the structural evaluation — reject designs where any tether segment has non-positive tension at ω_eq

**Tech Stack:** Julia, KiteTurbineDynamics.jl

---

### Task 1: Remove `max_positions` clamp from `design_from_vector_v10`

**Objective:** Allow rotor mask positions to map to any valid ring index (1 through n_rings), instead of restricting to the top half only.

**Files:**
- Modify: `src/objective_v10.jl:141-151`

**Step 1: Replace the clamp logic**

Current code (lines 141-151):
```julia
    # Clamp rotor positions to top half only (hub-side rings)
    # Rotor mask position 1 = hub ring. Ring indices are ground→hub.
    # Convert: mask position p → ring index = n_rings - p + 1
    max_positions = max(n_rings ÷ 2, 1)
    positions = Int[]
    for p in positions_raw
        if p <= max_positions
            ring_idx = n_rings - p + 1  # position 1 = hub ring = ring n_rings
            push!(positions, ring_idx)
        end
    end
    n_active = length(positions)
```

Replace with:
```julia
    # Map rotor mask positions to ring indices.
    # Mask position 1 = hub ring. Ring indices are ground→hub.
    # Convert: mask position p → ring index = n_rings - p + 1
    # Clamp to valid ring range [1, n_rings].
    positions = Int[]
    for p in positions_raw
        ring_idx = n_rings - p + 1
        if ring_idx >= 1 && ring_idx <= n_rings
            push!(positions, ring_idx)
        end
    end
    n_active = length(positions)
```

**Step 2: Verify**

Run a quick test that decodes mask index 59 (bits=585, positions [1,4,7,10]) with n_rings=7. Expected: positions = [7, 4, 1] (3 rotors at rings 7, 4, 1). Position 10 maps to ring −2 which is <1 → dropped.

### Task 2: Add tension-distribution gate to `objective_v10`

**Objective:** After the structural evaluation and force computation, check that every tether segment carries positive tension at ω_eq. A single slack segment means the TRPT cannot transmit torque — the design is structurally non-viable.

**Files:**
- Modify: `src/objective_v10.jl` — insert gate between current gate #6 (line 400-402) and the "Feasible: compute total mass" section (line 407)

**Where:** The `cumulative_thrust` array is already computed (line 353). Each entry `cumulative_thrust[ri]` is the accumulated axial force from ring 1 (ground) up to ring ri. The tension in each tether line above ring ri is `cumulative_thrust[ri] / n_lines`.

**Step 1: Add the gate**

After the slack guard (gate #6, line 402), insert:

```julia
    # ── Gate 6b: Tension distribution — every segment must carry load ────
    # cumulative_thrust[ri] is the force above ring ri that the tethers must bear.
    # A non-positive value means that segment has gone slack — the TRPT cannot
    # transmit torque from expansion rotors to the generator at the ground ring.
    min_tether_tension = minimum(cumulative_thrust) / n_lines
    if min_tether_tension <= 0.0
        return eval_result.mass_total_kg * max(10.0, abs(min_tether_tension) / 100.0 + 1.0) + 1_000_000.0
    end
```

**Step 2: Verify on V10 winner**

Evaluate the current V10 winner through the modified objective. Expected: the gate fires (returns >1e6) because the single hub rotor with 35° bank produces insufficient axial thrust distribution to tension the upper tether segments.

### Task 3: Clear cache, test, commit

**Step 1: Clear cache**
```bash
rm -v ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.ji ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.so
```

**Step 2: Test the V10 winner through the modified objective**
```julia
using KiteTurbineDynamics
x_raw = parse.(Float64, split(readline("scripts/results/v10_campaign_50kw/best_vector.csv"), ","))
x = copy(x_raw); x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
x[10] = clamp(x[10], 0.0, Float64(N_VALID_MASKS))
result = objective_v10(x, PROFILE_ELLIPTICAL, params_v5_50kw(); power_W=50000.0, max_ground_radius=5.0)
println("Mass: ", result < 1e6 ? "$(round(result,digits=1)) kg (feasible)" : "INFEASIBLE ($(round(result-1e6,digits=1)) penalty)")
```

**Step 3: Also test a 2-rotor design** — verify that `design_from_vector_v10` now returns 3 rotors for mask 59 with n_rings=7.

### Task 4: Commit

```bash
git add src/objective_v10.jl docs/plans/2026-06-21-rotor-position-clamp-tension-gate.md
git commit -m "fix: remove rotor-position clamp, add tether-tension-distribution gate

- Removed max_positions = n_rings/2 clamp from design_from_vector_v10.
  Rotor mask positions now map to any valid ring index 1..n_rings.
  The bitmask generator already enforces >=2-ring gaps; the clamp
  was an unnecessary restriction that prevented 2+ rotor designs
  from distributing thrust evenly along the TRPT.

- Added tension-distribution gate to objective_v10: rejects designs
  where any tether segment has non-positive tension at omega_eq.
  Catches the V10 winner's failure mode: single hub rotor
  concentrates thrust at top ring, upper tethers go slack, torque
  cannot transmit to the ground-ring generator (0 kW, 144 slack
  lines, -2 rpm observed in dashboard)."
```
