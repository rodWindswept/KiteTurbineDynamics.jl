# Room response: the caption leads and the closure records (2026-10-14, figures seat)

**Status** LANDED. Two routed passes in one landing: the F-VALUE closure
records for the levers family, and the round-3 caption leads with the
ring gate line. **Seat** figures-images-diagrams. **Read at** `2074a5d`.

## 1. The closure records (aero-validator route)

- The figure-map cells for rows 20 and 21 take the closure: the
  re-census at `7329191` closes F-VALUE on the fix commit (`d6d4db9`),
  zero defects. The cells next read the section 3.4 fold and the
  pointers, then the visual pass by Rod.
- The two kit rounds lines take the same closure. The retired "fresh
  read rides" lines are gone from both SPECs, and the R3 lines now hold
  the visual pass alone.
- Map delta v27 records the closure.

## 2. The caption leads (routing parts 9 and 10)

- Ring utilisation: both tiers open with the governing ring. The
  technical tier leads "The hub ring R6 governs the structural check at
  FoS 15.033. All other airborne rings hold much larger margins
  (NR-021)." The gate line lands: the unit fail boundary at FoS 1
  against the campaign gate at FoS 2.5 or above (NR-015).
- Twist limit: both tiers open with the limit result. The technical
  tier adds "S1 carries the least segment torque margin, 2.03
  (NR-040)."
- Evolution strip: both tiers open with the objective fall, 36.109 to
  27.364 kg-equivalent (NR-006, NR-005).
- The kit notes take the new cites: NR-015 on the ring rows table,
  NR-040 on the twist rows table, and one caption-lead entry per kit.
  The two SPEC caption plans take the new leads and a delta line.
- Map delta v28 records the landing. The 3.5 render deltas (the ring
  axis treatment and the twist legend and label fixes) stay queued at
  this seat.

## 3. Surfaces and checks

- Text only. No render bytes move on any kit. The diff is ten markdown
  files: the three caption files, the two register notes, the two
  SPECs, the two levers SPEC rounds lines, and the map.
- `scratch/fig_cl_edit.py` applies the pass.
  `scratch/fig_cl_check.py` and its log assert every landed string and
  every retired string.
- STE rc=0 on all ten touched files.
- The ring lead prints the capture form 15.033 (NR-021), not the report
  headline 15.0 (NR-009). The plate draws capture values only. One
  line flips the lead if the room wants the headline form there.

## Handoffs

- @author: the caption text sits in the kits for the rebuild. The fold
  and the pointers are ungated from the figures side.
- @aero-validator: the closure records take your route. The map cells
  and the rounds lines now read the closure.
- @science-writer: the consistency sweep can key on the new caption
  forms. The reading stands on the same rows.
- @science-validator: the 3.5 checker seat on the render deltas when
  they come.

---

figures-images-diagrams, 2026-10-14.
