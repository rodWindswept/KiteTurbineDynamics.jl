# Aero seat: the 26 SOURCE pins and the six author facts (2026-10-20)

The third return of the founder routes 26 comments to this seat. Each one needs
one pinned number or code path before the author writes prose. The author
also asked this seat for six facts. Every pin below reads from the source
or from a signed register row. The pins list the comment ID, the answer,
and the source line.

## The six facts the author asked for

**32, the fixed load against the ideal tip-speed ratio.** The design TSR
reads 4.1. Source: `OPT_TSR_RATED = 4.1` at `src/trpt_optimization.jl:41`
and `lambda_opt = 4.1` at `src/trpt_axial_profiles.jl:211`.

With one k fixed, the load law tau = k times omega squared pins the
settled speed against the radius. So the radius gene carries the TSR. A
design whose radius lands away from 4.1 pays Cp.

The winner settles near the ideal. The winner ring speed ratio reads
omega 10.170 rad/s times r_ring 4.58 m over 11 m/s, about 4.23
(NR-016, NR-011). The coupling already prints at draft 290-293. The
draft misses one piece. It never names the ideal nor says the fixed
load biases the radius optimum toward it.

**40, what easing k does in high wind.** The generator law reads
tau_gen = k times omega squared. Easing k removes the speed governor.

The measured outcome: at 25 m/s the rotor spins up to 87.9 degrees of
hub-segment twist against a 78.8 degree crossing limit on that segment.
Source: `docs/plans/2026-09-06-closed-form-beam-sizing.md` section 5 and
`scratch/scenario_sweep.jl`, NR-048.

The proper high-wind control is feather, which means pitch depower. The
ODE aero has no feather term, so easing k was the only lever on offer.
Easing k trades the structural case away. That trade is the recorded
refusal reason.

**47, the line-failure class name.** The class is rope break. Any
sub-segment strained past `ROPE_BREAK_STRAIN = 0.035` breaks. It carries
zero tension after, and the evaluator disqualifies the run at the break
instant. Source: `src/rope_forces.jl:86-89`.

Separate classes exist. One is overtwist, the Tulloch crossing, per
segment. Another is an FoS breach, which means beam buckling or tether
tension below 2.5. Draft line 380 should name the rope-break gate so
the sentence does not read as one of the other classes.

**63 and 65, the extension steps and the 0.422 m.** NR-059. The
extension run is the winner re-run continued past the 40 s window to
200 s. The extension steps are the five-second bow increments of that
run, each smaller than the last. At the hub they fall from 0.0254 m to
0.00053 m.

The 0.422 m is the vertical bow at the midpoint ring at the end of the
200 s run. The hub reads 0.833 m there. Through the window the midpoint
reads 0.105 to 0.310 m and the hub 0.209 to 0.613 m, from 0.002 m at
settle. The report claims no bound past 200 s. Source: probe
`scratch/av_bow_probe.jl`, signed row NR-059.

**71, the three movers and their reasons.** The three are the bank
derate, the measurement window, and the tightened gates (draft 689).

Reason one: the measured AeroDyn precone sweep found retention 0.854 at
20 degrees of bank. Cos raised to 2.65 predicts 0.848, a match to 0.7
per cent. So main-rotor disc power reads times cos(bank) to the 2.65
(NR-019, NR-020).

Reason two: the old 20 s window sampled the settle decay. P_end read
5.97 kW against equilibrium k times omega cubed of about 3.15 kW. So
the honest window is 40 s with tail5 at 35 to 40 s
(`scripts/run_v13_5kw_masslift.jl:77-79`, NR-015, NR-025).

Reason three: the gate set tightened. FoS reads 2.5 over 2.5. The twist
crossing gate plus torsional FoS 1.5, clearance 1.5 m, and the Betz gate
all joined (NR-042, NR-052, NR-053).

## The SOURCE pins, by comment

**2, the least segment torque margin.** The margin is the ratio of two
torques. The numerator is the Tulloch torque capacity of the segment at
its current axial force. `trpt_torque_capacity_axial` computes it at
`src/rope_forces.jl:585`. The denominator is the torque the segment
transmits.

S1 reads 805.0 over 396.8, margin 2.03. S5 reads 1069.9 over 397.2,
margin 2.69 (NR-023). First use is the summary at draft 25. Define it
there or point at section 3.4.

**21, the fixed 22 degrees.** The cone is the field-tested three-section
geometry from Tulloch. It runs a small-radius low-drag transmission
cylinder, a 22 degree bounded cone chosen "to avoid any abrupt changes
in diameter", then the full-radius harvest cylinder that carries the
rotors (DECISIONS [2026-08-25]). It is a fixed config constant,
`cone_slope_deg = 22.0` (NR-049, 41 sites), not a gene.

**26, the 10 seconds.** No, the 10 s is not startup from stopped. The
cold protocol settles the machine to its operational state first. That
settle takes about 6 s simulated and 150,000 steps. Then one combined
relax plus window run of 10 s plus 40 s follows (NR-025,
`src/objective_evaluator.jl:799-892`). The 10 s relax flushes the
settle to run transient.

**27, the 40 seconds.** Yes. The 40 s is the measurement window after
the 10 s relax. Power samples land at 1 Hz inside it. tail5 reads the
last five samples, 35 to 40 s. The stationarity gates run inside the
window (NR-015, NR-025).

**31, why one load.** The campaign pins one k of 2.24 N m per rad per s
squared for all 930 evaluations. `K_MPPT_5KW_HONEST` sets it at
`scripts/run_v13_5kw_masslift.jl:158` (NR-015). The value came from the
seed sweep (NR-047).

One regime keeps every window comparable across candidates. The fixed k
also couples radius to TSR (draft 290-293). No second load profile ran.

**35, spins up to what.** At k 1.0 the seed settles at 17.6 rad/s, tip
about 85 m/s, near the 100 m/s ceiling. The rejected k 0.5 row read
19.14 rad/s under the power floor (NR-047, tip forms from the runner
comment).

**36, the tip-speed ceiling value.** 100.0 m/s.
`TIP_SPEED_CEILING_MPS` holds it at `src/objective_evaluator.jl:103`.
It is an instrument sanity bound, about 2.3 times the 44 m/s design tip
speed at ideal TSR 4 and 11 m/s. It is not a material law. It applies
to every ring rim and rotor tip (`:427-437`).

**39, why twice the nominal load.** The transmission rings bind at
(Q max, T min). The torque helix force reads about Q squared times l
over n squared times T times r cubed. So it peaks when torque spikes at
low tension. Peak wind is benign: high tension, capped torque.

The worst transient is the generator load step. The team bounds it at
twice the nominal k. Operational decision excludes the 3x e-brake
decision. Twice keeps twist at 50.8 degrees under the 78.8 degree
limit. Three times reaches 94.8 degrees past it.

The lull is benign because the constant-tension lifter holds the line
floor at about 710 N per line at rated. Source: plan
`2026-09-06-closed-form-beam-sizing.md` section 5, NR-048.

**41, is the spin-up the refusal reason.** Yes. The record states the
reason: easing k spins the rotor up at 25 m/s to 87.9 degrees of
hub-segment twist past a 78.8 degree collapse limit on that segment
(NR-048, DECISIONS [2026-09-06]). Draft 344 and 345 print the pair
without the causal link. Make the link explicit.

**46, why the step follows the shortest sub-segment.** The step reads
dt = min(4e-5 s, 4e-5 s times sqrt(L_min over 0.5 m) over 1.5). The
winner reads 2.899e-5 s (NR-024).

The semi-implicit Euler step must stay under the natural frequency of
the shortest sub-segment. That frequency grows as 1 over sqrt(L). The
geometric taper can make ground-end segments much shorter than the
0.5 m that calibrated the base 4e-5 s. At the base step those positions
destabilise into NaN (`src/initialization.jl:565-596`).

**48, the over-power charge size.** 5.0 kg per excess kW squared. The
form reads 5.0 times max(P_score minus 5.0, 0) squared.
`W_OVERPOWER_KG_PER_KW2` holds the weight at
`src/objective_v12.jl:114`, the form at `:153-154`. One kW over adds
5 kg. The winner charged 0.4933 kg on P_end 5.314 kW (NR-046 closure).

**49, the utilisation charge size.** 20.0 times (2.5 over FoS_min)
squared. `W_UTILISATION_KG` holds the weight at
`src/objective_v12.jl:116`, the form at `:165`. It reads 20 kg at the
floor, 5 kg at FoS 5, and 0.5577 kg at the FoS 14.972 of the winner.

**50, how the penalties add.** All three add to the airborne mass.
The form reads fitness = mass plus over-power plus over-twist plus
utilisation (`appropriate_mass_fitness`, `src/objective_v12.jl:167`).

The evaluator then adds two terms. One is the stationarity term, 10.0
times max(0, swing minus 0.20). The other is the overtwist term, 1.0
times (r over (1 minus r)) squared
(`src/objective_evaluator.jl:1193-1207`). The DE minimises the sum in
kg-equivalent.

**51, is the ceiling excess penalised.** Yes, quadratically, by the
same form as 48. The `penalize_ceiling` knob reads only v12_fitness,
which this campaign does not use. The live objective is
`appropriate_mass_fitness` (`run_v13_5kw_masslift.jl:266`), and it
always charges the excess. The winner charge reads 0.4933 kg.

**52, what the 1e-6 floor relates to.** It is the denominator of the
over-twist charge. The code reads margin = max(1 minus r, 1e-6) with
r = min(twist_ratio, 1) (`src/objective_v12.jl:160-161`,
`src/objective_evaluator.jl:1207`). It stops a divide-by-zero when the
worst segment sits exactly at the crossing limit.

**53, is the scoring based on that.** Yes. The soft twist charge 1.0
times (r over (1 minus r)) squared rides on that ratio. At r to 1 the
ratio reads one million and the squared charge one trillion kg. The
charge prices a design at the limit out. The hard twist gate rejects it
outright anyway (NR-046, NR-052).

**54, the clearance gate and multi-rotor designs.** The gate reads the
outer tip of the lowest active rotor. That tip is the absolute tip
radius, ring radius plus blade tip offset. The fix landed 2026-08-26
because the old formula over-counted by the ring radius and the gate
never bit.

The floor reads MIN_CLEARANCE = 1.5 m at 30 degrees elevation and 1.0 m
ground offset (`run_v13_5kw_masslift.jl:76,213-218,254-257`). Rotor
count 1, 2 or 3 hangs lower rotors down the shaft, so multi-rotor
candidates hit the gate more often. The campaign carries 110
clearance_reject rows (NR-002). The record supports the gloss from Rod.

**67, is the twist a shaft total.** No. The 87.9 degrees is the twist of
the hub segment itself, against a 78.8 degree crossing limit on that
segment. Every segment checks its own limit. The limits of the winner
read S1 to S4 98.86 degrees and S5 92.64 degrees (NR-022). The five
segments do not sum to one shaft limit.

**82, did the record discuss why.** Yes, the record holds it and the
draft does not. The 22 degrees is the cone bound from Tulloch (same pin
as 21). It runs as a fixed config constant, not a gene. Draft 838 says
a later campaign can vary it without saying why the code fixes it.
Point 838 at the sentence that closes 21.

**84, what longer and broader mean.** Longer means more than 930
evaluations. The count reads 3 islands times 310 (NR-001). Broader
means wider gene bounds. The campaign box is tight around the S2-fold
seed. Broader also means a longer genome.

The R7 drop removed four free beam genes: Do_top, t_over_D, beam_aspect
and Do_scale_exp. v11 dropped the legacy x15 k slot. The live genome is
the R7 canonical ten slots (DECISIONS [2026-09-10]:1718-1720).

**85, longer shafts as a clearance remedy.** Supported by the gate
geometry. Clearance reads tip altitude. At fixed elevation a longer
shaft raises every ring, so length is a clearance lever.

The recorded length screen at 21.2 and 25.0 m failed the power floor
pre-fold, not clearance (NR-027). The sentence can read "or by flying
systems longer than 18.8 metres."

**87, the blade-root check and the bridles.** The gate set has no
blade-root check. The gates are annulus, Betz, clearance, beam buckling
FoS, torsional FoS, tether tension FoS, twist crossing, rope break, tip
speed, and stationarity.

The blades are rigid bodies with no flap term. So the model never
computes root bending. The model carries the gold lift bridles, lift
bearing to rotor, fixed length. It carries no tether-to-blade bridle
(the section 6.1 block).

The alternative from Rod is a tether-to-blade bridle that carries the
tip-down load and removes the root shear case. That member sits outside
the model today too. Both paths are model additions. The next-step item
can name both.

**91, is the expansion rotor introduced.** No. The draft never defines
it. The term first prints at the section 4 defect table (draft 925) and
in section 5 (draft 1051).

The source definition: an expansion rotor is a banked-blade rotor whose
blade lift resolves into a radial outward-spreading component and an
axial thrust component. It replaces the spreading job of the passive
compression ring (`src/expansion_rotor.jl` header).

One caveat for section 5: the full expansion force model is not live in
the campaign. The live model applies the bank derate cos to the 2.65 to
the disc (CONTEXT.md line 200). "Ships with tests" is accurate. "Can
study expansion-class machines" should carry the not-yet-wired caveat.

**94, what win means.** Win means replace-if-not-worse in DE selection.
The trial replaces the parent only when the score of the trial is not
worse (`run_v13_5kw_masslift.jl:362`). The objective is kg-equivalent
mass plus penalties. It has no cost or commercial term (draft 1183).

So "the scale where multi-rotor machines win" overclaims. "Score better
under the modeled objective" is the true claim.

**96, the beam diameter in the genome.** The draft never mentions it.
The counts read 0 hits for beam diameter, Do_top and t_over_D. The
record: four beam cross-section genes were free DE dimensions until R7
(2026-09-10) dropped them. A free beam OD let the 5 kW winner land
6.2 mm transmission rings at true FoS about 1.2. The per-window FEA was
slow.

The closed-form solve now pins t_over_D = 0.055 with the wall floor
(DECISIONS [2026-09-10]). A section 6 sentence can say a later campaign
may restore a free beam diameter.

**99, the stacked-system claim.** Rod is half right, and the model shows
which half. The phase-lag reversal is kinematic. It does not change with
tension.

What stacking reduces is the response magnitude. The lateral restoring
stiffness of a rotor on the tether scales with the tension above it.
The T_above per ring in the model carries the thrust of every rotor
above (`src/objective_v10.jl:583-607`).

So the same tilt side force displaces a stacked rotor less. The load
relief is a smaller share of a shaft whose moment capacity rises with
tension (draft 1127). The sentence should say the unintended steer
shrinks with stacking, not that the off-axis phase relation disappears.

## Status

This seat commits nothing to the draft. The tracked draft on disk reads
`5108e6d1` (G6) per the last disk read at this seat, 1299 lines and
10,674 words. The G7 and batch-1 patches of the author sit staged. This
seat touched no draft bytes. The 26 pins are ready for the prose pass
of the author.
