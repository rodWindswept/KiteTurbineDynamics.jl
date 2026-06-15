# Triangle Rings and Biased Density: A 67% TRPT Mass Reduction at 50 kW

**Rod Read, Windswept & Interesting Ltd — June 2026**

*Submitted to the AWES Forum*

---

## Abstract

A differential evolution optimisation of the TRPT kite turbine structural design
discovered a counterintuitive optimum: **three-line (triangle) polygon rings**
outperform the eight-line octagon baseline by 67%, reducing 50 kW airborne mass
from 179 kg to 58 kg. The breakthrough came from widening three parameter bounds
that were acting as a constraint ceiling. The optimiser exploited the new
freedom to discover that (1) narrower rings with thicker beams beat wider rings
with thinner beams, (2) ring density strongly biased toward the ground anchor
reduces Euler buckling risk where compression is highest, and (3) tripling the
expansion rotor count distributes thrust across multiple rings instead of
concentrating it at one.

---

## 1. Background: The Constraint Ceiling

Our V6 optimisation campaign (May 2026) converged on a 179 kg design with 8-line
octagonal rings, 1 expansion rotor, and uniform ring spacing (target L/r = 2.0).
However, 6 of the 11 design parameters were pressed against their search bounds:

| Parameter | V6 value | Bound | At limit? |
|-----------|----------|-------|-----------|
| n_lines | 8 | [3, 8] | **MAX** |
| target_Lr | 2.0 | [0.4, 2.0] | **MAX** |
| aspect_ratio | 1.0 | [0.25, 1.0] | **MAX** |
| t_over_D | 0.02 | [0.02, 0.20] | **MIN** |
| knuckle_mass | 0.01 kg | [0.01, 0.20] | **MIN** |
| r_hub factor | 0.80× | [0.80, 1.20]× | **MIN** |

This "constraint ceiling" meant the optimiser could not explore whether fewer
lines with thicker beams, shorter ring segments, or alternative geometries might
be better. We widened the bounds for V6.2:

| Parameter | V6 bound | V6.2 bound |
|-----------|----------|------------|
| n_lines | [3, 8] | [3, **12**] |
| target_Lr | [0.4, 2.0] | [**0.2**, **3.0**] |
| aspect_ratio | [0.25, 1.0] | [**0.15**, **1.5**] |
| t_over_D | [0.02, 0.20] | [**0.01**, 0.20] |
| knuckle_mass | [0.01, 0.20] | [**0.005**, 0.20] |
| r_hub factor | [0.80, 1.20]× | [**0.60**, **1.50**]× |
| *density_profile* | *—* | **[−0.8, 0.8]** (new) |

We also added a 12th design variable, `density_profile` β, which biases ring
spacing toward the ground anchor (β > 0) or toward the hub (β < 0). The ring
radius distribution becomes r_i = r_top · (r_bottom/r_top)^(t^(1−β)) where
t ∈ [0,1] is the uniform position.

---

## 2. The Surprising Optimum

A 60-island differential evolution campaign (596,700 total iterations, ~8
minutes wall time) converged to an optimum that exploited every widened bound:

| Parameter | V6 optimum | V6.2 optimum | Change |
|-----------|-----------|-------------|--------|
| **n_lines** | 8 (octagon) | **3 (triangle)** | −62% |
| **n_expansion** | 1 | **3** | +200% |
| **density_profile** | — | **0.76** | new |
| **Do_scale_exp** | 0.64 | **0.0** | uniform beams |
| **target_Lr** | 2.0 | **3.0** | still at max |
| **t_over_D** | 0.02 | **0.01** | half thickness |
| **r_hub** | 7.20 m | **6.13 m** | −15% |
| **r_bottom** | 0.37 m | **0.30 m** | still at min |
| **Do_top** | 118.3 mm | **125.7 mm** | +6% |
| **Mass** | 179.27 kg | **58.19 kg** | **−67.6%** |

The most radical change: switching from 8-line octagonal rings to 3-line
triangular rings. At first glance this seems wrong — fewer lines mean each
beam carries more compression, requiring thicker beams. But the mass accounting
works differently than intuition suggests.

---

## 3. Why Triangle Rings Beat Octagons

### 3.1 The constant-mass theorem

For a ring carrying total polygon compression N, distributed across n lines:

- Load per beam: N_comp = N / (2 · tan(π/n))
- Required beam diameter: Do ∝ √(N_comp) (from Euler buckling: P_crit ∝ Do⁴/L²)
- Beam cross-section area: A ∝ Do² ∝ N_comp ∝ 1/tan(π/n)
- Beam mass per unit length: m_beam ∝ n · A ∝ n / tan(π/n)

For large n, tan(π/n) ≈ π/n, so m_beam ∝ n / (π/n) = n²/π → mass grows with n²!
For small n, tan(π/n) > π/n, so the scaling is worse than n².

At n=3: tan(π/3) = √3 ≈ 1.732 → n/tan = 1.73
At n=5: tan(π/5) ≈ 0.727 → n/tan = 6.88
At n=8: tan(π/8) ≈ 0.414 → n/tan = 19.3

**Beam mass at n=8 is 11× higher than at n=3 for the same ring compression.**

This is the fundamental reason the optimiser chose triangles. The mass penalty
of additional lines overwhelms the per-beam load reduction.

### 3.2 Knuckle mass

Each polygon vertex requires a knuckle joint. With the lower bound at 0.005 kg:

- n=3: 3 knuckles = 0.015 kg
- n=8: 8 knuckles = 0.040 kg

Knuckle mass alone is 2.7× higher at n=8.

### 3.3 Tether mass

The TRPT shaft uses n_lines tension members:

- n=3: 3 tethers × 67 m × 970 kg/m³ × π × (d/2)²
- n=8: 8 tethers × 67 m × 970 kg/m³ × π × (d/2)²

Tether mass scales linearly with n_lines: 8/3 = 2.67×.

---


## 4. Bottom-Biased Ring Density

The `density_profile` β = 0.76 crowds rings toward the ground anchor where
cumulative compression is highest. For the V6.2 design with 10 intermediate
rings:

| Segment | z (m) | L/r (β=0) | L/r (β=0.76) | P_crit ratio |
|---------|-------|-----------|-------------|-------------|
| 1 (bottom) | 0.0 | 3.13 | **0.79** | **15.7×** |
| 2 | 0.4 | 3.13 | **0.85** | **13.6×** |
| 3 | 0.9 | 3.13 | **0.92** | **11.6×** |
| 4 | 1.5 | 3.13 | **1.02** | **9.4×** |
| 5 | 2.4 | 3.13 | **1.13** | **7.7×** |
| 6 | 3.5 | 3.13 | **1.29** | **5.9×** |
| 7 | 5.0 | 3.13 | **1.51** | **4.3×** |
| 8 | 7.1 | 3.13 | **1.82** | **3.0×** |
| 9 | 10.1 | 3.13 | **2.35** | **1.8×** |
| 10 | 14.4 | 3.13 | **3.51** | **0.8×** |
| 11 (hub) | 20.1 | 3.13 | **15.86** | **0.04×** |

P_crit ∝ 1/L², so the bottom segment gains a factor of (3.13/0.79)² = 15.7× in
buckling resistance. This is precisely where compression is highest — the
cumulative thrust from all rotors above. The top segments carry almost no
compression (only local expansion rotor thrust) and can tolerate L/r = 15.9.

---

## 5. Expansion Rotor Multiplication

The V6.2 design uses 3 expansion rotors instead of 1. Combined with the hub
rotor, this creates a 4-rotor network where each rotor is sized for 12.5 kW
(50 kW ÷ 4). The expansion rotors are positioned at rings 9, 10, and 11
(counting from ground), placing them in the upper third of the shaft where
the ring radii are larger (2.7–4.7 m) and the blades can be longer.

Thrust distribution:

| Rotor | Ring | Radius | Power | Blade tip |
|-------|------|--------|-------|-----------|
| Hub | 12 (top) | 6.13 m | 12.5 kW | 3.69 m |
| ER 1 | 11 | 4.66 m | 12.5 kW | 7.39 m |
| ER 2 | 10 | 3.54 m | 12.5 kW | 7.39 m |
| ER 3 | 9 | 2.69 m | 12.5 kW | 7.39 m |

All expansion blades share the same mould (7.39 m tip radius, banked at 45°
toward the next ring down). This is a key manufacturability advantage — one
blade design serves all three expansion rotors.

---

## 6. Remaining Constraints

Despite the 67% mass reduction, 7 of 12 parameters remain on bounds:

| Parameter | V6.2 value | Bound | Direction |
|-----------|-----------|-------|-----------|
| target_Lr | 3.0 | [0.2, 3.0] | MAX — wants longer segments |
| r_bottom | 0.30 m | [0.30, 5.0] | MIN — wants narrower ground ring |
| Do_scale_exp | 0.0 | [0.0, 1.0] | MIN — uniform beams optimal |
| t_over_D | 0.01 | [0.01, 0.20] | MIN — wants thinner walls |
| aspect_ratio | 1.0 | [0.15, 1.5] | MAX — circular cross-section |
| knuckle_mass | 0.005 kg | [0.005, 0.20] | MIN — wants lighter knuckles |
| bank_angle | 45° | [5, 45] | MAX — wants steeper bank |

The optimiser is still fighting the constraint boundaries. Further widening of
target_Lr (beyond 3.0), t_over_D (below 0.01), and r_bottom (below 0.3 m) may
yield additional mass savings. However, manufacturability limits on wall
thickness and knuckle mass are approaching physical minima.

---

## 7. Implications for Kite Turbine Design

1. **Triangle rings are the TRPT global optimum.** The mathematics of polygon
   compression scaling (m_beam ∝ n/tan(π/n)) means fewer lines are always
   lighter for a given compression. The lower bound of n=3 (a determinate
   structural polygon) is the theoretical minimum.

2. **Ring density should be strongly biased toward the ground.** The linear
   accumulation of compression down the shaft means bottom rings need
   proportionally shorter segments. A power-law density profile (β ≈ 0.75)
   captures this physics with a single continuous parameter.

3. **More expansion rotors distribute thrust better.** Moving from 1 to 3
   expansion rotors reduced the peak ring compression by spreading the load
   across multiple rings. The optimum count may be even higher.

4. **Uniform beam diameters work.** Do_scale_exp = 0 means every ring uses
   the same 125.7 mm beam. This eliminates the manufacturing complexity of
   tapered beams and lets the density profile handle regional strength
   requirements.

5. **The constraint ceiling is real and costly.** The V6 bounds prevented the
   optimiser from discovering the triangle-ring design. Parameter bounds should
   be set by physics and manufacturability, not by assumption.

---

## 8. Method

### 8.1 Physical model

The TRPT structural model evaluates polygon-frame rings connected by tension
lines, with Euler buckling as the primary failure mode. Beam properties follow
the scaling law Do(r) = Do_top · (r/r_hub)^exp. Ring spacing uses a geometric
series in radius with a power-law density bias. Expansion rotors contribute both
thrust (axial) and radial spreading forces, with polygon hoop tension credited
as a beam stiffening effect (beam-column approximation).

### 8.2 Optimisation

Differential evolution with 12 continuous design variables, 60 islands of 80
candidates each, up to 10,000 iterations per island. Collapse detection with
aggressive reseeding (98% population replacement) prevents stagnation.
Convergence: 596,700 total iterations in 7.6 minutes (Julia 1.12, 8 threads).

### 8.3 Reproducibility

Source code and results at:
`github.com/windswept-energy/KiteTurbineDynamics.jl` (branch `v6-force-first`).
Campaign results in `scripts/results/v6_2_campaign_50kw/`.

---

*Contact: rod@windswept.energy*
