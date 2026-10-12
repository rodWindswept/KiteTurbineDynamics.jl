# Captions: system anatomy

**Slug** `system-anatomy`. **Status** GENERATE (re-cut v3). **Date**
2026-10-12. **Caption split** 2026-10-12.

Site: the report at §2.1, the machine and its terms. Reading order: the
plate seats ahead of the genome strip.

The wording comes from the seat draft `captions-draft.md`, STE-gate
checked, with the 2026-10-12 caption split. Values cite NR-011 and
NR-017. The geometry source is the island-3 winner decode
(`scratch/fig1_decode_winner.jl`, data commit `dd3cc6a`).

The split (2026-10-12): the plain and technical captions carry the
scientific text only. The provenance line carries the audit tokens: data
commit, decode receipt, rows, script commit.

The audit tokens resolve to the figure-provenance appendix. The report
prints the scientific captions. The plate stamp and the appendix carry
the provenance.

## Plain caption

This figure shows the whole machine and the names of its parts, from the
kite stack in the sky to the ground station that takes the power.

## Technical caption (undergrad register, STE-clean form)

The plate shows the campaign winner in a side view. Six rings run from
the ground ring (R1, 0.804 m radius) to the hub ring (R6, 4.580 m
radius).

Three tension lines span each of the five segments S1 to S5. The main
rotor sits on R6 only. Its three blades bank at 7.088°.

The lift chain runs from the lifter stack, down the lift line, through
the sky anchor and the cyan line, to the lift bearing. Three bridles run
from the bearing into the main rotor.

The lifter gives lift only. It does not drive the rotor. Torque runs
down the TRPT rings to the ground station.

The dashed outline marks the ground station: the generator and the power
take-off. That outline sits outside the primary render scope. The dashed
backline is an altitude limiter, not a load path. The scale bar is 5 m.

## Provenance line

Data commit `dd3cc6a` · decode receipt `scratch/fig1_decode_winner.jl` ·
rows NR-011, NR-017 · script commit `df8a2b4` · full record: the
figure-provenance appendix.

## Generation note

Resolved at GENERATE by the figures seat. The re-cut v2/v3 lands at
`df8a2b4`. The generator emits the TeX build, the mock and the label
ledger from one coordinate set. pdflatex and pdftoppm then render the
plate. Two full runs stay byte-identical.

The author label check closed at `38a15f1`, and its two fixes ship in v3.
The content check ran at `311e738`. Its two deviations ship in v3, and no
bound value moved.

Held terms: the plate carries the room forms (lifter stack, autogyro
rotors, tension lines, sky anchor, cyan line). The Track D picks flip
the lifter labels and the line compound at the author pass.

The caption follows the picks. The title carries the settled reader
term (campaign winner). The plate header carries the island-3 short
form.

Split note (2026-10-12): the caption text only. No render moved.
