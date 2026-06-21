# V10 Tight Campaign — Non-Dimensional Atlas: Panel-by-Panel Explainer

Accompanying diagram: `v10-tight-nondim.png`
Campaign: 12 islands × 1500 iterations, tight bounds, k_mppt ∝ λ² scaling
Winner: Island 1, 49.20 kg, 4 rotors, λ=0.519, r_hub=2.89m, ω=59 rpm

---

## How to Read the Atlas

Each of the 9 panels shows the same PCA projection of the 14-dimensional
design space, but coloured by a different non-dimensional (Pi) group.  The
first two principal components from the tight campaign capture 49.3% of the
total variance — significantly more than the V10v1 campaign (32.7%),
reflecting the concentrated search within tight bounds.

- **PC1 (28.9% var):** Structural scale — r_hub, Do_top, n_lines dominate.
  Moving right (+) means larger structure, more lines, thicker beams.

- **PC2 (20.4% var):** Configuration choice — λ gradient, bank gradient,
  rotor mask selection.  Moving up (+) means expansion-dominant.

White dashed lines are iso-mass contours (50, 65 kg).  The yellow diamond
marks the 49.2 kg winner.

---

## Panel 1: Beam Slenderness — L_r / D

**What it measures:** Segment length divided by beam outer diameter.  The
fundamental structural leanness metric.  Higher = longer, thinner beams
with fewer rings and less knuckle mass.  Lower = short, thick beams.

**V10v1 value:** 39.1 at the 76.75 kg optimum.
**Tight campaign value:** ~50 at the 49.2 kg winner.

**Physical interpretation:** The winner pushes slenderness to ~50 — beams
are 0.06m diameter (the *minimum allowed* in the tight bounds, screaming at
the Do_top=0.06 floor) with 3.0m segments (the *maximum allowed* target_Lr).
This is the structural boundary of the tight envelope: the DE cannot make
beams thinner or segments longer, so it compensates with a multi-rotor
configuration and compact hub radius.

**Trend:** Slenderness peaks in the low-mass region (bottom-left quadrant),
confirming structural leanness as the primary path to low mass — same
pattern as V10v1, but shifted to more extreme values.

---

## Panel 2: Beam Efficiency — (t/D) × (L_r/D)

**What it measures:** Wall thickness ratio multiplied by slenderness.
A column buckling efficiency metric.  t/D = 0.01 is pinned at the minimum
across all feasible designs (97% in V10v1, 100% in the tight campaign),
so this group is dominated by slenderness.

**Tight campaign value:** ~0.50 (0.01 × 50).

**Physical interpretation:** The beam wall is as thin as allowed.  The
beam efficiency is entirely slenderness-driven — there is no wall-thickness
headroom to exploit.  This is a structural floor: thinner walls would
violate manufacturing minimums and Euler buckling constraints.  The DE
cannot reduce beam mass further through wall thinning; it must find mass
savings elsewhere (multi-rotor thrust distribution, compact hub).

**Difference from V10v1:** V10v1 efficiency was 0.39 (slenderness 39 ×
t/D 0.01).  The tight campaign's higher efficiency (0.50) comes entirely
from the longer segments (target_Lr=3.0 vs V10v1's 2.95).

---

## Panel 3: TRPT Aspect Ratio — L × n / r_hub

**What it measures:** Total polygon perimeter (segment length × number of
sides) divided by hub radius.  Captures how "tall and many-sided" the
structure is relative to its rotor hub.  Higher = more structural load
distributed across more tether lines per unit hub radius.

**V10v1 value:** ~11.5 at r_hub=3.70m, n=12, L_r=2.95.
**Tight campaign value:** ~13.5 at r_hub=2.89m, n=13, L_r=3.0.

**Physical interpretation:** The winner achieves a 17% higher aspect ratio
than V10v1.  The hub radius has shrunk from 3.70m to 2.89m (22% reduction)
while n_lines increased from 12 to 13 and L_r increased from 2.95 to 3.0.
The compact hub concentrates structural mass, and the higher polygon count
distributes tether tension across more lines to compensate.

**Trend:** TRPT aspect peaks in the low-mass region, same as V10v1.
The multi-rotor design enables a smaller hub because thrust is distributed
across rings — the hub doesn't need to be as large to house the rotor.

---

## Panel 4: Ring Packing — L_r / (n × D)

**What it measures:** How densely rings are packed per unit beam diameter
and polygon count.  Higher = more efficient use of structural material
per ring.

**V10v1 value:** ~2.7 at n=12, D=0.075, L_r=2.95.
**Tight campaign value:** ~3.8 at n=13, D=0.06, L_r=3.0.

**Physical interpretation:** Ring packing is 41% higher than V10v1,
driven by the thinner beams (0.06m vs 0.075m) and longer segments (3.0m
vs 2.95m).  The structure is materially more efficient per ring — each
ring spans a longer segment with less beam material.

**Trend:** Peaks in the optimum region, consistent with V10v1.  Higher
packing density correlates directly with lower mass.

---

## Panel 5: Power Loading Coefficient — P / (½ρ π r_hub² V³)

**What it measures:** Rated power divided by the kinetic energy flux
through the hub rotor's geometric swept area.  Values above 1.0 mean the
rotor must extract more power than the Betz limit would allow from its
geometric area alone — requiring expansion rotor contribution.

**V10v1 value:** 1.43 at r_hub=3.70m.
**Tight campaign value:** ~2.4 at r_hub=2.89m.

**Physical interpretation:** The power loading has nearly doubled.  With
a 22% smaller hub radius, the geometric swept area is 50% smaller
(π×2.89² vs π×3.70²).  The same 50 kW must be extracted from half the
area — requiring significant expansion rotor power contribution.  This is
enabled by the 4-rotor configuration, where the hub rotor shares power
generation with expansion rotors on lower rings.

**Trend:** Power loading increases sharply in the low-mass region — the
DE discovers that a smaller hub with multi-rotor power sharing is lighter
than a large hub with a single rotor.

---

## Panel 6: Ring Taper — (r_hub − r_bottom) / r_hub

**What it measures:** Conicity of the TRPT.  0 = cylindrical (r_hub =
r_bottom).  Positive = hub wider than ground (normal taper).  Negative =
ground wider than hub (inverted cone).

**V10v1 value:** −0.24 (slightly inverted).
**Tight campaign value:** ~0.31 (normal taper, hub wider than ground).

**Physical interpretation:** The tight campaign winner has a *normal*
taper — the hub at 2.89m is wider than the ground ring at 2.00m (r_bottom
screaming at its 2.0m minimum).  This is a fundamental geometric shift
from V10v1's near-cylindrical design.  The tapered shape concentrates
structural mass near the hub where the rotor thrust is highest, while
the ground ring is as narrow as the bounds allow.

**Why it changed:** The multi-rotor design distributes thrust across rings,
so the ground ring doesn't need to be as wide to carry accumulated tension.
The r_bottom at 2.0m (minimum allowed) is screaming for a lower bound.

---

## Panel 7: Rotor Solidity — n_blades × c / (2πR)

**What it measures:** Total blade chord area divided by rotor circumference.
A classic turbomachinery solidity metric.  Higher = more blade area per
unit of rotor disc, higher torque capacity.

**V10v1 value:** ~0.052 (very low solidity).
**Tight campaign value:** ~0.15 (3× higher).

**Physical interpretation:** The blade solidity has tripled from V10v1.
At λ=0.519 (vs V10v1's λ=0.234), the blades are more than twice as large,
with correspondingly larger chord.  The higher solidity provides the torque
needed to overcome the scaled k_mppt=166 generator load.  This is the
direct consequence of the k_mppt λ² scaling: the DE can no longer cheat
with microscopic blades because they produce negligible power at the
scaled generator load.

**Trend:** Solidity increases in the low-mass region — higher blade area
is required to produce rated power at the correctly-scaled k_mppt.

---

## Panel 8: Expansion-to-Structural Ratio — log₁₀(Σ rotor area / Σ beam area)

**What it measures:** Orders of magnitude by which the total expansion
rotor swept area exceeds the total structural beam cross-sectional area.
Higher = rotors dominate the structure.

**V10v1 value:** ~2.4 (≈250×).
**Tight campaign value:** ~1.5 (≈32×).

**Physical interpretation:** The expansion-to-structural ratio has
*decreased* from V10v1 — from 250× to 32×.  This seems counterintuitive
given the 4-rotor design, but is explained by the compact hub: the
rotor swept area scales with r_hub² × λ², and r_hub dropped 22% while
λ doubled.  The net rotor area is similar to V10v1, but the structural
beam area is *higher* per unit of rotor area because the smaller hub
requires denser ring packing.

**Trend:** The expansion/structural ratio is lower in the optimum region
than in V10v1 — the tight campaign trades some expansion dominance for
structural compactness.

---

## Panel 9: Mass — kg (reference panel)

**What it measures:** The objective function output (total airborne mass
× power-accuracy penalty).  This is the reference panel — it shows the
same PCA landscape as all other panels, coloured by the optimisation
target itself.

**Tight campaign optimum:** 49.20 kg at Island 1.
**V10v1 optimum:** 76.75 kg at Island 41.

**Physical interpretation:** The 36% mass reduction is the combined effect
of all fixes: ring-mapping correction (rotor on correct ring), k_mppt λ²
scaling (no λ→0 cheat), hub-rotor mask filter (19 vs 60 masks), and tight
bounds eliminating degenerate regions.  The mass minimum sits at the
intersection of high slenderness, high TRPT aspect, moderate solidity, and
normal ring taper — a physically different basin from the V10v1 optimum.

---

## Cross-Panel Synthesis

The tight campaign winner represents a fundamentally different design
philosophy from V10v1:

| Aspect | V10v1 | V10 Tight | Driver |
|--------|-------|-----------|--------|
| Mass | 76.75 kg | 49.20 kg | All fixes combined |
| Architecture | 1 rotor, large hub | 4 rotors, compact hub | k_mppt scaling + multi-rotor |
| Slenderness | 39 | 50 | Do_top at min, L_r at max |
| TRPT Aspect | 11.5 | 13.5 | Smaller hub, more lines |
| Power Loading | 1.4 | 2.4 | Compact hub needs expansion power |
| Ring Taper | −0.24 (inverted) | +0.31 (normal) | Multi-rotor thrust distribution |
| Solidity | 0.05 | 0.15 | k_mppt scaling forces larger blades |
| Exp/Struct | 250× | 32× | Compact structure vs expansion |

Five parameters are screaming at the tight bounds: Do_top (0.06m min),
t_over_D (0.01 min), target_Lr (3.0 max), r_bottom (2.0m min), and
λ_bottom (0.10 min).  The true global optimum lies outside the current
tight envelope — widening these bounds would likely find designs below
49 kg.
