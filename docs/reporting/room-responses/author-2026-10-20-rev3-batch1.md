# Author seat: founder return 3, batch 1 (2026-10-20)

Status: two rulings, one measured batch, one optional hunk held.
The tracked draft on disk reads `5108e6d1` (G6) and stays dirty.
Every state below starts from that file and applies with `patch -p1` in order.

## 1. The 168 ruling

**Ruling.** Delete the target clause.
The sentence reads: "The machine plates show the blade leaning downward."

State `b9d01717`, 1299 lines and 10,670 words.
STE reads 22 at 0.21, em dash 0.
The patch is `scratch/au_rev3/au_g7_168.patch`, 11 lines and one hunk.

**Why the old clause dies.**
Rod answered the open question directly.
The blade tip aims at a point on the TRPT section line.
It does not run all the way down to the next ring.
That run costs bridle line drag.
The plate draws the lean and nothing else.

`machine-winner-hero.jl:262-263` sets the drop from `tandeg(abs(bank))`.
`:282-283` places the two blade ends at `+shaft*din` and `-shaft*dout`.
Both offsets are axial only.
For the winner the tip drops 0.1294 m against a mean ring gap of 3.76 m.
That is 3.44 per cent of the run.
The old clause names a target that the plate does not draw.

**Why the proposed replacement dies.**
Fig proposed "toward the TRPT line below".
That form fails twice.
First, the plate has no radial component.
A point on the axis sits at radius zero.
The plate moves the tip along the shaft axis, not toward it.
Second, the phrase collides with the register of this draft.

`TRPT line` already means a tension rope on four lines: 153, 161, 783 and 784.
A reader who met the term at 153 reads the phrase as "toward the rope below".
That is the fault the room killed at 1169.
The nearest antecedent would be the wrong member.
The measurement from Fig is right, and the verb ruling stands.
Only the target clause fails.
`91583e8e` is the rejected state, kept as evidence.

## 2. The aiming-point fact

The answer from Rod carries more than a target.
The bridle aims at a point on the section line, not at the ring.
The reason is bridle drag.
No sentence in the report says so.

Proposed sentence, after the first bridle sentence in section 6.1:

> It aims at a point on the shaft axis below the rotor, not at the ring, to cut bridle drag.

State `1c2c6acd`, 10,763 words, STE 22 at 0.21, em dash 0.
The patch is `scratch/au_rev3/au_a1_b.patch`.
Two word choices are deliberate.
The draft already says `shaft axis` at 603, and `section line` reads 0.
`TRPT line` is unavailable, for the reason in section 1.

**This hunk is not applied.**
It enters the blessed paragraph, so it needs a nod from Rod.
The release does not depend on it.

## 3. Batch 1: 12 of 41 comments

1. **#3.** The abstract glosses "physics era" as one model version, and defines the bank derate.

2. **#4.** The bridles read as real field practice, and the model leaves them out.

3. **#5.** The lifter kite can modulate tension, and the report treats that ability as an assumption.

4. **#6.** A feasible candidate now sits "inside the gated performance bounds".

5. **#10.** Rigid wings are "more efficient, but brittle and more costly".

6. **#11.** The third split reads as mechanical force transmission.

7. **#13.** The ground station now holds the shaft in a wheel and converts the power.

8. **#16.** Section 2.1 loses its three forward uses of "gene".

9. **#16.** The inactive-slot sentence moves to 2.2.1, after the genome definition.

10. **#17.** The sizing sentence names what sets the radius: power, wind speed and power coefficient.

11. **#18.** Twelve definition uses of "reads" become "is" or "gives".

12. **#19.** The blade now runs from `r_hub` to `r_rotor`, and the part outside the ring is the overhang.

13. **#22.** The settling sentence carries both loads: generator load and line drag.

The comment IDs in this batch are 3, 4, 5, 6, 10, 11, 13, 16, 17, 18, 19 and 22.
Comment 16 takes two edits, so the list holds 13 lines for 12 comments.

State `265f90d5`, 1303 lines and 10,743 words, STE 22 at 0.21, em dash 0.
All five counters match G7.
The patch is `scratch/au_rev3/au_a1_front.patch`, 133 lines and 12 hunks.
Both patches ran on a fresh copy of the disk draft.
They reproduce `265f90d5` byte for byte at 10,743 words.

**Two build consequences.**
The abstract gains a paragraph break before "The search is a screen".
That holds the long-paragraph count at 12.
The team measured the section 6.1 cut on G6 at 153 words.
That figure now sits on a moved base.
The cut must be rebuilt from this state or later.

## 4. What is left: 29 comments

**Prose, mine, next batch.** Eighteen comments, 29 to 101.
The IDs are 29, 30, 33, 34, 42, 43, 59, 60, 68 and 69.
The rest are 70, 72, 73, 86, 88, 89, 98 and 101.

**Needs one pinned fact.** 32, 40, 47, 63, 65 and 71.

Each of those six needs a sentence that the draft cannot supply.
They are the effect of the fixed load on the ideal tip-speed ratio (32).
Easing k in high wind is the second (40).
The name of the line-failure class is the third (47).
The meaning of an extension step and of 0.422 m is the fourth and fifth (63, 65).
The reason for the three movers is the sixth (71).

**One-word calls for Rod.** 12, 28, 44 and 45.

These are terminology, not prose.
Is the blade term `kite blade` (12).
What does "shorter could" mean at the window sentence (28).
Do `line` and `ring` become `beam` and `ring beam` (44, 45).
A beam rename would run through the structural register and is wider than this lane.

**Reclassified.** 83.

Rod asks for a strip that prints power and mass.
That is a plate change, and it belongs to the figures seat.

## 5. One correction to this receipt

The first version of this receipt gave 1299 lines for `265f90d5`.
That figure belongs to G7.
Comment 16 removes two lines and the batch adds six, so the batch-1 state holds 1303 lines.
The science-writer seat caught the error.
No hash and no word count moves.

## 6. The section 6.1 cut: the lock lost its antecedent

The cut deletes the four report lines.
The lock string `Until they run, the rotor phase lag stays a free parameter.` survives verbatim.
Its plural antecedent does not.
The only test sentence left reads "A BEM sweep from 0 to 10 degrees of tilt is the test".
That sentence is singular.
So "they" now points at nothing.

The room has killed three states on this fault class: F3, G4 and the bridle rule at 1169.
This is the fourth, and it sits inside the blessed section.

**Ruling.** Name the two tests.
Both runs already sit in the base text.
The sentence becomes:

> A BEM sweep from 0 to 10 degrees of tilt and a lateral-mode check are the two tests.

The paragraph holds at six sentences.
The lock keeps its place at the head of paragraph 2, and the STE count holds at 22.
The antecedent is unique: paragraph 2 carries no other plural noun.

State `d54d6ae4`, 1222 lines and 10,117 words, STE 22 at 0.22, em dash 0.
All counters match cut v2.
The patch is `scratch/au_rev3/au_cut_v3_tests.patch`, one hunk and one line.
All five lock strings still read one hit each.

**Comment 100 drops 98.** The cut leaves no slot for a someawe pointer.
It returns only with a `references.bib` entry and a sentence, in that order.
This receipt records the drop so that a later pass cannot call it lost.

**Comment 99 rides** in the science-writer patch, and that sentence rests on the aero pin.
**Comment 95 rides** in the same patch and touches none of these hunks.

## 7. The aiming sentence is withdrawn (Rod, 2026-10-20)

Rod killed the noun, not the fact.
A bridle bifurcates from a line.
No bridle can bifurcate from the shaft axis, because the shaft axis is a virtual centreline.
The draft uses `shaft axis` for one job only, at 599: it bows off its design line.

Section 2 above chose that noun to match a term already in the register.
`section line` read zero hits, so reuse bought consistency and cost the physical object.
That is the fault this seat has held other desks to, committed here.

The corrected form keeps Rod's own words:

> The blade tip aims at a point on a TRPT line below the rotor.
> It does not run down to the next ring. That run costs bridle line drag.

`TRPT line` is the draft's physical noun for a rope of the shaft: 150 holds the
TRPT lines apart, and 158 counts the TRPT line attachments around the ring.
A bridle can bifurcate from a rope, so the sentence is now true of a real member.

One correction to section 1's rejection of Fig's form.
Fig proposed "toward the TRPT line below".
This seat rejected it partly because the phrase collides with the draft register.
That collision is with a rope, which is the right class of object.
The rejection stands only on the other ground: the hero plate draws no bridle at all.
The credit for the target belongs to Fig.

One question is open, and this seat will not invent the answer.
The plate drops the tip 0.1294 m against a mean ring gap of 3.76 m, and the blade
line runs outward and down.
Does the bridle leave the tip along that same line to its anchor on the TRPT line,
or is the blade lean set independently of the anchor point?

`scratch/au_rev3/au_a1_b.patch` is rejected.
It stays on disk as evidence, the way `91583e8e` was kept.
The release does not depend on it.
