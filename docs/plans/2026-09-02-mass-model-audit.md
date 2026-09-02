# Why the 5 kW winner is not trustworthy, and what we are changing (2026-09-02)

**Purpose.** This document explains, in plain language, why our last 5 kW
design search produced a result we cannot believe, what specifically went
wrong, and the decisions we are making so the next attempt is correct.  It is
written so a new person can read this one document and know exactly what is
wrong and what to do.  No shorthand; each idea is spelled out.

---

## 1. What happened, in plain terms

We ran a design search — a computer program that tries thousands of candidate
machine designs and keeps the best.  "Best" here meant "lightest that still
makes 5 kW and does not break".  The search finished and reported a winning
design weighing **9.6 kg**.

But when we checked the winner by hand, its weight is *less than physically
possible*.  A rough calculation of just the ring tubes (the circular frames of
the tower) says those tubes alone should weigh about **2.6 times more than the
winner claims for the entire tower**.  That is the warning sign.

What this means: the optimiser found a **loophole in how we estimate weight**,
and it exploited the loophole.  It did not find a real machine; it found an
imaginary one that our weight formula lets exist for free.

To be clear about what *is* and *is not* wrong:

- The **power check was real and passed** — the winner does genuinely make
  about 5.1 kW.
- The **strength check was real and passed** — the winner does not buckle
  (safety factor 17.6, above the required 2.5).
- The **weight estimate is what is broken**.  And because the optimiser's job
  is "find the lightest machine", a broken weight estimate means it found the
  lightest *imaginary* machine, not the lightest *real* one.

## 2. The two weight numbers, explained (9.6 kg vs 4.4 kg)

These are the same thing, measured two ways:

- **9.6 kg** is the "fitness" score the optimiser minimises.  It is the tower
  structure (rings, blades, cables, joints) **plus a fixed 5 kg lifting
  kite/rotor** that every design carries.
- **4.4 kg** is the tower structure **alone**, without that 5 kg lifter.

So `9.6 ≈ 4.4 + 5.0`.  They are not two contradictory answers; one includes the
lifter and one leaves it out.  (When we recompute it ourselves we get 4.6 kg
for the structure; the 4.4 vs 4.6 difference is a small mismatch between two
separate reporting tools, and it is tiny compared to the real problem below.)

## 3. Three bugs in how we estimate weight

The weight formula has three separate mistakes.  Each one, on its own, makes
the winner look lighter than it is.  Together they explain the whole problem.

### 3.1 There is no minimum tube size — the tower can become toothpick-thin

The tower rings are made of tubes.  The software sizes each tube by a rule
that makes tubes **thinner as you go down the tower**.  The rule was allowed to
run all the way down with no stop.

For the winning design, the bottom rings ended up as tubes **2.3 millimetres
wide with a 0.06 millimetre wall**.  That wall is about the thickness of a
human hair.  No such tube can be manufactured, and it would crumple instantly.
The optimiser exploited this: it made the entire lower tower nearly
weightless (5 rings × 3 grams each = 15 grams).

**What was ignored:** there was no rule saying "a tube must be at least this
thick".  We only limited the *ratio* of wall-to-diameter, not the absolute
size.

**Decision:** a tube's **wall thickness must be at least 2 mm** (Rod,
2026-09-02).  (See §6 for the full rule.)

### 3.2 The weight uses ONE average ring, instead of adding each ring up

To save effort, the software guessed the total ring weight by computing the
weight of **one average ring** and multiplying by the number of rings.  That
only works if all the rings are roughly the same size.  They are not.

For the winner, the rings are wildly different:

| ring | tube width | wall | weight |
|---|---|---|---|
| bottom rings (5 of them) | 2.3 mm | 0.06 mm | 3 grams each |
| top ring (1 of them) | 30 mm | 0.82 mm | 2.7 kilograms |

The "average" came out at 0.32 kg per ring, so the software said
`5 × 0.32 = 1.6 kg`.  Adding the rings up **individually** gives **2.7 kg** —
about 1.7 times more.  The average hid the fact that the top ring dominates.

**What was ignored:** the rings are not one size; the top ring is 900 times
heavier than a bottom ring.  Averaging erased that.

**Decision:** ring weight must be **summed ring by ring**, each ring priced at
its own diameter and wall.  No averaging.  (See §6.)

### 3.3 The joints where cables meet rings were counted as free

Where each cable attaches to a ring there is a metal joint (we call it a
"knuckle").  These joints have real weight, and there are many of them — one
at every cable-on-ring meeting point.

The software counted the knuckles on the **blades**, but **forgot to count the
knuckles where the cables attach to the rings**.  So all those ring joints
weighed nothing.

**What was ignored:** the ring-to-cable joints.  For a design with 3 cables
and 6 rings, that is 18 joints, all free.

**Decision:** every ring-to-cable joint must be counted, using the **same**
joint-weight rule everywhere.  (See §6 and §7.)

## 4. The wake-blocking rule was applied in the wrong places (the inconsistency)

This is a different kind of bug — not weight, but **consistency**.

**Background.** When two rotors are stacked behind each other, the front rotor
takes energy out of the wind and the rotor behind it gets less wind.  We added
a rule for this: a rotor that sits behind another only gets **75% of the
power** it would get in clean air.  (We call this "wake blocking".)

**The bug.** The simulation runs in two steps:

1. A quick "settle" step that works out a sensible **starting spin speed**
   before the careful simulation begins.  It adds up the wind power on each
   rotor to guess the right speed.
2. The careful, slow simulation that then runs the machine in detail.

We applied the 75% wake-blocking rule in the **careful simulation (step 2)**,
but we **forgot to apply it in the quick settle step (step 1)**.

So the settle step thinks the rear rotors get **full** wind (more power), and
it sets the starting spin speed **too high**.  The careful simulation then
starts from that too-high speed and **slowly winds down** to the correct slower
speed.

**What this looked like:** one design appeared to make 7.45 kW in the early
seconds and only 5.37 kW later — not because anything was wrong with the run,
but because it started too fast and was still winding down.  A design with a
single rotor is *not* affected (it is not behind anything, so there is no
wake rule to apply); this only bites machines with more than one rotor.

**Decision:** apply the 75% wake rule in the **settle step and the careful
simulation**, using exactly the same value from exactly the same place, so the
two agree.

## 5. The new fitness score — what "good" now means

The old score was "lightest, as long as it makes at least 5 kW and does not
break".  That alone lets the optimiser find machines that are too light to be
real (the weight loopholes above) and machines that are barely safe.

The new score keeps "light" but adds **"appropriate and safe"** (Rod,
2026-09-02):

1. **Light** — minimise mass (still the main goal).
2. **Not over-powered** — a machine that makes *more* than 5 kW is wasting
   material we do not need.  Going over 5 kW should be **penalised**, so the
   target is "close to 5 kW, not above it".
3. **Not near twist-collapse** — a machine that is close to twisting too far
   (the cables winding past their safe angle) should be **penalised**.  We want
   a comfortable margin away from overtwist, not a machine parked on the edge.
4. **Not near the strength limit** — a machine whose rings are close to their
   buckling limit (safety factor just above 2.5) should be **penalised** too.
   High "beam utilisation" (little safety margin) is unsafe and should cost.

In short: **light, ~5 kW (not more), with a comfortable safety margin in both
twist and strength.**  The exact penalty strengths are to be decided; the shape
is: small penalty far from the limit, growing penalty as you approach it, and
a hard reject if you cross it.

## 6. The new weight rules (hard requirements)

1. **Minimum tube wall thickness = 2 mm.**  No tube may have a wall thinner
   than 2 mm, no matter how small its diameter.  (This also forces a minimum
   sensible tube size, since a 2 mm wall cannot fit inside a 2 mm tube.)
2. **Ring weight is summed ring by ring.**  Each ring's weight is computed from
   its own diameter, wall, and length, then added together.  No single
   "average ring" shortcut.
3. **Every ring-to-cable joint is counted.**  Each knuckle weighs the same
   everywhere (one shared rule), and they are all included.

## 7. The consistency rule (one source of truth)

We keep getting caught out because **the same physical number is computed in
several different places with slightly different rules, and they disagree**.
The ring weight was averaged in one place and would be summed in another; the
knuckles were counted in some places and not others; the wake rule was applied
in the simulation but not the settle step.

The rule going forward: **each physical quantity is computed in exactly one
place in the code, and every other part of the software uses that one place.**
Concretely, this means:

- one ring-weight function (used by the DE score, the gate, and any report);
- one knuckle-weight rule (same value, same count, everywhere);
- one wake-blocking value (same 75% power rule, applied in settle and simulation
  alike).

Where a quantity is already duplicated, the first task is to delete the copies
and point everyone at the single source.

## 8. The next starting designs ("seeds")

The next search must start from **safe, slightly heavier** designs, not from the
suspicious light corner (Rod, 2026-09-02).  A good seed is one that is clearly
real and clearly safe even if it is not the lightest, so the optimiser explores
sensible territory rather than re-finding the loophole.  Concretely: thicker
tube walls (≥ 2 mm), a modest hub radius, enough cables that the geometry is
not degenerate, and a comfortable strength margin well above 2.5.

The specific seed values are a follow-on task; the principle is "start safe,
optimise toward light" rather than "start at the edge".

## 9. What to do, in order (for the new person)

1. Fix the weight formula (§6): minimum 2 mm wall, per-ring summing, all
   knuckles counted.
2. Fix the wake rule in the settle step so it matches the simulation (§4).
3. Rebuild the fitness score with the appropriateness + safety penalties (§5).
4. Apply the one-source-of-truth rule to ring weight, knuckle weight, and wake
   blocking (§7).
5. Pick new, safer seed designs (§8).
6. Re-run the search.
7. Re-check the winner the same way we did here (does its weight pass a
   by-hand sanity check? is its power close to 5 kW, not over? is it safely away
   from twist and buckling limits?).
8. Only then re-baseline the slow acceptance tests.

## 10. Where each thing lives in the code

- Ring weight (the average + the bugs): `src/objective_evaluator.jl`
  (`build_system_from_v10`, search for "m_ring_design"); the total airborne
  weight: `src/expansion_analysis.jl` (`expansion_airborne_mass`).
- Knuckle weight: `src/trpt_optimization.jl` (`knuckle_mass_at_ring`,
  `OPT_KNUCKLE_MASS_KG`); note the DE's mass does NOT use it today — that is
  bug 3.3.
- Blade weight: `src/expansion_rotor.jl` (`expansion_blade_mass`), anchored by
  `M_BLADE_REF_KG = 0.420` in `src/parameters.jl`.
- The fitness score: `src/objective_v12.jl` (`mass_min_fitness` and the older
  `v12_fitness`).
- Wake blocking: `src/objective_v10.jl` (`design_from_vector_v10`),
  `src/ring_forces.jl` (the careful simulation), and `src/initialization.jl`
  (`settle_to_operational_state` — the settle step that is missing the rule).
- The winning genome and its re-check: `scripts/results/v13_5kw_masslift_len18.8_rotorcount/best_vector.csv`
  and `.../regate_verdict.md`.
- The design-search runner: `scripts/run_v13_5kw_masslift.jl`; the seed
  definitions: `scripts/compute_seeds.jl`.
- Previous handover: `handovers/handover-2026-08-28-rotorcount-campaign-complete.md`.
