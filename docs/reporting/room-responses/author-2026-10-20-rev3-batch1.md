# Author seat: founder return 3, batch 1 (2026-10-20)

Status: two rulings, one measured batch, one optional hunk held. The tracked draft on disk is `5108e6d1` (G6), dirty. Every state below starts from that file and applies with `patch -p1` in order.

## 1. The 168 ruling: the target clause goes, and the replacement fails twice

**Ruling.** Delete the clause. The sentence reads:

> The machine plates show the blade leaning downward.

State: `b9d01717e7fd5e4f0f9ba0baaaf5f42e`, 1299 lines / 10,670 words, STE 22 at 0.21, em dash 0. Patch `scratch/au_rev3/au_g7_168.patch` (11 lines, one hunk, one line changed).

**Why the old clause dies.** Rod answered the question directly: the blade tip aims at a point on the TRPT section line, not all the way down to the next ring, because that run costs bridle line drag. The plate draws the lean and nothing else. `machine-winner-hero.jl:262-263` sets the drop from `tandeg(abs(bank))`, and `:282-283` places the two blade ends at `+shaft*din` and `-shaft*dout`. Both offsets are **axial only**. For the winner the tip drops 0.1294 m against a mean ring gap of 3.76 m, which is 3.44 per cent of the run. "Toward the ring below" names a target the plate does not draw and the machine does not use.

**Why the proposed replacement dies.** Fig proposed "toward the TRPT line below". It fails twice.

1. The plate has no radial component. A point on the axis is at radius zero; the plate moves the tip along the shaft axis, not toward it. The phrase claims a convergence the geometry does not contain.
2. Worse, it collides with the draft's own register. `TRPT line` already means a tension rope in this report, on four lines: 153 "hold the TRPT lines apart", 161 "TRPT line attachments", 783 and 784 "TRPT line count". A reader who has met the term at 153 reads "toward the TRPT line below" as "toward the rope below". That is the same fault the room killed at 1169: a true-sounding clause whose nearest antecedent is the wrong member.

Fig's measurement is right and his verb ruling stands. Only the target clause fails. `91583e8e` is the rejected state, kept as evidence.

## 2. Rod's aiming-point fact, and the one place it belongs

His answer carries more than a target. The bridle aims at a point on the section line, not at the ring, and the reason is bridle drag. No sentence in the report says so.

**Proposed, one sentence, after the bridle's first sentence in section 6.1:**

> It aims at a point on the shaft axis below the rotor, not at the ring, to cut bridle drag.

State: `1c2c6acdd9cc723d4381e887bbd1c09b`, 10,763 words, STE 22 at 0.21, em dash 0. Patch `scratch/au_rev3/au_a1_b.patch`.

Two word choices are deliberate. The draft already says `shaft axis` at 603, and `section line` reads 0, so the sentence uses the register the report owns. `TRPT line` is unavailable, for the reason in section 1.

**This hunk is not applied.** It enters the blessed paragraph, so it needs Rod's nod. The release does not depend on it.

## 3. Batch 1 of the AUTHOR lane: 12 of 41 comments, measured

| # | Comment | Change |
|---|---|---|
| 3 | these concepts need introduced | "physics era" glossed as one model version; "bank derate" defined as a cut in rotor power as the blades bank |
| 4 | field turbines use outer stiffening bridles | the bridles are now named as real field practice, and the model leaves them out |
| 5 | lifter kite can modulate tension | the ability is stated, and the report's treatment of it as an assumption follows |
| 6 | within gated performance bounds | "under the model and gates" becomes "inside the gated performance bounds" |
| 10 | but brittle and more costly | brittleness added to the rigid-wing comparison |
| 11 | mechanical | the third split is named as mechanical force transmission |
| 13 | shaft to generator | the wheel on the ground station and the conversion to electrical power are stated |
| 16 | genome not yet introduced | the inactive-slot sentence moves to 2.2.1, where the genome is defined; section 2.1 loses its three forward uses of "gene" |
| 17 | simpler blade-size wording | the sizing sentence now says what sets the radius: power, wind speed and power coefficient |
| 18 | does "reads" mean "is set at" | twelve definition uses of "reads" become "is" or "gives"; "reads" stays for what the model outputs |
| 19 | how much is inboard and outboard | the blade now runs from `r_hub` to `r_rotor`, and the part outside the ring is named as the overhang |
| 22 | and line drag | the settling sentence carries both loads: generator load and line drag |

State: `265f90d5ec45f6ca3e5f5e418e6da14e`, 1299 lines / 10,743 words, STE 22 at 0.21, em dash 0. Counters identical to G7: passive 5, long_sentence 3, nominalization 1, contraction 1, long_paragraph 12. Patch `scratch/au_rev3/au_a1_front.patch` (133 lines, 12 hunks).

Verification: both patches applied to a fresh copy of the disk draft with `patch -p1`, in order, reproduce `265f90d5` byte for byte, 10,743 words, and the result is identical to the measured candidate.

**Two build consequences.** The abstract gains a paragraph break before "The search is a screen", which keeps the long-paragraph count at 12. The section 6.1 cut was measured on G6 at 153 words; that figure now sits on a moved base and must be rebuilt from this state or later.

## 4. What is left: 29 comments, sorted by what each one needs

| Class | IDs | Count |
|---|---|---|
| Prose, mine, next batch | 29, 30, 33, 34, 42, 43, 59, 60, 68, 69, 70, 72, 73, 86, 88, 89, 98, 101 | 18 |
| Needs one pinned fact | 32, 40, 47, 63, 65, 71 | 6 |
| One-word call for Rod | 12, 28, 44, 45 | 4 |
| Reclassified to Fig | 83 | 1 |

The six source items are one sentence each and none of them can be written from the draft alone: the effect of the fixed load on the ideal tip-speed ratio (32), the consequence of easing k in high wind (40), the name of the line-failure class (47), what an extension step is and what 0.422 m measures (63, 65), and the reason for the three movers (71).

The four calls for Rod are terminology, not prose: whether the blade term is `kite blade` (12), what "shorter could" means at the window sentence (28), and whether `line` and `ring` become `beam` and `ring beam` (44, 45). A beam rename would run through the structural register and is wider than the author lane.

83 is not prose. Rod says the strip would be better if it printed power and mass; that is a plate change, and it belongs to the figures seat.
