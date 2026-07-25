# Genome Glossary — V10/V11 DE design vector

**Purpose:** Single source of truth for what each genome variable controls.
The mechanical columns (bounds, clamp sites, decoder) are generated from source
at `search_bounds_v11` / `design_from_vector_v10` / `design_from_vector_v4`.
The physical-meaning and gaming-risk columns are maintained by humans — these
are the parts code cannot state. If a session disagrees with this file, the
file wins until a commit corrects it.

**Last regenerated:** 2026-07-25, from `search_bounds_v4` + `search_bounds_v10`
+ `search_bounds_v11` + decoder clamp sites. Asserted by test: bounds and clamp
sites here must match the code.

---

## Variables 1–9: V4/V5 base genome (geometry)

| # | Name | Low | High | Clamp | Decoder | Physical meaning | Gaming risk |
|---|------|-----|------|-------|---------|------------------|-------------|
| x1 | Do_top (m) | 0.20 | 0.440 | — | `design_from_vector_v4` | Beam tube outer diameter at hub ring. Dominant FoS lever: I ∝ Do⁴. | DE reduces Do to save mass; FoS floor catches it at scoring |
| x2 | t_over_D | 0.01 | 0.15 | — | `design_from_vector_v4` | Wall thickness ratio. At 0.15 tube is near-solid rod. Secondary FoS lever. | DE pushes toward min; ~32% I gain from 0.15→solid not worth the mass |
| x3 | aspect_ratio | 1.0 | 1.0 | — | `design_from_vector_v4` | Beam cross-section ellipticity. Fixed at 1.0 (circular) per Rod 2026-07-24. | Not gamed — clamped to single value |
| x4 | Do_scale_exp | 0.0 | 1.0 | — | `design_from_vector_v4` | Tube diameter taper rate from hub toward ground. 0 = uniform Do along shaft; 1 = ground-ring Do → 0. Ground ring is excluded from FoS (ground-supported, `sim_frame.jl:167`) but its mass still counts in airborne mass (`expansion_analysis.jl:43`: `n_rings × m_ring` includes it). | DE benefits from tapering (saves mass that counts in objective). Zero taper = heavier intermediate rings = higher airborne mass. |
| x5 | r_hub (m) | 1.50× ref | 8.00× ref | — | `design_from_vector_v4` | Hub ring radius. Sets swept area (power) and bending moment arm. | Larger = more power, more bending. Classic trade-off |
| x6 | r_bottom (m) | 1.5 | 8.0 | `clamp(x[6], 0.1, max_ground_radius)` | `design_from_vector_v4` | Ground ring radius. Must be ≤ r_hub (enforced by decoder at `ring_spacing.jl:412`). | Gaming: r_bot ≪ r_hub → extreme taper → unloaded lower rings, fake FoS at unloaded stations |
| x7 | target_Lr | 0.2 | 3.0 | — | `design_from_vector_v4` | Target ring spacing ratio L/r. High values → fewer rings → lighter shaft. | **CONFIRMED EXPLOIT.** DE maximises Lr → n_rings→3 → massive inter-ring spacing → Tulloch/geometric model breakdown. | 
| x8 | n_lines | 3 | 16 (V10 cap) | `clamp(round(Int, x[8]), 3, 12)` in v4 decoder | `design_from_vector_v4` | Polygon vertex count = blade count. | More lines = more torque capacity but more structural mass |
| x9 | density_profile | −0.8 | 0.8 | — | `design_from_vector_v4` | Ring density bias along shaft. Negative = rings clustered toward ground. | DE biases toward ground cluster to concentrate mass low |

## Variables 10–14: V10 expansion-rotor genome

| # | Name | Low | High | Clamp | Decoder | Physical meaning | Gaming risk |
|---|------|-----|------|-------|---------|------------------|-------------|
| x10 | rotor_mask | 0.0 | 60.0 | `clamp(round(Int, x), 0, N_VALID_MASKS-1)` | `decode_rotor_mask` → 60 valid bitmask patterns | Expansion rotor station placement. Each set bit = one ring station carrying a full complement of n_lines blades. **n_active = count of set bits.** | **CONFIRMED EXPLOIT.** DE selects n_active=1 → all 50 kW concentrated at one station. Lower total structural loading from fewer stations. |
| x11 | bank_top (°) | 0.0 | 25.0 | `clamp(x[11], 0, 25)` | `design_from_vector_v10` | Topmost expansion rotor bank angle. | Not yet observed gaming |
| x12 | bank_bottom (°) | 0.0 | 25.0 | `clamp(x[12], 0, 25)` | `design_from_vector_v10` | Bottommost expansion rotor bank angle. | Not yet observed gaming |
| x13 | λ_top | 0.1 | 2.0 | `clamp(x[13], 0.1, 2.0)` | `design_from_vector_v10` | Blade linear scale at top station. λ=1.0 = reference blade. Area scales as λ². | DE can minimise λ to unload structure |
| x14 | λ_bottom | 0.1 | 2.0 | `clamp(x[14], 0.1, 2.0)` | `design_from_vector_v10` | Blade linear scale at bottom station. Interpolated linearly between stations. | Same as λ_top |

## Variable 15: V11 genome extension

| # | Name | Low | High | Clamp | Decoder | Physical meaning | Gaming risk |
|---|------|-----|------|-------|---------|------------------|-------------|
| x15 | log₁₀(k_mppt) | −2.0 | 3.0 | — | `k_mppt = 10^x[15]`; applied as `sys.k_mppt_ref[] = k_mppt` | Generator load coefficient. τ = k·ω². log encoding gives uniform exploration across orders of magnitude. | **CONFIRMED EXPLOIT.** DE selects k→1000 (upper bound) → transient spin-down power clears P_floor before structure collapses. Stationarity gate now catches this. |

---

## Genome-to-system pipeline

```
x[1:9]  → design_from_vector_v4()  → TRPTDesignV4 (geometry: radii, rings, tethers)
x[10]   → decode_rotor_mask()      → bitmask → expansion rotor station positions
                                         n_active = count of set bits
                                         P_per_rotor = 50 kW / n_active
x[11:14] → design_from_vector_v10() → bank angles + blade scales per station
x[15]   → 10^x[15]                 → k_mppt applied directly, no λ² scaling
```

The v4 decoder (`ring_spacing.jl:403`) is the single authority for x[1:9].
The v10 decoder (`objective_v10.jl:122`) wraps the v4 decoder and adds x[10:14].
The v11 objective (`objective_v11.jl`) adds x[15] and the windowed ODE protocol.
