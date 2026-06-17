# Corrected TRPT Mass at 50 kW: 74 kg — and What We Learned by Finding Our Own Errors

**Rod Read, Windswept & Interesting Ltd — June 2026**

*Posted to the AWES Forum*

---

Recent preliminary results showed a 67% mass reduction from
triangle-ring TRPT geometry. During preparation of the detailed report we
discovered three modelling assumptions that were conspiring to produce that
result. Correcting them flipped the optimum completely — from 3-line triangles
to 12-line dodecagons — and the mass rose from 58 kg to 74 kg. This post tells
both stories: what we found, and how we found what was wrong with it.

The 74 kg result is still a 71% reduction from our V6 baseline of 259 kg, and the corrected physics
tell a more nuanced story about polygon geometry than the original headline
suggested.

---

## What happened

Our differential evolution optimiser converged on three-line triangle rings at
58 kg — a 67% reduction from the octagonal baseline. The result was dramatic and
counterintuitive: fewer lines meant each beam carried more compression, but the
mass accounting worked the other way because Euler buckling sizing runs through
√C rather than C, and because tethers and knuckles both scale directly with line
count.

We wrote it up. We made diagrams. We were about to post. Then three things
surfaced during review.

---

## The three corrections

**1. Polygon force resolution: tan vs sin.** The structural model was using
tan(π/n) instead of sin(π/n) to resolve polygon vertex forces into beam
compression. For an n-gon under radial load, the correct formula is C = F_v /
(2·sin(π/n)). The tan formula understates compression by cos(π/n) — a factor of
2 at n=3 but only 1.04× at n=12. The old model was artificially favouring low
line counts.

**2. Free-floating knuckle mass.** The knuckle mass was an independent design
variable with a lower bound of 0.005 kg — completely decoupled from beam
diameter. A 126 mm beam and a 50 mm beam got the same knuckle. We replaced it
with a geometry-coupled model where knuckle mass derives from the beam outer
diameter and wall thickness, assuming a bent CFRP tube cuff with weight-optimised
patterning. For the 95 mm beams in the new optimum, this gives ~0.10 kg per
knuckle instead of 0.005 kg.

**3. Elevation power exponent.** During the June 10 BEM table regeneration, the
power elevation exponent was updated from cos³ to cos²·⁶⁵ in the main dynamics
code — but two utility files were missed and still used the old exponent. Now
consistent across the codebase.

Together these three fixes added about 16 kg to the optimum mass and shifted
the preferred polygon from n=3 to n=12.

---

## The corrected optimum

A 60-island differential evolution campaign (600,000 evaluations, 13.9 minutes
on 8 threads) converged to:

| Parameter | Old result (pre-fix) | Corrected result |
|-----------|---|-----|
| **n_lines** | **3 (triangle)** | **12 (dodecagon)** |
| Do_top | 126 mm | 95 mm |
| t_over_D | 0.01 | 0.01 |
| r_hub | 6.13 m | 5.40 m |
| r_bottom | 0.30 m | 1.05 m |
| target_Lr | 3.0 | 2.98 |
| n_expansion | 3 | 1 |
| density_profile | 0.76 | −0.13 |
| bank_angle | 45° | 45° |
| **Mass** | **58 kg** | **74 kg (−71% from baseline)** |

---

![Figure 1: Polygon comparison — the old octagon baseline (V6) vs the new
dodecagon optimum (V6.2). Twelve thin 95 mm beams with small knuckles beat three
thick 126 mm beams with large knuckles.](d1-polygon-comparison.png)

---

## Why the flip happened

The sin correction removed the artificial advantage of low n. At n=3 the
compression was 2× higher than the model computed; at n=12 the error was only
4%. The coupled knuckle mass removed the second advantage: triangle rings needed
thick beams (126 mm) and therefore heavy knuckles, while dodecagon rings use
thin beams (95 mm) with proportionally lighter knuckles.

With both corrections in place, the economics reverse. Twelve thin beams with
twelve small knuckles cost less total mass than three thick beams with three
large knuckles — even after accounting for the extra tether mass. The optimiser
wants more lines than our current upper bound of 12 allows.

---

![Figure 2: Density profile — the n=12 optimum uses nearly uniform ring spacing
(β ≈ −0.13) because the beams are thin enough that local strength requirements
don't demand biased density.](d2-density-profile.png)

---

## One remaining uncertainty

Our BEM aerodynamic model uses a solidity correction to account for induction:
Cp ∝ (5/n_lines)^k with k=0.7. This exponent is labelled as a placeholder in
the source code — it's physically motivated but never been validated against
AeroDyn BEM sweeps at multiple blade counts.

The n=12 result is sensitive to this exponent. At k=0.7, a 12-line rotor takes
a 41% Cp penalty relative to the validated 5-line baseline. If the true exponent
is k=0.5 (30% penalty), the structural advantage of more lines would be even
stronger. If k=0.9 (51% penalty), the optimum might shift back toward n=8–10.

We are running AeroDyn BEM sweeps at n={3,5,6,8,10,12} to lock this down. The
qualitative conclusion — that corrected physics push the optimum toward higher
line counts than the old triangle-ring result — is robust regardless of the
exact exponent. But the precise optimum and the absolute mass number will shift
when we have validated aerodynamics.

---

![Figure 3: Mass scaling with line count — the corrected sin-based polygon
compression formula shows a different shape than the old tan-based curve.
Higher n benefits from the √C Euler buckling scaling while avoiding the
compression penalty at low n.](d3-mass-scaling.png)

---

## Expansion rotors

The corrected optimum uses a single expansion rotor at the hub (down from three
in the old result). At n=12 the hub rotor is sized for 25 kW (50 kW ÷ 2 rotors
rather than ÷ 4), giving it a larger radius and more thrust per blade. The
expansion rotor count dropped because distributing thrust across more stations
no longer pays for itself — the larger hub rotor at n=12 handles the load
efficiently at one station.

The bank angle remains at 45° (the upper search bound). A caution from our earlier 
post: during pitch depower the apparent wind direction at the
expansion rotor shifts, and at 45° bank the blades may be back-winded. Dynamic
simulation is needed before this angle can be considered validated.

---

![Figure 4: Optimisation landscape — the DE convergence trajectory in the
corrected search space. The global optimum at n=12, β≈−0.13, n_exp=1 is
visible in the lower-left region. Islands exploring n<6 consistently hit the
penalty barrier.](d4-optimization-landscape.png)

---

## What's still at the bounds

Seven of eleven parameters remain on their bounds, including n_lines=12 (wants
more), t_over_D=0.01 (wants thinner walls), and bank_angle=45° (wants steeper
bank). The optimiser is not done — it's just run out of permitted space.

The key structural bound is n_lines. With n_blades = n_lines (one blade per
polygon vertex on the hub ring), higher line counts increase solidity and
induction losses. The interaction between the structural optimum (more lines =
lighter beams per unit compression) and the aerodynamic penalty (more blades =
more induction) is the central unresolved question in the TRPT design space.

---

## Method and reproducibility

All code, data, and the corrected source files at:
`github.com/rodWindswept/KiteTurbineDynamics.jl`

The three corrections are documented in `docs/case-notes/` and the campaign
workflow is captured as a Hermes agent skill. Campaign results (best design,
convergence history, raw DE vector) at `scripts/results/v6_2_campaign_50kw/`.

---

![Figure 5: Bank angle concern — the expansion blade at 45° bank during pitch
depower. Dynamic simulation needed to confirm safe operating envelope.](d5-bank-angle-expansion.png)

---

*Contact: rod@windswept.energy*
