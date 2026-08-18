# F7 — prose: "The census" (why 2,784 evaluations were rejected)

An optimiser that only reports its winners is a salesperson. This figure is
the ledger: every one of the 928 evaluations in each 5 kW campaign, sorted
by what the evaluator said about it. Four verdicts exist — `ok` (the design
survived the window), `clearance_reject` (it did not clear the ground),
`reject` (it stalled, failed its power window or its FoS), and
`reject_twist` (the chain twisted past its crossing limit).

The first thing to notice is what dominates. In every campaign roughly
two-thirds of all designs evaluate `ok` — 663 of 928 at 18 m, 585 at 21.2 m,
673 at 25 m. The search space is not hostile; most genomes are at least
runnable. Of the rejections, the largest single cause is ground clearance —
226 at 18 m, 279 at 21.2 m — designs that fly, but not high enough. The
optimiser spends most of its search scraping the 1.5 m minimum-clearance
gate, which is precisely the safety constraint a real rig must respect:
the machine that wins is the one that survives being near the ground.

The second thing to notice is the 25 m column. General `reject` triples
(35 → 95) while clearance rejections fall (226 → 151) — at 25 m the chains
fail for other reasons first: stall, power windows, structure. The twist
rejections stay tiny everywhere (4, 10, 9) — not because twist is rare,
but because the corrected model's gates catch most bad designs before the
twist detector gets a vote.

The census is the argument that the three winners were found by a search
that was actually looking: 2,784 evaluations, 1,921 ok, and the envelope's
shape — clearance first, then stall — visible in what the search had to
fight.
