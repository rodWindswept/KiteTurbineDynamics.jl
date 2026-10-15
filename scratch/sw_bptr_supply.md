# Supply: the back-pointer term row (science-writer seat)

**Date** 2026-10-15. **Target** `docs/reporting/glossary-candidates.md`.
**Base pin** md5 `d452554f3b87875845b3cedb6d1b62b1`, the blob at HEAD `b9a52e2`.
**Candidate** md5 `c0d82058355ce53118d675ed30162b43`.

## 1. The landed row (section 2, after the collapse-margin row)

| destructive resonance | The shaft failure mode of an earlier gain sweep. The twist ripple grows and does not settle. The shaft snaps between states, and the power falls to zero in intervals. The report names the term for that earlier round only. That round and this campaign share no number. | `docs/NOTES_MPPT_TWIST.md` section 3, the 2026-09-25 Tulloch plan section 9 | supply |

**The gap the row closes.** The v0.56 draft prints the term once, in the
load-block back-pointer at section 2.2.2. The candidates file carried no entry
for it. The glossary contract holds that a short term with no entry blocks
release.

**Grounds, read at the tip.**

- `docs/NOTES_MPPT_TWIST.md` section 3, "The 4x Instability Cliff is Invisible", reads: "At k_mult = 4x, the TRPT shaft enters a destructive resonance regime". The section carries the twist ripple, the slip events, the periodic snapping and the power drop.
- `docs/plans/2026-09-25-trpt-tulloch-criterion-correction.md` section 9 lists the same failure as a cause of its own, beside the wind-up.

**The value slot.** The row carries no number. The gain figure stays a binding
slot for Track D. The room ruled the printed sentence carries no digit, so the
entry must not smuggle one in.

## 2. The delta entry (v19)

```
- **v19 (2026-10-15):** the back-pointer term lands at the science-writer seat.
  Section 2 takes the destructive-resonance row, from the v0.56 load-block back-pointer
  (`docs/NOTES_MPPT_TWIST.md` section 3, `docs/plans/2026-09-25-trpt-tulloch-criterion-correction.md` section 9).
  The row carries no value, so the gain figure stays a binding slot for Track D.
  The status line takes v19, from a header that the v18 pass left at v17.
  The bow row does not land and waits on a ruling from the founder.
  No other change.
```

**The status-line miss.** The header stood at `PREP v17` through the v18 pass.
The v18 delta entry landed and the header token did not move. The v19 delta
records the move. No past entry changes.

## 3. STAGED, NOT LANDED: the bow row

The founder word on the bow call decides this row. This seat holds the text
ready. No bow row lands until that word arrives.

| bow | The lateral sag of the shaft axis off the design line, in the tilted plane. The perpendicular part of the hub weight causes it. The stack does not move sideways, because the lines reorient at near-constant length. The report holds it as an output, not a constraint. The settle calculation and the run must agree on it. | DECISIONS [2026-09-15] ruling 2, `docs/agents/physics-topology.md` | supply |

Section 7 guard, staged with the row:

| Do not write | Write | Ground |
|---|---|---|
| "bow" as a sideways move of the ring stack | bow: a line rearrangement at near-constant length | DECISIONS [2026-09-15] ruling 2 |

**Grounds and the hard bar.**

DECISIONS [2026-09-15] ruling 2 reads "Bow is an output, not a constraint." It
names the bow as sag, and it bars the reading of the bow as a translation. A
sideways stack move is very stiff, and the real bow is a line rearrangement.

The same ruling bars the September figure as a printed result, and it names the
figure a rigid-tilt estimate. The relaxation probe returned 0.116 to 0.776 m and
did not converge, so the estimate does not serve as the report value.

The same ruling fixes the disagreement rule. A settle/ODE bow disagreement is a
re-initialisation or force-scaling bug, not a design question.

**The value slot for the bow row.** The row carries no value. The probe at the
aero seat supplies the winner read, and the register row signs it.

## 4. Evidence set

- `scratch/sw_bptr_fold.py` and `.log`: the assertion-guarded fold, 19 checks, 0 fail.
- `scratch/sw_bptr_check.py` and `.log`: the independent checker, 27 checks, 0 fail.
- `scratch/sw_bptr_ste_probe.py`: the per-sentence offender attribution.
- `scratch/sw_bptr_base.md` and `scratch/sw_bptr_new.md`: the pinned base and candidate.
- `scratch/sw_bptr_off_base.txt` and `scratch/sw_bptr_off_new.txt`: the offender sets.
