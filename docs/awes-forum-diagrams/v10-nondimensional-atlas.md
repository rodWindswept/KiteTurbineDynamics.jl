V10 Campaign — Non-Dimensional Exploration Space Atlas
=======================================================

Accompanying diagram: v10-nondimensional-atlas.png
Source campaign: V10, 60 islands, 310,000 evaluations, 14-DoF DE optimisation
Best design: Island 41, 76.75 kg, 12-line dodecagon, 1 rotor, 35° bank

What this atlas shows
---------------------
A 3×3 grid of PCA landscape plots. Every panel shows the same two-dimensional
projection of the 14-dimensional design space, but coloured by a different
non-dimensional (Pi) group. The axes are the first two principal components
of the parameter covariance:

  PC1 — Structural Scale (20.0% of variance)
        Driven by hub radius, beam diameter, wall thickness, and blade scale.
        Moving right (+) means larger, heavier structure.

  PC2 — Configuration Choice (12.7% of variance)
        Driven by segment length, rotor count, and bank angle.
        Moving right (+) means more expansion-dominant configuration.

White dashed lines are iso-mass contours (80, 100, 150 kg). Yellow dots mark
the optimum region (76-78 kg). Orange spiderweb lines trace all 60 island
convergence paths through the exploration space.

The ten non-dimensional groups
------------------------------
These groups were derived from the 14 raw design variables. Each captures a
physically meaningful ratio that is independent of absolute scale.

1. Beam Slenderness  L_r / D
   Segment length divided by beam diameter. The strongest single mass driver
   (r = −0.83 with mass). Light designs use long thin beams (≈39); heavy
   designs use short thick beams (≈12). The constraint boundary sits at ~21
   — below this, parasitic drag exceeds available aerodynamic power.

2. Beam Efficiency  (t/D) × (L_r/D)
   Wall thickness ratio multiplied by slenderness. A column buckling metric.
   t/D is pinned at its 0.01 minimum across 97% of feasible designs, so this
   group is dominated by slenderness. Lighter designs have higher values.

3. TRPT Aspect Ratio  L × n / r_hub
   Total polygon perimeter (segment length × number of sides) divided by hub
   radius. Captures how "tall and many-sided" the structure is relative to
   its rotor. The optimum sits at ~11.5 — near the upper bound set by
   target_Lr = 3.0 and n_lines = 16.

4. Ring Packing  L_r / (n × D)
   How densely the polygonal rings are packed per unit beam diameter. Higher
   values mean fewer, longer segments for a given structural envelope.
   Correlates strongly with low mass (r = −0.71).

5. Lambda Gradient  λ_bot / λ_top
   Ratio of blade scale at the lowest expansion rotor to the highest. Wind
   shear means lower rings see slower wind, so some bottom-biased scaling is
   beneficial. But the optimum converges to ~4.3 — heavy designs overshoot
   to ~28, creating enormous parasitic drag.

6. Rotor Solidity  n × c / (2πR)
   Total blade chord × blade count divided by rotor circumference. A classic
   turbomachinery solidity metric. The optimum has σ ≈ 0.052 — relatively
   low solidity, consistent with a high-speed rotor.

7. Power Loading Coefficient  P_rated / (½ρ π r² V³)
   Rated power divided by the kinetic energy flux through the hub rotor
   swept area. Values above 1.0 mean the rotor must extract more power than
   the Betz limit would allow from its geometric area — possible only with
   expansion rotor contribution. The optimum is at 1.43.

8. Ring Taper  (r_hub − r_bottom) / r_hub
   Conicity of the TRPT. Zero = cylindrical. Negative = bottom ring wider
   than hub ring (inverted cone). The optimum is near-cylindrical (−0.24);
   heavy designs are strongly inverted (−0.60).

9. Expansion-to-Structural Ratio  log₁₀(expansion area / structural area)
   Orders of magnitude by which expansion rotor swept area exceeds the
   structural cross-section. The optimum sits at 2.4 (≈250×). Heavy designs
   are near parity (0.0 = 1×). This is the dimensionless expression of
   "expansion rotors dominate the power budget."

How to read the atlas
---------------------
Each panel tells a story about where in the exploration space a given Pi
group takes high or low values. For example:

  - Slenderness is highest in the bottom-left quadrant — exactly where the
    iso-mass contours show the lightest designs. This confirms that
    structural leanness is the primary path to low mass.

  - Lambda gradient shows a sharp gradient from bottom-left (low, ~4)
    to top-right (high, >25). The divergent islands that got stuck at
    80-81 kg sit in the high-gradient region — they never reduced their
    bottom-blade overshoot.

  - Ring packing and TRPT aspect ratio both peak in the optimum region,
    confirming that tightly-packed, tall, many-sided geometries are the
    winning configuration.

  - Ring taper is near-zero throughout the optimum basin — the equilibrium
    solver consistently favours cylindrical (or very slightly top-wider)
    geometries for uniform structural loading.

Key non-dimensional insights
----------------------------
1. Mass minimisation in this 14-DoF space decomposes into two near-orthogonal
   sub-problems: structural leanness (PC1) and expansion/thrust balance (PC2).
   These are only weakly coupled — you can improve mass by advancing either.

2. The constraint boundary is a single non-dimensional gate: L_r/D > 21.
   Every feasible design must clear this threshold. The optimum pushes to
   nearly 2× the threshold (39.4) because mass continues to drop with
   slenderness until the bounds are reached.

3. Lambda gradient is the "strategy switch" — it separates the optimum basin
   (λ_bot/λ_top ≈ 4) from the sub-optimum basin (≈8-15). Wind shear
   compensation is real, but the optimum only needs ~4× bottom bias, not the
   28× that heavy designs attempt.

4. Three parameters are screaming at bounds: t/D = 0.01 (min), L_r = 3.0
   (max), r_bottom = 0.5 (min). All three are structural slenderness levers.
   The true global optimum lies outside the current search bounds and is
   likely below 76 kg.

5. The expansion-to-structural ratio of ~250× at the optimum confirms that
   the TRPT architecture is fundamentally an expansion-rotor concept — the
   structural elements exist only to hold rotors in place, and the mass
   penalty for structure is paid only once while the power benefit of
   rotors scales with count.
