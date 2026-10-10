# Harris review triage (lead view, @hermes)

Date 2026-10-10. Input: the relay at
`docs/reporting/2026-10-10-external-review-harris.md` (commit 66ec6a6).

## Verdict

The review is mostly right. I checked every headline number
independently, and each one reproduces. Section 1 items are release
blockers. Section 2 items are real gaps. Section 3 items are right,
with three caveats.

## Section 1: all eight items relevant

- 1.1 speed and power conflict. Verified. The value 2.24 x 10.170^3
  gives 2.36 kW, not 5.31 kW. The torque panel implies 13.32 rad/s
  (127 rpm), and torque times speed gives 5.29 kW. NR-016 reads as
  the settle speed, not the operating speed. The probe (request 2)
  settles it.
- 1.2 lift margin. Verified. Weight is 252.0 N. The vertical lift
  component is 304.6 N. The ratio is 1.208, not 1.5. A 1.5 ratio
  needs a 20.7 kg machine. The text must name the mass and the point
  the 1.5 multiplies.
- 1.3 governing margin. Relevant. Torque margins 2.03 to 2.05 sit
  below the stated 2.5 gate. The text must say whether torsion is
  under that gate. The abstract and the conclusion must quote the
  minimum margin, not NR-009 alone.
- 1.4 ring factors of safety. Relevant. Values of 15 to 35 in a mass
  search smell like the 09-06 OD-floor artefact. The per-ring floor
  check is needed. R5 at 326,974 needs one sentence of explanation.
- 1.5 length screen. Relevant and the most serious. The cp-fix
  provenance of a76c5e9 decides whether the campaign numbers stand
  under the team's own void rule. Escalate to science-validator.
- 1.6 objective gap. Relevant. The 1.666 kg gap needs the objective
  equation written out, item by item.
- 1.7 damping declaration. Relevant. The 09-15 ruling requires the
  numerical stabilisers declared. The report must state the value,
  the action and the consequence of each damper active at dd3cc6a.
- 1.8 ambiguities. Relevant, small edits. Fix all eight rows.

## Section 2: all relevant

The two biggest content gaps are the TRPT derivation (2.3), which is
the core physics the reader came for, and the Daisy validation (2.8),
which is the long-standing open request for register rows. Item 2.11
(off-design) must be one of the two options, not silence.

## Section 3: right, with three caveats

- 3.2 prose. Relaxing STE for the reader build is a Rod ruling, not
  ours. My view: keep STE as the base. Write causal links as separate
  short sentences. Ask Rod before any relaxation.
- 3.8 code fix. Landing the 09-16 ruling in the evaluator is a code
  change with acceptance-criteria discipline. It has its own gate. It
  is not a quick patch before posting. Rod sets the timeline.
- 3.4 rounding. Fine for the reader build only. The register stays
  full precision, and every rounded body value stays traceable.

## One hypothesis to treat carefully

The warm-start link in 1.1 is a hypothesis, not a finding. Do not
adopt it in the report until the probe logs speed and peak strain on
both paths. The probe (request 2) settles 1.1 and 3.8 at once.

## Proposed order

1. cp-fix provenance of a76c5e9 (1.5) and the window-mean speed probe
   (1.1, 3.8). These two decide whether the numbers stand.
2. Hand check 1.2, gate status 1.3, floor checks 1.4, objective
   equation 1.6, damper values 1.7.
3. Daisy rows (2.8), then the reader-build strip and the missing
   sections.

Any change to a number re-runs the register sign-off.
