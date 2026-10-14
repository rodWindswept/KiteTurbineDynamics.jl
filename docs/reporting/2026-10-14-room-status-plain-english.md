# Room status in plain English (2026-10-14)

**Status** PLAIN ENGLISH for Rod. **Written by** hermes. **Read at**
`dce5e61` (branch `bank-derate-cos2p65`).

The room writes its notes in shorthand. This page states the status of
2026-10-14 in plain English for Rod. Every line below traces to a room
record. Nothing here is a new claim.

## 1. The era call stays open

One question about the report stays open for now. Section 2.3 tells
how the team picked the load constant k = 2.24, from this campaign.
An earlier round of the same study ran on earlier machines. Should the
report also point back to that round? The earlier round includes the
case at four times the load multiplier. There the TRPT shaft enters a
destructive resonance.

The other choice keeps the section on this campaign alone. Nobody has
decided yet. Nothing is blocked by it. The phrase "as routed" means
the question stays where the room put it, and no ruling has moved.
Until the room makes the call, the report cannot cite the earlier
study.

## 2. The plates that wait on the visual pass

Three finished plates wait for the look by Rod before they go into the
report. Every number on every plate passed its check. In the room
notes, "user" means Rod.

### The k-basis plate (report section 2.3)

The plate shows how the team picked the load constant k for the whole
design search. It plots window mean power against k for the seed
machine.

- The k = 0.5 run makes 3.49 kW. It sits under the 5.0 kW power floor,
  so it counts as a reject.
- The heavy end levels off near 8.95 kW. More load buys almost no
  more power.
- The pick, k = 2.24, sits between the two ends. One load runs the
  whole search.

The text beside the plate carries the safety story on both sides. The
light end nears the 100 m/s tip-speed ceiling (about 85 m/s at k = 1.0). On the
heavy side the safety factor falls from 36.4 at k = 2.24 to 24.3 at
k = 3.0. The text also names the two retired anchors, 3.55 and 5.39.

### The Harris-3.5 pair (report section 3.3)

"Harris" names the outside review of the draft from 10 October. Rod
fed the draft PDF to a review bot while he was in Harris. Item 3.5 of
that review covers the figures. The pair is the two plates that answer
that item.

- The ring-utilisation plate. Every checked airborne ring sits far
  below its fail boundary. The hub ring R6 governs, at FoS 15.033.
- The twist-limit plate. All five shaft segments stay inside their
  limits at the winner. The smallest torque margin sits at S1, 2.03.

Both plates carry the item-3.5 fixes. The ring plate takes the log
axis and the corrected interaction form. The twist plate takes the
re-spaced labels and the binding-limit measure.

## 3. The safety close

The safety thread closes. The room finished the rope-break wording
work.

- Every live page now reads the detector form. The evaluator keeps the
  rope-break check armed across the relax and the window. The ruling
  limits break detection to the measurement window. A break there
  always rejects the design. An older wording could read as permission.
  The room added the correction beside it, and future quotes use the
  safe form.
- The review copy reads clean at v0.39. The full check ran 163 checks
  with no failures. The copy has since advanced to the v0.40 build.
  That build also reads clean, 164 checks.
- The aero-validator refreshed its handover page in the same update.
  That refresh is insurance. The storm over Lewis could cut the power.
  The next session then resumes from that page.

## 4. Short glossary

- **era call**: the open question about citing the earlier study
  (section 1).
- **k-basis plate**: the plate that shows how k = 2.24 was picked.
- **Harris-3.5 pair**: the ring and twist plates that answer item 3.5
  of the Harris review.
- **detector form**: the safe wording for the rope-break rule.
- **live surface**: a current page in the repo, not a historical
  record.
- **storm insurance**: a handover refresh done early, so a power cut
  cannot stall the work.
- **visual pass**: the look by Rod at a plate before it goes into the
  report.

The queue working rules now carry the same line. "Write anything Rod
reads in plain English. Keep the shorthand for internal notes."

hermes, 2026-10-14
