# Addendum: the ontology against the report and the physics

For Rod Read, Windswept & Interesting Ltd. Confidential: written on Tallak's machine and kept there.

**How this was made.** An AI agent (Claude Opus 5.5) wrote this addendum to `review.md` at Tallak
Tveide's request, with samara at git rev `d74ea4e`. Tallak passes it on, not the agent. I read
`axioms.yaml`, `ontology-core.yaml` (96 entities), `draft-glossary.md` (R1–R60), and PDF pages 11,
22 and 24, rendered as images: the twist-limit plate and the register rows NR-008 to NR-053. Every
check is in `samara/ontology.samara` (output in `out_onto.txt`, about 0.1 s) and
`samara/dims_generated.samara` (one check per entity). Verified results and judgement are marked
separately.

**In short.** The report and the ontology use "δcrit" for two different twists. The report's δcrit
is the restoring-torque **peak**; the ontology's is the torque's **zero crossing**. For the
straight-line section model, the zero crossing sits at exactly 180° whatever the tension does,
unless the rings meet first. The peak is also where the twist under load loses stability. So the
ontology's fatal axiom fires only after the shaft has already run away. I got this wrong in
`review.md` too, which is now corrected (O1). The units are clean: all 45 entities that carry a
dimension agree with their SI unit.

| # | Class | Finding |
|---|---|---|
| O1 | error (naming clash; and a correction to review.md) | the report's δcrit (98.86°, 92.64°) is the torque peak, the ontology's δ_peak |
| O2 | error (physics; the verdict is judgement) | the zero crossing is 180° for every coaxial straight-line section; the twist turns unstable at the peak, not at the crossing |
| O3 | error | `max(T_section) > 0` is not enough at n = 3: two taut lines cannot carry axial force and torque on the axis |
| O4 | error (machine form) | the axioms use symbols that no entity defines: `Cp`, `delta_operating`, `T_section` |
| Q1 | question | R26's "stable for δ < 90°" is the l → ∞ limit: δ_peak = 90° + r0·r1/l² rad + … |
| Q2 | question | twist ratio against torque ratio, side by side |
| Q3 | proposal | the Betz axiom with its area basis |
| Q4 | question | `trpt_twist_limit`: the "no limit" case, and a 0.2 % residual |
| Q5 | minor | unit conversions with 2π, empty Formula dimensions, classes, the "Goldstein" name |
| C5–C8 | closed form | δ_crit as a piecewise form, the twist ratio as a function of the torque ratio, Glauert's cubic, the peak series |
| ✓ | checks out | 45/45 entity units, 12 formula unit checks, the delta_peak definition, the realisability floor |

---

## 1 Errors

### O1. Two meanings of δcrit (R17, R24; report §3.3–3.4, NR-022/023); review.md corrected

The ontology (R17, R24, `critical_twist_angle`) defines δcrit as the twist where the restoring
torque **crosses zero**, and makes the peak only the warning line. The report's δcrit comes from
`trpt_twist_limit` (NR-022): 98.86° for S1–S4 and 92.64° for S5. That δcrit is the **peak**. The torque
margins in NR-022 and NR-023 match the peak reading and no other:

| | S1 (33.95°, 98.86°) | S5 (22.82°, 92.64°) |
|---|---|---|
| extract: capacity / torque | 805.0/396.8 = **2.0287** | 1069.9/397.2 = **2.6936** |
| peak model, Λ(δ_peak)/Λ(δ) (C3 in review.md) | **2.0252** | **2.6883** |
| sin law, peak at 90° | 1.791 | 2.578 |
| sin law with its zero at the report's δcrit | 1.135 | 1.431 |

In the ontology's terms, the report's limit is δ_peak, and its torsional capacity is the peak torque.
The ontology's δcrit for these sections is 180° (O2). So the report's "δcrit 98.86°" and the
ontology's `torsional_collapse_fatal` (δ < δcrit) are different checks under one name. Either the
report says δ_peak, or the ontology moves its fatal line (O2).

**Correction to review.md.** Q8 there read "zero crossing" as dτ/dθ = 0 and called it consistent
with C1. That reading was wrong: the ontology means τ = 0. C1 there is the peak (δ_peak), and so is
the report's δcrit. I have amended review.md (Q8, C1, section 4, and a note at the top). The numbers
in review.md are unchanged. Its argument for the torque ratio stands (Q2 below), and against the
ontology's 180° the S1 twist ratio is 0.189, not 0.343.

### O2. The zero crossing is pinned at 180°; stability ends at the peak (R17, R24, R25, axioms)

**Verified.** Take a straight line from radius r0 to radius r1, twisted by δ, carrying any tension T.
Its moment about the shaft axis is

  τ = T·r0·r1·sin δ / (line length)

```
moment: simplify(cross(P1, T * (P0 - P1) / len_line)[3])
                                  → -T * r0 * r1 * sin(d) / sqrt(h^2 + r0^2 - 2 * r0 * r1 * cos(d) + r1^2)
solve(d, sin(d) = 0)              → [pi, 2 * pi]
```

So τ crosses zero at δ = 180° **for every tension model**, as long as the line keeps a length. With
a fixed line length l, the rings meet where cos δ = (r0² + r1² − l²)/(2·r0·r1). That cosine is below
−1, so the rings never meet, exactly when l > r0 + r1 (`test_equal → true`). Every section with a peak
below 180° has l > r0 + r1, because at the peak (l² − r0² − r1²)/(2·r0·r1) − 1 = (1 + c)²/(−2c) > 0
(`test_equal → true`). Hence:

  δ_crit = 180° if l ≥ r0 + r1, else arccos((r0² + r1² − l²)/(2·r0·r1)) (the rings meet)

For the pilot's shaft F (20, 50, 100), δ_peak = 98.27°, Λ_max = 0.2398, Λ(180°) = 0, and
Λ(225°) = −0.1876. For l < r0 + r1 at fixed axial tension, the torque does not cross zero at all: it
grows without bound as the rings meet (2.24, 7.05, 22.3 at 0.1, 0.01 and 0.001 rad before meeting,
for r0 = r1 = 1, l = 1.5). R17 calls the 180° figure "a special-case observation". For coaxial rings
joined by straight lines it is the general case. Only tilted rings, sagging lines or meeting rings
move it.

**Verified: stability ends at the peak.** Model the rotor as an inertia J_r with aerodynamic torque
slope a, the ground side as J_g with load-law slope b (2kω for τ = kω²), and the shaft stiffness as
s = dτ/dδ. Then

```
characteristic_polynomial(x, [0, 1, -1; -s/J_r, a/J_r, 0; s/J_g, 0, -b/J_g])
subs(x = 0, ...)                   → s * (b - a) / (J_g * J_r)
```

Routh–Hurwitz needs that constant term to be positive. With the load law steeper than the rotor's
torque curve (b > a, the normal operating case), the twist is stable only while s > 0, that is,
before δ_peak. Past the peak, a small extra twist lowers the transmitted torque, the rotor speeds up,
the ground ring slows, and the twist grows further. **Judgement:** the event that loses the machine
is the peak, and by the time the twist reaches 180° the shaft has already run away. The literature
phrase that R26 records, "positive torsional stiffness stability condition", is exactly δ < δ_peak.
I would make the peak the fatal line, give the warning as a torque margin (Q2), and keep 180° as a
derived constant. The `delta_peak` entity's own definition, "past which torsional stiffness turns
negative", is right.

### O3. Full-section tension at n = 3 (R56, R60; axiom positive_tension_constraint)

**Verified, for a coaxial section.** Line i adds a horizontal force T_i·e^{iφ_i}·w/l, with w the same
for every line, and a vertical force at r0·e^{iφ_i} that tilts the ring by the same sum. So the
section carries an axial force and a torque, and nothing else, exactly when Σ T_i·e^{iφ_i} = 0
with T_i ≥ 0.

```
n = 3, line 3 slack:  solve([T1, T2], horizontal balance)  → [[0, 0]]
                      det(w, rot(120°) w) = (√3/2)·(r0² − 2·r0·r1·cos δ + r1²)  (≠ 0)
                      tilting moment, same two lines        → [[0, 0]]
n = 3, all taut:      → T2 = T3 = T1
n = 4, line 4 slack:  → T2 = 0, T3 = T1   (the opposite pair carries it all)
```

With three lines and one slack, no coaxial equilibrium exists. The two taut lines pull the ring
sideways and tilt it, so the shaft must bend before it can carry torque again. Whether it does, and
how far it bends, is a nonlinear 6-DOF equilibrium of each ring with one-sided line constraints. That
needs the real geometry and the neighbouring sections; samara could set it up with `find_root`, but
the simulator is the right tool. So `max(T_section) > 0` is necessary but not sufficient. A
machine-parseable condition that is exact for the coaxial section:

  `max_gap(phi[T_i > 0]) <= pi`  (the taut lines do not all lie in one half-circle)

For n = 3 that is `min(T_section) > 0`, R58's original form, which R60 replaced. It also agrees with
R31 ("two lines cannot close a ring"). For n = 4, one slack line leaves the opposite pair carrying
everything.

### O4. Axiom symbols that no entity defines (axioms.yaml; ontology-core.yaml l. 3674–3709)

The expressions are marked `status: checked`, but `Cp` (the entity's symbol is `C_p`),
`delta_operating` and `T_section` appear nowhere else in the core (grep). `collapse_margin` is used
by its id, while its symbol is `delta/delta_crit`. A machine check cannot bind these as written.
(Verified by search. Dimensionally, all four expressions are consistent: section 4.)

---

## 2 Questions and a proposal

### Q1. R26's "stable for δ < 90°"

The series of the peak (C8): cos δ_peak = −r0·r1/l² + O(l⁻⁴), so δ_peak = 90° + r0·r1/l² rad + ….

| r0, r1, l | δ_peak | 90° + r0·r1/l² |
|---|---|---|
| 0.5, 1, 20 | 90.07° | 90.07° |
| 0.8, 1, 5 | 91.96° | 91.83° |
| 0.8, 1, 2.66 | 98.66° | 96.48° |
| 0.8, 1, 2 | 113.0° | — |
| 1, 1, 2.05 | 129.8° | — |

The statement holds as the stability boundary only in the limit l → ∞, or for two idealisations
whose torque is ∝ sin δ (a fixed height, or a fixed line tension; `solve → [pi/2, 3·pi/2]`). For
any finite section at fixed axial tension it is sufficient but not the boundary. It understates the
stable range by 2.6° (S5), 8.9° (S1) and up to tens of degrees for short sections. It is not unsafe
in this model. It would be unsafe only in a model where the peak falls below 90°, which none here
does.

### Q2. Twist ratio against torque ratio (R57)

Let x = δ/δ_peak. The torque ratio τ/τ_peak = 1/margin, for the section model, is

  y(x) = sin(x·δ_p) / √(1 + cos²δ_p − 2·cos δ_p·cos(x·δ_p))

(C6, proved via review.md's C3). For S1 (δ_p = 98.859°):

| twist ratio δ/δ_peak | 0.1 | 0.25 | **0.343** (S1) | 0.5 | 0.6 | 0.75 | 0.9 | 1 |
|---|---|---|---|---|---|---|---|---|
| torque ratio τ/τ_peak | 0.149 | 0.366 | **0.494** | 0.687 | 0.791 | 0.914 | 0.986 | 1 |
| torque margin | 6.7 | 2.73 | 2.03 | 1.46 | 1.26 | 1.09 | 1.01 | 1 |

The slope at zero twist is δ_p/(1 − cos δ_p) = 1.495, and at the peak it is 0. The twist ratio
reads 0.75 where the torque margin is already 1.09. With the ontology's δcrit = 180°, S1's
collapse_margin is 33.946/180 = **0.189**, and the warning line δ_peak/δcrit sits at **0.549**. A torque
margin of 1.5 corresponds to:

| δ_peak | 90.07° | 92.64° | 98.86° | 113.0° |
|---|---|---|---|---|
| twist for margin 1.5 | 41.86° | 43.57° | 47.70° | 56.91° |
| as δ/δ_peak | 0.465 | 0.470 | 0.483 | 0.504 |
| as δ/180° | 0.233 | 0.242 | 0.265 | 0.316 |

So a margin rule in twist ratio needs a per-geometry threshold, while one in torque ratio does not.
The torque ratio is also what a gust or a load step has to exceed. My suggestion (judgement): keep R57's
ratio form, but define collapse_margin as τ(δ)/τ_peak, or give both, with the conversion y(x)
above.

### Q3. The Betz axiom with its area basis (betz_goldstein_limit)

The ceiling depends on the tilt γ between the rotor axis and the wind (verified, `maximize` per tilt):

| γ | 0° | 10° | 20° | 30° | 40° | 50° |
|---|---|---|---|---|---|---|
| Glauert, max of 4a(cos γ − a)√(1 − 2a·cos γ + a²) | 0.5926 | 0.5857 | 0.5631 | 0.5192 | 0.4471 | 0.3453 |
| 16/27 · cos γ (Betz on the wind-normal area) | 0.5926 | 0.5836 | 0.5569 | 0.5132 | 0.4540 | 0.3809 |
| Glauert / projected | 1 | 1.004 | 1.011 | 1.012 | 0.985 | 0.906 |
| 16/27 · cos³ γ | 0.5926 | 0.5660 | 0.4917 | 0.3849 | 0.2664 | 0.1574 |

Proposal, with the basis stated (judgement on which to make fatal):

```yaml
- id: betz_ceiling_wind_normal
  target: power_coefficient_quantity
  expression: P <= 16/27 * 0.5 * rho * A_swept * cos(gamma) * V^3
  # A_swept: the annulus the blades sweep in the rotor plane (tip radius to root radius)
  # gamma: angle between the rotor axis and the wind (cos(gamma) = cos(elevation) * cos(yaw))
  # V: free-stream wind at hub height, the same V that defines Cp
  severity: warning
- id: betz_ceiling_tilted_disc
  expression: P / (0.5 * rho * A_swept * V^3) <= Cp_glauert_max(gamma)
  # Cp_glauert_max: max over a of 4 a (cos g - a) sqrt(1 - 2 a cos g + a^2); its a solves the cubic
  # -3 a^3 + 7 a^2 cos g - 3 a cos^2 g - 2 a + cos g = 0 (C7); 0.5192 at 30 deg
  severity: fatal
```

Glauert's model is the classical one for a skewed disc. Up to about 35° it lies at most 1.2 %
above the projected-area Betz, so a fatal line at the projected Betz value could flag a
momentum-consistent design. Hence the two levels. Today's "Cp ≤ 16/27" with Cp on the disc area
cannot trip below a Cp of 0.593, which is 14 % above the 30° ceiling. A minor point: the 16/27
ceiling is Betz's (Lanchester–Betz–Joukowsky). Goldstein's finite-blade optimum lies below it,
so "betz_goldstein" in the id is misleading.

### Q4. `trpt_twist_limit` (PDF p. 11 caption, NR-022)

The caption says that a no-limit segment exists because "its tension lines cannot reach the axis".
In the peak model, every section with l > r0 + r1 has a peak. A section with l ≤ r0 + r1 has no peak:
its torque grows until the rings meet (O2). Is "no limit" that case? Also, the margins in the extract
are 0.17 % (S1) and 0.20 % (S5) above the closed form from the printed twists. That is more than
rounding of the twist (33.95°, 22.82°) explains, and might come from the rest length against the
loaded length ("mean line rest length", NR-022).

### Q5. Units and classes (minor; all verified by reading the YAML)

- **2π conversions.** `natural_frequency` is rad/s in SI but Hz in the papers, and
  `rotational_speed_*` is rad/s against RPM. Dimension vectors take rad = 1, so the 2π (and 2π/60)
  factors are invisible to them. The conversion needs its own field. samara has the same trap: it
  shows 1/s as Hz (gap W13).
- **Formula entities without a dimension.** 11 of the 14 have none: axial_force_formula, force_ratio,
  mppt_law_formula, power_coefficient_formula, ring_spacing_formula, tether_drag_eq,
  tether_drag_formula, torque_capacity_formula, torsional_stiffness_eq, and the two scaling laws. The
  scaling laws are proportionalities, so empty may be right for them.
- **Classes.** `critical_twist_angle` is a Formula with unit rad, while `delta_peak` is a
  PhysicalQuantity. One of them is in the wrong class.
- **Empty units.** `collapse_margin` carries unit_si '1', while the other dimensionless entities
  carry ''.
- **The wrong stiffness formula.** `torsional_stiffness_eq` reads "shear modulus times polar moment
  over length". That is a solid shaft. A TRPT section's stiffness is
  dτ/dδ = T·r0·r1·cos δ/l at fixed line tension, or T_N·r1·dΛ/dδ at fixed axial tension. Both are
  N·m/rad, but they are different physics.

---

## 3 Closed forms (new here; C1–C4 are in review.md)

- **C5:** δ_crit = π if l ≥ r0 + r1, else arccos((r0² + r1² − l²)/(2·r0·r1)). The zero crossing comes
  from τ = T·r0·r1·sin δ/(line length) for any T.
- **C6:** the torque ratio as a function of the twist ratio, y(x) above. Its inverse, the twist at a
  target margin M, is cos δ_M = (c + √(c² − M²(1 + c² − M²)))/M² (review.md C3).
- **C7:** Glauert's tilted-disc optimum: −3a³ + 7a²c − 3ac² − 2a + c = 0, with c = cos γ. Its root
  is a = 0.343369 at 30°, matching `maximize`.
- **C8:** δ_peak = 90° + r0·r1/l² rad + O(l⁻⁴), from `series(l = infinity, cos_peak)` → −r0·r1/l².

## 4 What checks out

- **Units of all 45 dimensioned entities.** unit_si agrees with the dimension vector, with rad = 1
  (`dims_generated.samara`: 45 × `test_equal → true`).
- **Formula units.** Every one of these is consistent in samara's units:
  - Cp = P/(½ρAV³) and λ = ΩR/V are dimensionless, and so is σ/V;
  - kΩ² gives N·m and kΩ³ gives W, with k in N·m·s² (the report's N·m/(rad/s)²);
  - GJ/L gives N·m;
  - the TRPT torque and its δ-derivative give N·m;
  - √(K/J) gives 1/s;
  - ⅛ρC_t·d·l·v² gives N, and P/A gives W/m²;
  - the Betz ceiling in power form gives W.

  The four axioms are dimensionally consistent too: dimensionless against 16/27, an angle ratio
  against an angle ratio, angle against angle, and force against 0.
- **The `delta_peak` definition** ("past which torsional stiffness turns negative") is right, as is
  `torque_twist_relation`'s shape: it rises to a peak and falls through zero, at 180° in this model.
- **The simulator** uses the peak torque as the torsional capacity and the peak twist as its limit.
  That matches the physics (O2) and disagrees with the ontology only in the name (O1).
- **The realisability floor.** arcsin(1/1.05) = 72.247° matches NR-053's 72.25°. It is a torque
  margin of 1.05 under a sin law. Under the section model at S1's peak, the margin at 72.25° is 1.110
  (review.md Q3).

## Files

These are in `samara/`:
- `ontology.samara`: sections 1–5, with output in `out_onto.txt`.
- `dims_generated.samara`: generated from `entities.tsv`, which was extracted from
  ontology-core.yaml; output in `out_dims.txt`.
- `definitions.tsv`: the definitions, extracted.
- `pages/`: the rendered PDF pages.

New generic samara gaps W12–W16 are in `../samara-gaps.tsv`.

**Limits.** I saw the PDF's register rows only on the three pages I rendered, and no simulator
code. O2's choice of which twist to call fatal is my judgement; the math under it is verified.
O3 covers the coaxial section only.