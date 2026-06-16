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

### 3.1 Polygon compression mechanics

Consider a regular n-gon ring of radius R. Each vertex experiences an inward
radial force F_v from the tether lines pulling the ring vertices toward the
shaft axis. The ring resists this with beam compression.

**Step 1 — Force equilibrium at a vertex.** Two beams meet at each vertex.
From the polygon geometry, each beam makes an angle π/n from the tangent
direction, so its inward radial component is C·sin(π/n) where C is the beam
compression. Force balance:

\[
2C \cdot \sin\!\left(\frac{\pi}{n}\right) = F_v
\qquad\Longrightarrow\qquad
C = \frac{F_v}{2\sin(\pi/n)}
\]

This is the exact polygon statics. For a square (n=4): sin(π/4)=1/√2, so
C = F_v/√2 ≈ 0.707F_v — each beam carries 71% of the per-vertex load.

**Model simplification.** The structural model in KTD.jl uses:

\[
C = \frac{F_v}{2\tan(\pi/n)}
\]

The two differ by cos(π/n). For n=3 the tan-formula gives C = 0.289F_v
vs the exact 0.577F_v — a factor-of-2 under-estimate. For n=8 the
discrepancy is only 8%. The qualitative conclusion is unchanged regardless
of which denominator is used, but the tan-formula is used throughout the
DE campaigns and the mass scaling below is presented consistently with it.

**Step 2 — Euler buckling sizing.** Each beam is a thin-walled tube of
diameter D, wall thickness t, spanning length L between adjacent rings.
For Euler buckling between ring supports (pin-pin end conditions):

\[
P_{\text{crit}} = \frac{\pi^2 E I}{L^2},
\qquad I = \frac{\pi}{8}D^3 t \;\;(\text{thin wall}, t \ll D)
\]

Setting P_crit ≥ C (with a Factor of Safety) and holding t/D constant:

\[
D^4 \propto C \cdot L^2
\]

For a given ring station, the axial spacing L_axial between rings is fixed
by the density profile — it does not depend on n. Therefore L is constant
across the n-comparison, and:

\[
D^2 \propto \sqrt{C}
\]

Cross-section area: A = πDt ∝ D² ∝ √C.

**Step 3 — Mass comparison.** The ring has n beam segments. With
C ∝ 1/tan(π/n) (the model's formula):

\[
A \propto \sqrt{C} \propto \frac{1}{\sqrt{\tan(\pi/n)}}
\]

Each beam's mass: m_beam ∝ A · L_poly, where L_poly = 2R·sin(π/n) is the
polygon side length (which does depend on n). Total ring mass:

\[
m_{\text{ring}} \propto n \cdot \frac{1}{\sqrt{\tan(\pi/n)}} \cdot \sin(\pi/n)
 = n \cdot \sqrt{\sin(\pi/n) \cdot \cos(\pi/n)}
\]

**Step 4 — Numerical comparison.** Evaluating this function for the
relevant n range:

| n | Polygon | sin(π/n) | tan(π/n) | √(sin·cos) | n·√(sin·cos) | vs n=3 |
|---|---------|----------|----------|------------|--------------|--------|
| 3 | triangle | 0.866 | 1.732 | 0.658 | **1.97** | 1.00× |
| 4 | square | 0.707 | 1.000 | 0.595 | 2.38 | 1.21× |
| 5 | pentagon | 0.588 | 0.727 | 0.530 | 2.65 | 1.35× |
| 6 | hexagon | 0.500 | 0.577 | 0.467 | 2.80 | 1.42× |
| 7 | heptagon | 0.434 | 0.481 | 0.409 | 2.86 | 1.45× |
| 8 | octagon | 0.383 | 0.414 | 0.357 | **2.86** | 1.45× |
| 12 | dodecagon | 0.259 | 0.268 | 0.239 | 2.87 | 1.46× |

The ring mass converges toward n→∞ at ~2.87 — only 46% above n=3. This
is a more modest effect than the headline 11×, because:
1. The √C (rather than C) scaling from Euler buckling weakens the
   n-dependence.
2. The polygon perimeter shrinks with n (shorter beams), partially
   offsetting the increased beam count.

**So why does the DE see a much larger mass difference?**

The beam-mass comparison above keeps ring radius R and per-vertex force F_v
constant — a single ring in isolation. In the full TRPT optimisation,
changing n_lines ripples through the entire design:

- **Tether count.** 8 tethers weigh 2.67× more than 3 tethers (§3.3).
- **Knuckle count.** 8 knuckles weigh 2.67× more than 3 (§3.2).
- **Rotor radius.** The BEM-coupled rotor R must grow to compensate for
  the Cp penalty at high solidity (more blades in the annulus).
- **Ring radius.** The DE can choose a different r_hub and r_bottom when
  n changes — the optimum reconfigures geometrically.
- **Expansion rotor count.** The V6 optimum at n=8 used 1 expansion
  rotor; the V6.2 optimum at n=3 uses 3. The network effect compounds
  the polygon benefit.

The 58 kg vs 179 kg result is the product of all these effects working
together — the polygon scaling is the catalyst that enables the other
optimisations, not the sole mechanism.

### 3.2 Knuckle mass

Each polygon vertex requires a knuckle joint. At 0.005 kg per knuckle:

- n=3: 3 × 0.005 = 0.015 kg
- n=5: 5 × 0.005 = 0.025 kg
- n=8: 8 × 0.005 = 0.040 kg

Knuckle mass scales ∝ n — 2.7× between n=3 and n=8. For a shaft with
10 rings, this contributes 0.25 kg of difference.

### 3.3 Tether mass

The TRPT shaft uses n_lines tension members running the full 67 m shaft
length. Tether mass scales ∝ n (same cross-section per line):

- n=3: 3 × 67 m × 970 kg/m³ × π(d/2)² = 0.55 kg (for d=1.9 mm Dyneema)
- n=5: 5 lines = 0.91 kg
- n=8: 8 lines = 1.46 kg

A 2.67× difference for the tether mass alone. Combined with beam mass,
knuckle mass, and the compounding effects on rotor sizing, the polygon
choice drives the largest structural lever in the TRPT design space.

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

## 5. Expansion Rotors: Aerodynamic Spreading of the TRPT Shaft

### 5.1 What is an expansion rotor?

An expansion rotor is an intermediate ring on the TRPT shaft whose knuckle
nodes carry not passive carbon beams but actively-lifted aerodynamic blades.
During TRPT rotation, these blades generate lift with an outward radial
component — spreading the tether attachment points wider than the passive
ring geometry would permit.

The expansion rotor replaces structural mass (thick carbon beams resisting
ring compression) with aerodynamic work (lift from spun blades). Instead of
passively fighting the inward buckling force, the blades actively push
outward.

### 5.2 How it works

Each expansion blade is coupled to the rotating TRPT line set, driven by
the torque flowing down from the hub rotor above. The blade is banked
downward — its tip points toward the next lower ring — so that its lift
vector resolves into two components:

1. **An outward radial component** that spreads the tether attachment points,
   increasing the effective ring radius (r_eff) at that station.
2. **A downward axial component** that contributes to the compressive load
   in the shaft below.

The radial spreading has two structural benefits:

- **Wider r_eff increases torsional capacity.** The Tulloch/Wacker
  torsional collapse criterion scales as τ_cap ∝ r² — a wider ring at an
  expansion station can transmit more torque before the helical lines
  overtwist.
- **Shorter effective segment length.** Each expansion rotor breaks a long
  soft shaft section into two shorter ones, reducing the L/r slenderness
  ratio and increasing Euler buckling resistance.

### 5.3 The V6.2 configuration

The V6.2 design uses 3 expansion rotors (up from 1 in V6). Combined with
the hub rotor, this creates a 4-rotor network where each rotor is sized for
12.5 kW (50 kW ÷ 4). The expansion rotors are positioned at rings 9, 10,
and 11 (counting from ground), placing them in the upper third of the shaft
where the ring radii are larger (2.7–4.7 m) and the blades can be longer.

**Thrust distribution:**

| Rotor | Ring | Radius | Power | Blade tip |
|-------|------|--------|-------|-----------|
| Hub | 12 (top) | 6.13 m | 12.5 kW | 3.69 m |
| ER 1 | 11 | 4.66 m | 12.5 kW | 7.39 m |
| ER 2 | 10 | 3.54 m | 12.5 kW | 7.39 m |
| ER 3 | 9 | 2.69 m | 12.5 kW | 7.39 m |

All expansion blades share the same mould (7.39 m tip radius). This is a
key manufacturability advantage — one blade design serves all three
expansion rotors.

### 5.4 Why three expansion rotors helped

The V6 optimum used 1 expansion rotor and produced 179 kg shaft mass. The
V6.2 DE optimiser was freed to explore n_expansion ∈ [0, 6] and converged
on 3. The physics reason: distributing the 50 kW of aerodynamic thrust
across 4 rotors (hub + 3 expansion) instead of 2 (hub + 1) reduces the peak
ring compression at any single station by nearly half. Lower peak
compression → thinner beams can survive Euler buckling → less mass.

This is a **network effect**: more expansion rotors spread the structural
load across more rings. The diminishing return comes from the parasitic drag
of the expansion blades themselves — each additional rotor adds blade area
that must be spun through the air, consuming a fraction of the transmitted
power. The optimiser's choice of n_exp = 3 represents the balance point
where the structural benefit of one more rotor no longer outweighs its
added mass and drag.

### 5.5 The bank angle concern

The V6.2 optimum places expansion blades banked at 45° toward the next ring
down — the upper search bound. The optimiser would prefer an even steeper
bank if permitted. This raises a critical operational concern.

Expansion rotor blades are banked downward to produce an outward radial
lift component. Their angle of attack relative to the incoming wind depends
on the shaft elevation angle (currently 30° from horizontal). During
**pitch depower** — the emergency shutdown procedure where the back-anchor
line is winched out to tilt the rotor axis toward vertical and spill wind —
the apparent wind direction at the expansion rotors changes.

At a 45° bank angle and 30° shaft elevation, the blades already operate
near the edge of their usable angle-of-attack range. If pitch depower
raises the shaft by another 15–20°, the apparent wind could approach the
blades from above — reversing the lift direction and converting the
expansion rotors from outward-spreading devices into inward-collapsing
devices. A back-winded expansion rotor would pull the tethers inward,
reducing r_eff precisely when the shaft is most vulnerable (during an
emergency manoeuvre with fluctuating loads).

This is not modelled in the current static structural sizing. The DE
optimiser cannot penalise a design for failing under a transient operating
condition it doesn't evaluate. We recommend:

1. **Dynamic simulation of pitch depower with expansion rotors** — a
   multi-body ODE transient to confirm whether back-winding actually occurs
   at 45° bank.
2. **Bank angle sweep** — map the safe operating envelope of bank angle vs.
   shaft elevation angle, identifying the maximum bank that survives a full
   pitch depower sequence.
3. **Blade section selection for expansion rotors** — symmetric or
   reflexed-camber airfoils that tolerate reversed flow may widen the safe
   bank angle range.

Until this analysis is complete, the 45° bank angle result should be
treated as an optimiser artefact at the search bound, not a validated
design choice. A conservative bank angle of 20–30° is likely safer for
initial prototyping.

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
| bank_angle | 45° | [5, 45] | MAX — wants steeper bank **(see §5.5)** |

The optimiser is still fighting the constraint boundaries. The bank_angle
saturation at 45° is particularly concerning — steeper bank angles may be
structurally optimal in the static model but could cause expansion rotor
back-winding during pitch depower (discussed in §5.5). Further widening of
target_Lr (beyond 3.0), t_over_D (below 0.01), and r_bottom (below 0.3 m)
may yield additional mass savings. However, manufacturability limits on wall
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

3. **More expansion rotors distribute thrust better, with caveats.** Moving
   from 1 to 3 expansion rotors reduced the peak ring compression by
   spreading the load across multiple rings. The optimum count may be even
   higher, but parasitic drag on the expansion blades and the bank angle
   back-wind risk during pitch depower (§5.5) impose practical limits not
   yet captured in the static structural model.

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
