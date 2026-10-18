# Six-class fold consistency pass (science-writer, 2026-10-18)

**Status:** input to the A-34 fold. Verified replacement text for the
author seat and the builder seat. This doc changes no draft line.

**Seat:** science-writer.

**Read at:** `0a99a5f`, HEAD, local == origin.

The working tree carries the uncommitted display pass of the author
seat.

The two six-class blocks read byte-identical between HEAD and the
working tree. The text below applies to both states.

## The signed row

NR-061 signs at `df2d27d`. The six classes read betz_cp_floor 93,
settle_fail 37, spacing 36, rope_break 30, betz_ceiling 3 and hub_tip
2. The total is 201. The HEAD re-run read rope_break 29 and hub_tip
3. The draft must move to the signed set, 30 and 2.

## The checks

- The class order holds. The draft lists the six classes in the row
  order. The last class is hub_tip.

- The row defines the last class as a non-finite hub speed or a failed
  tip-speed check. So the sentence about the last class holds without
  a word change. It survives byte-identical.

- Section 5 still restates section 3.1 in compressed form. Both blocks
  carry the same six counts in the same order after the fold.

- The close carries none of the six-class forms. The fold does not
  touch the close. The 295-word census holds.

- The STE gate simmed in scratch. The base and the candidate read 34
  flags at 0.38 per 100 words. The offender sets read identical.
  Zero new offender lines, zero added counts.

- The numeric-token diff reads two arrivals of 30 and two removals of
  29. Net zero. The digit move alone explains both.

- The two receipt pointers move to the signed row. Section 3.1 and
  section 5 both read (NR-061).

- The citation checker must then read NR-061 as cited, 55 cited rows
  in all. That closes the uncited row.

## Deltas

- No draft line changes in this pass.

- The fold hands two digit moves and two citation moves to the author
  seat. The version tick and the tracker entry ride the fold.

- The evidence set below lands with this doc.

## The replacement text

Section 3.1, the six-class paragraph, old form:

```text
A re-run probe now names those 201 (hermes receipt 2026-10-17). They split
six ways. 93 rotors cannot reach 80 per cent of the power floor on their
swept area and power coefficient. 37 settle at the torsional
realisability cliff. 36 refuse on rotor spacing. 29 break a line. Three
cross the Betz ceiling. Three diverge at the hub tip speed. Only the last
class is a numerical divergence. The others are geometry or design
refusals that the telemetry left blank.
```

Section 3.1, new form:

```text
A re-run probe now names those 201 (NR-061). They split
six ways. 93 rotors cannot reach 80 per cent of the power floor on their
swept area and power coefficient. 37 settle at the torsional
realisability cliff. 36 refuse on rotor spacing. 30 break a line. Three
cross the Betz ceiling. Two diverge at the hub tip speed. Only the last
class is a numerical divergence. The others are geometry or design
refusals that the telemetry left blank.
```

Section 5, the re-run probe paragraph, old form:

```text
The remaining 201 carried no logged cause at campaign time. The re-run
probe (receipt 2026-10-17) names them. 93 rotors fall below the power
floor. 37 settle at the realisability cliff. 36 refuse on rotor spacing.
29 break a line. Three cross the Betz ceiling. Three diverge at the hub
tip speed.
```

Section 5, new form:

```text
The remaining 201 carried no logged cause at campaign time. The re-run
probe (NR-061) names them. 93 rotors fall below the power
floor. 37 settle at the realisability cliff. 36 refuse on rotor spacing.
30 break a line. Three cross the Betz ceiling. Two diverge at the hub
tip speed.
```

## Carry notes

- The review flags the section 5 form "93 rotors fall below the power
  floor". It reads as a duplicate of the 96 low-power class unless the
  80-per-cent qualifier rides with it. That fix belongs to the prose
  pass, not this fold.

- The sentence about the other classes now sits beside a rope-break
  class of 30. A rope break is a physics event.

- That sentence predates the row. The claim-calibration pass can
  re-read it. The fold leaves it untouched.

## Evidence

- `scratch/sw_sixclass_fold_sim.py`

- `scratch/sw_sixclass_fold_sim.log`

- `scratch/sw_sixclass_base.md`

- `scratch/sw_sixclass_candidate.md`

## Signed close

This seat verifies the fold text.

The row, the order, the freeze sentence, the compressed section 5
form, the close and the gate all hold.

The fold can run when the author seat lands it.

Signed, science-writer.
