# Review of "The kite turbine: a search over its design space", draft v0.89

For Rod Read, Windswept & Interesting Ltd. Confidential: written for you on Tallak's machine and kept there.

**How this was made.** An AI agent (Claude Opus 5.5) wrote this review at Tallak Tveide's request,
with samara, Tallak's computer algebra system (git rev `d74ea4e`). Every derivation and number check
below was run in samara; the files are in `samara/` beside this note. Tallak is the one passing this
on to you, not the agent. I read only the draft and the cover note. I had no register rows, no code
and no ontology files (they were not attached). So I could check what the draft states and the
numbers it prints, not how the simulator computes them. Where a finding rests on judgement and not
on a check, I say so.

**In short.** The draft's arithmetic is careful. Nearly every number I could recompute agrees to
the printed digits, and two torque margins reproduce exactly from a shaft model that also has
closed forms (section 3). I found four errors: one wrong sentence about blade geometry, a Betz screen
whose ceiling is too high for a tilted rotor, an explanation of the power gap that a sign argument
rules out, and an edge case in the reject seam. There are ten questions, mostly about which area,
radius or limit a gate uses.

**Addendum.** After the ontology files arrived, `review-ontology.md` corrected this note in one place: the
ontology's δcrit is the zero crossing of the torque (180° in this shaft model), while the report's δcrit
is the torque peak. Q8 and C1 below now say so.

Line numbers refer to `report-first-draft-v0.89.md`.

| # | Class | Finding | Where |
|---|---|---|---|
| E1 | error | blade "runs from r_hub to r_rotor", but r_rotor 2.434 m < r_hub 4.580 m | §2.1, l. 180–183 |
| E2 | error | the per-rotor Betz screen's ceiling, 16/27 on the untilted annulus, is 14–16 % above the momentum ceiling of a 30° tilted disc | §2.4.5, l. 439, 475, 484 |
| E3 | error | power gap: a speed trend or averaging can only make P_mean *larger* than k·ω̄³, and the window swing caps any such effect at half the gap | §2.3, l. 338–345 |
| E4 | error (edge) | twist charge reaches 1e12, above the 1e9 reject cost, so "no reject ranks above an ok design" fails near the limit | §2.4.7–2.4.8, l. 534–544 |
| Q1 | question | clearance 5.468 m fits a 4.54 m radius, not the 5.63 m blade tip | l. 729, 451 |
| Q2 | question | what does the crossing limit bound? It is below 90° for every segment, and lines of one shaft never meet before half a turn | l. 284, 730, 850–852 |
| Q3 | question | the campaign twist gates admit torque margins down to about 1.07 | l. 498, 560, 737–739 |
| Q4 | question | the wind-normal factor is 0.8590, not cos 30° = 0.8660 | l. 714 |
| Q5 | question | the sizing formula needs f_proj > 1 at 5 kW, 11.01 m/s | l. 187–192, 719 |
| Q6 | question | the heavy-end band (8.9475–8.9511 kW) is not the k = 3.0 row (8.89 kW) | l. 313, 318–325, 642–644 |
| Q7 | question | ok designs "5.02 to 6.32 kW" against one ok design at 5.00 kW | l. 635, 956 |
| Q8 | question | the ontology axioms: Betz area basis, collapse margin as twist or torque ratio, slack lines with three lines | cover note |
| Q9 | judgement | a "50 kW default" gain only five times the 5 kW gain | l. 1039 |
| Q10 | minor | wording and references | various |
| C1–C4 | closed form | peak twist (the report's δcrit), peak torque, torque margin from two twists, crossing limit | §2.2.2, §3.3–3.4 |

---

## 1 Errors

### E1. The blade's radii (§2.1, l. 180–183)

The text says the blade "runs from the ring radius `r_hub` to the tip radius `r_rotor`". The winner
has r_rotor = 2.434 m (l. 192) and r_hub = 4.580 m (l. 668), so that blade would have negative
length. The numbers elsewhere fit together another way. The tip-speed ratio and the ring speed ratio
use the same speed and wind (13.38 rad/s, 11.01 m/s; samara gives 5.5659 for the ring), so the tip
radius is 6.8415 · 11.01 / 13.38 = **5.630 m**. The base span is 0.75 · 2.434 · 0.8213 = **1.499 m**
(l. 178, 774). An annulus from 5.630 − 1.499 = 4.130 m to 5.630 m has area
π(5.630² − 4.130²) = **45.971 m²**, which matches your raw swept area of 45.9733 m² (l. 714) to
within the rounding of ω. A blade running outward from the ring would sweep 50.21 m² instead.

```
R_tip: lam_tip * v / w_mean                         → 5.6297
span: 0.75 * 2.434 * 0.8213                         → 1.499
pi * (R_tip^2 - (R_tip - span)^2)                   → 45.9712   (draft 45.9733)
pi * ((r_hub + span)^2 - r_hub^2)                   → 50.207
```

So the blade crosses the ring. About 0.45 m lies inside it and 1.05 m outside. r_rotor is the sizing
radius, not the tip. Please correct the sentence and name the tip radius. (Verified, assuming the
TSR is taken at the blade tip.)

### E2. The per-rotor Betz screen's area basis (§2.4.5, l. 439, 475, 484)

The aggregate screen charges the wind-normal area. I reproduced its ceiling exactly:
16/27 · ½ · 1.225 · 39.4912 · 11.01³ = **19 130.4 W**, and 5.309 kW is **27.75 %** of it. The
per-rotor screen, by contrast, charges "the annulus with no elevation factor". For a rotor whose axis
is tilted 30° to the wind, every standard momentum model puts the ceiling on the disc area well
below 16/27:

| ceiling on the disc area at 30° tilt | Cp |
|---|---|
| Betz on the untilted annulus (per-rotor screen) | 0.5926 |
| Glauert's tilted-disc momentum model, max over induction | **0.5192** (at a = 0.343) |
| Betz on the projected area, 16/27 · cos 30° | 0.5132 |
| axial component only, 16/27 · cos³ 30° | 0.3849 |

```
cp_glauert: 4 * aa * (cos(g) - aa) * sqrt(1 - 2 * aa * cos(g) + aa^2)
maximize(aa, subs(g = 0, cp_glauert), 0..0.5)       → [1 / 3, 16 / 27]     (the untilted check)
maximize(aa, subs(g = pi / 6, cp_glauert), 0..0.5)  → [0.3433687629, 0.5192286517]
```

So the per-rotor ceiling is 14 % above Glauert's tilted-disc maximum, and 16.4 % above the
wind-normal basis your other two screens use (1/0.859). For a one-rotor design it can never trip
before the aggregate screen, and for multi-rotor designs it lets one rotor run up to about 14 % past
its own ceiling. The numbers are verified. Calling this an error is my judgement: if the screen is
meant only as a loose tripwire, say so and drop "Betz" from its name. Otherwise give it the
elevation factor that the other two have. The same applies to the ontology's "Cp ≤ 16/27" axiom
unless its Cp is defined on the wind-normal area (Q8).

### E3. The power–torque gap (§2.3, l. 338–345)

The draft gives P_mean = 5.309 kW against k·ω̄³ = 5.366 kW (I get 5365.6 W and 1.066 %; both
check out) and offers three possible causes: a slow speed trend, ground-ring drag, or how the
power is averaged. Under the stated law, each sample is P = k·ω³ (l. 292, 334). Two facts then hold
for any speed history:

1. **Sign.** mean(k·ω³) ≥ k·mean(ω)³ (Jensen's inequality). A trend or any averaging can only
   make P_mean *larger* than k·ω̄³, never smaller. For a linear trend ω₀(1 + e·s), s from −1 to 1:
   ```
   simplify(mean_cube - mean_w^3)                   → e^2 * w0^3     (≥ 0)
   ```
   With the window's own swing (0.029 kW in 5.309, a speed range of about 0.18 %), the effect is
   +8·10⁻⁷.
2. **Size.** ω̄ is at most the top speed, so k·ω̄³ is at most the top sample power, which is at
   most P_mean + P_range. The gap k·ω̄³ − P_mean is **56.6 W**, while the window's power range is
   **29 W** (l. 663).
   ```
   holds(2.24 * 13.38^3 - 5309 <= 29)               → false
   ```

So in the window, the sampled power cannot be k·ω³ of the window-mean ground-ring speed. That rules
out the trend and the averaging. Ground-ring drag helps only if the sampled torque is not the
generator's kω². The load sweep shows the same shortfall at every row: P_mean/(k·ω³) =
0.996, 0.993, 0.990, 0.988, 0.989, 0.988 (using ω_final). That points to something systematic, such
as the torque taken at another speed, a ratio or efficiency between the shaft and the generator, or
power sampled on the shaft side of an inertia or drag term. The math is verified. It needs only the
two sentences of the draft I cite. If the samples are not k·ω³, the draft should say what they are.

### E4. The twist charge against the reject seam (l. 534–544)

With the denominator floored at 1e-6, the twist charge at the limit is (1/1e-6)² = **1e12**, which
is above the reject cost **1e9** that the runner stamps. Any ok design with twist ratio above
**0.999968** therefore scores worse than every reject:

```
solve(rr, rr / (1 - rr) = sqrt(1e9))                → [0.9999683782]
holds(subs(rr = 0.99999, (rr / (1 - rr))^2) < 1e9)  → false
```

This is harmless in practice, but l. 544 ("No reject ranks above an ok design") is not true as
written. A cap on the charge below 1e9 would fix it. (Verified.)

---

## 2 Questions and ambiguities

### Q1. Clearance 5.468 m (l. 729; gate l. 435, 451)

The hub sits at 18.8 · sin 30° = 9.400 m. The lowest point of a circle of radius R in the rotor plane
lies R · cos 30° below the hub. A clearance of 5.468 m fits R = **4.540 m**, which is less than the
ring radius. The swept circle of the 5.630 m tips (E1) gives **4.525 m**. The ring radius gives
5.434 m, and the ring radius times cos(bank) gives 5.464 m.

```
low(R): h_hub - R * cos(30 * deg)
[h_hub, low(R_tip), low(r_hub), low(r_hub * cos(7.088 * deg)), (h_hub - 5.468) / cos(30 * deg)]
                                                    → [9.400, 4.525, 5.434, 5.464, 4.540]
```

Does the gate test the ring, or the blade tips at their build phase (three blades), rather than the
circle the tips sweep? The winner still passes with about 3 m to spare. The gate matters for the
110 clearance rejects and for designs near the 1.5 m line. (The arithmetic is verified; the
geometry of the gate is my inference.)

### Q2. The crossing limit, l. 284, and the three twist limits

Your formula simplifies to **cos δα\* = 2r²/(L² + 2r²)**. That is positive for every L and r, so
δα\* < 90° for every segment, and it tends to 90° for long segments. In contrast, the
restoring-torque peak (C1) is always **past** 90°. As for real crossing: for equal radii, two lines
of one shaft (three lines, twist δ) have the triple product −3·L·r²·sin δ, which is not zero for
0 < δ < π. The lines of a twisted shaft are skew and do not meet before half a turn.

```
simplify(cos(cross_lim))                            → 2 * r^2 / (L^2 + 2 * r^2)
limit(infinity, as_fun(L, cross_lim))               → pi / 2
expand(triple)                                      → -3 * L * r^2 * sin(d)
```

What physical event does δα\* bound, and where does it come from? From the twist charge (0.6141)
and S1's twist, S1's crossing limit is **77.26°**, which needs L/r_seg = **2.659**. If L_seg is the
line length and r_seg the outer radius, S1's δcrit of 98.859° then fixes r_in/r_out ≈ **0.814**,
which you can check against the built geometry. The draft also uses three twist limits for S1 (the
72.25° "realisability floor", the 77.26° crossing limit and the 98.859° δcrit), and §3.4 calls the
δcrit values the "over-twist limits" while the gate uses δα\*. Please name which one the gate uses,
which one the axiom uses, and which one the figure plots. (A limit that must not be exceeded reads
better as a ceiling than as a floor.)

### Q3. Do the campaign twist gates protect the torsional floor? (l. 498, 560, 737–739)

The torque margin depends only on the operating twist and δcrit (C3, verified against your 2.03 and
2.69). For S1 (δcrit = 98.859°), that gives:

| S1 twist | torque margin |
|---|---|
| 33.946° (winner) | 2.03 |
| **47.70°** | **1.50** (the torsional floor) |
| 72.25° (realisability floor) | 1.110 |
| 77.26° (crossing limit) | 1.071 |

```
to_number(twist_for(1.5, 98.859 * deg) / deg, 4)    → 47.70
[margin(72.25 * deg, 98.859 * deg), margin(77.264 * deg, 98.859 * deg)] → [1.110, 1.071]
```

The draft says the 1.5 torsional floor belongs to the verification path and that the 2.5 gate does
not cover torsion. So the campaign could mark a design ok at a torque margin of about 1.07. The
winner is far from that, but a later, lighter design might not be. Is that intended? A twist gate
set from the margin, via C3, would close the gap.

### Q4. The wind-normal factor (l. 714)

39.4912/45.9733 = **0.85900**, while cos 30° = 0.86603, and cos 30° · cos 7.088° = 0.85941. The
factor equals cos **30.80°**. Is it the rotor axis as it sags in the window (the hub bows down,
l. 698), or another factor? Please state it, because the Betz ceiling scales with it.

### Q5. The power sizing (l. 187–192, 719)

With P = 5 kW and v = 11.01 m/s, r_rotor = 2.434 m needs f_proj·Cp = **0.3286**. That gives
f_proj = **1.12** with Cp 0.2944, or 1.46 with Cp 0.2258, and a projection factor cannot exceed 1.
Which P (rotor share), v (rating wind?) and Cp enter NR-050? Also, the BEM table is a function of
the tip-speed ratio. Why is a Cp quoted "at the ring speed ratio", and which of the two Cp values
does the sizing use? (The arithmetic is verified; the inputs are unknown to me.)

### Q6. The heavy end of the load sweep (l. 313, 318–325, 642–644)

The band 8.9475–8.9511 kW is not the k = 3.0 row (8.89 kW, so 8.885–8.895). If the band is that
row's P_end, then P_mean and P_end differ by **0.59–0.74 %**, which breaks "below 0.5 per cent at
every row". Within the table the power does not level off: it rises 0.89 kW from k = 2.24 to 3.0.
Perhaps the sweep had heavier rows that the table leaves out (l. 1081's "about 9 kW" at 5.39 hints
at that). Please print them or reword.

### Q7. Which power is "mean power" for the ok designs? (l. 635, 956)

l. 635 says the ok designs hold a *mean* power between 5.02 and 6.32 kW. l. 956 says one ok design
reads 5.00 kW. The floor gates the window-*end* power (l. 442, 493), so an ok design's *mean* could
even sit below 5.00. Please state the basis in each sentence.

### Q8. The four axioms of the cover note (ontology not seen)

- **Betz ceiling Cp ≤ 16/27.** On the disc area of a 30° tilted rotor, the momentum ceiling is
  0.519 (Glauert) or 0.513 (projected area), see E2. Cp's area basis belongs in the axiom.
- **Collapse margin as a twist ratio.** For S1, the twist ratio against the peak is 0.343 (against
  the ontology's 180° it is 0.189), but the torque ratio is
  1/2.03 = 0.494. A twist ratio of 0.5 already means a torque margin of 1.46. The torque ratio is
  what collapse depends on, and C3 gives it in closed form.
- **Zero crossing** (corrected in review-ontology.md, O1). The ontology defines δcrit as the twist where
  the restoring torque τ itself crosses zero (R17, R24). The report's δcrit is the torque peak, where
  dτ/dθ = 0. In this shaft model τ crosses zero at exactly 180°. An earlier version of this note
  read "zero crossing" as dτ/dθ = 0; that reading was wrong.
- **Full-section tension** (judgement, not checked in samara). With three lines (the winner), one
  slack line leaves the ring held at two points, and the moment of the remaining two lines about
  the chord through their attachment points is zero. The ring can balance only by uneven tension in
  the next section, and it tilts. "Transmission dies only when every tether goes slack" may hold in
  the simulator, but as a physical claim it needs a statement about geometry at n = 3.

### Q9. The 50 kW default gain (l. 1039; judgement)

For a load law P = k·ω³ at a fixed tip-speed ratio and wind, k = ½ρπCp·R⁵/λ³ grows as R⁵, that is
as P^2.5. A geometrically scaled 50 kW machine would want about 316 times the 5 kW gain, not 5
times. Either the 10.0 default is not a 50 kW gain or that machine runs at another λ or wind. Worth
a word in the ledger entry, since the lesson there is about gains.

### Q10. Minor points

- Hub at 9.4000 m (l. 678) against wind "at 9.41 m" (l. 676). Both give 11.01 m/s (11.008 and
  11.009), but one height would read better.
- "Exponent 1/7, from the measured Daisy pair" (l. 677): one speed–height pair fixes the reference
  point, not the exponent.
- References 11–17 are never cited in the body.
- The cover note says the draft cites Tallak's tether-drag ODE solver. v0.89 does not: no entry in
  §8 and no tether-drag formula in the text (see the note on tether drag below).

---

## 3 Closed forms that could replace numerics

These hold for the segment model whose two torque margins I reproduced: line length l, radii r0 ≤ r1,
axial tension T_N, and Λ = τ/(T_N·r1) = r0·sin θ / √(l² − r0² − r1² + 2·r0·r1·cos θ). If your code
finds δcrit or the torque capacity by a search over twist, each of these replaces it exactly.

**C1. Peak twist δ_peak (the report's "δcrit"; the ontology's δcrit is the zero crossing, 180°, see review-ontology.md O1):**

  cos δ_peak = ( √((l² − (r1+r0)²)·(l² − (r1−r0)²)) − (l² − r0² − r1²) ) / (2·r0·r1)

samara solves dΛ²/d(cos θ) = 0, factors the discriminant into the two reach terms, and proves the
root for every shaft longer than r0 + r1 (`test_equal → true`). Because √((A−B)(A+B)) < A, the
cosine is negative, so δ_peak > 90° always. Examples: 110.1°, 113.0°, 96.3°, 101.9° and 90.07° for a
long shaft.

**C2. Peak torque:**

  τ_max = T_N · r1 · Λ_max = T_N · ( h(0) − h(π) ) / 2,  h(θ) = √(l² − r0² − r1² + 2·r0·r1·cos θ)

That is half the drop in segment height from no twist to half a turn. It is proved for every shaft
(`test_equal → true`), and it tends to T_N·r0·r1/l for long shafts. (From the pyramid paper review,
where samara found Λ_max first.)

**C3. Torque margin from two twists, and its inverse:**

  M(θ_op, δcrit) = √(1 + cos²δcrit − 2·cos δcrit·cos θ_op) / sin θ_op

At the peak, l² − r0² − r1² = −2·r0·r1·(1 + c²)/(2c) with c = cos δcrit, so the geometry cancels
(`test_equal → true`; checked against Λ(δcrit)/Λ(θ_op) directly to 8 digits). Check against the
draft: S1 at 33.946° with 98.859° gives **2.025** (draft 2.03), and S5 at 22.8° with 92.6° gives
**2.689** (draft 2.69). The inverse gives the twist allowed for a target margin M:

  cos θ_M = ( c + √(c² − M²·(1 + c² − M²)) ) / M²

That gives 47.70° for S1 at M = 1.5 (Q3). It would let the twist gate, the charge and the collapse
axiom all speak in torque margin.

**C4. Crossing limit:** cos δα\* = 2r²/(L² + 2r²), a simpler form of l. 284 (Q2).

---

## 4 What checks out

All recomputed in samara (`compare.samara`: 34 checks true, and 7 false where false is the finding).

- **Torque margins** 2.03 (S1) and 2.69 (S5) follow from the printed twists and δcrit alone (C3).
  This is strong evidence that the code's torsional capacity is the fixed-length shaft model.
- **Charges:** 5(P−5)² = 0.4933 at P_end 5.3141; 20(2.5/FoS)² = 0.5577 for FoS in its rounding
  interval (0.5576 at exactly 14.972); and (r/(1−r))² = 0.6141 gives r = 0.43935, the gate table's
  crossing ratio 0.4393. Their sum is 1.665, and your own account of 27.363 against 27.364 is right.
- **Betz ceiling** 19 130.4 W on the wind-normal area at 11.01 m/s, and 27.75 %. The delivered Cp is
  0.1645 on the normal area and 0.1413 on the raw area.
- **Load law:** k·ω̄³ = 5365.6 W, a gap of 1.066 % (1.07), and P/ω̄ = 396.79 N·m from the rounded
  inputs (draft 396.76).
- **Rotor:** ring speed ratio 5.5659; tip radius 5.630 m and raw area 45.971 m² (E1); tip speed
  75.3 m/s at the window-mean speed, under the 100 m/s ceiling. The seed's tip-speed sentences imply
  4.82 m and 4.76 m, consistent with "about".
- **Lift line:** 1.5 · 20.698 · 9.81 = 304.57 N, and /sin 70° = 324.12 N.
- **Wind:** 10.0 · (9.41/4.8)^(1/7) = 11.009 m/s.
- **Gate-table margins:** +0.314 kW and 6.28 %; +12.472, 498.9 % and 5.99×; +3.968 m, 264.5 % and
  3.65×; 2.13×, 2.91× and 2.28×; and a swing of 0.55 %.
- **Counts:** 508 + 301 + 110 + 11 = 930; 96 + 4 + 201 = 301; 93 + 37 + 36 + 30 + 3 + 2 = 201;
  3 islands × 31 generations × 10 = 930. Also 10.0/1.94 = 5.15, "about five times".
- **Peak:** the torsional stiffness dτ/dθ is zero at the report's δcrit (C1). That is the ontology's δ_peak, not its zero crossing (corrected; see review-ontology.md O1).

## Tether drag (the pyramid paper's factor)

v0.89 contains no tether-drag formula, and it cites neither the pyramid paper nor a tether-drag
solver. I could not check whether `KiteTurbineDynamics.jl` or the ontology uses that paper's
factor, because I did not read your code. If either does, note that samara found a sign slip in
it. For a cone-shaped shaft, the drag a line costs the rotor is ⅛·ρ·C_t·d·l·v² times
**(r0 + r1)(r0² + r1²)/r1³**, not (r0³ + r1³)/((r1 − r0)·r1²). The two differ little at r1 = 5·r0
(1.248 against 1.260), but the corrected factor tends to 4 for parallel lines, where the old one
diverges. (Re-derived here: `test_equal → true`, `limit → 4`.)

## Files

- `samara/windswept.samara`: the derivations (runs in about 0.1 s).
- `samara/compare.samara`: includes it and checks the draft's numbers.
- `samara/out_main.txt`, `samara/out_cmp.txt`: outputs.
- `samara/gaps.samara`: samara's own gaps met here. These are generic, with no content from the draft.

Run with `SAMARA_FUEL=200000000 timeout 300 isamara compare.samara`.

**Limits.** No register rows, code or ontology were available. The geometry inferences in E1 and Q1
assume that the TSR uses the blade tip and the same ω and v as the ring speed ratio. The error
classes above are the agent's reading, and you know the model far better than we do.