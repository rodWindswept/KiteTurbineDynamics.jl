# Harris review work division (2026-10-10)

Lead @hermes. Directive from Rod, 2026-10-10: raise the cadence and
effort on the report goals. Inputs: the Harris review relay (66ec6a6)
and the lead triage (dfdd78a).

## Rules

A number changes only through the register. A physics change goes
through acceptance criteria. Owners land work in the repo. Validators
sign it.

## Items

| Item | Owner | Deliverable | Gate |
|---|---|---|---|
| 1.1 window-mean omega and torque row; omega(t) and strain probe, warm and cold | aero-worker (probe), science-validator (row) | probe log and NR row | science-validator |
| 1.2 lift 1.5x hand check (mass and point) | science-validator | one paragraph and row amends | aero-validator counter |
| 1.3 torsion gate status; margin table | science-validator, software-validator | gate ruling and table | both sign |
| 1.4 per-ring OD and wall floor; R5 explanation | aero-validator | ring table | science-validator |
| 1.5 cp-fix provenance of a76c5e9 | hermes (forensics done; sign-off pending) | record and ruling | science-validator |
| 1.6 objective equation | hermes (dispatched) | equation and itemisation | science-validator |
| 1.7 damper values at dd3cc6a | hermes (dispatched) | value table | software-validator |
| 1.8 ambiguity edits | author, science-writer | draft edits | STE gate |
| 2.1 operating-point rows (wind, rho, shear, elevation, swept area, Cp, lambda) | aero-validator | NR rows | science-validator |
| 2.2 gene table (bounds and live conditions) | hermes (dispatched) | table | science-validator |
| 2.3 TRPT derivation from the src form | science-writer, software-validator | derivation and code form | both sign |
| 2.4 load-law teaching point | science-writer | prose | science-validator |
| 2.5 sub-model paragraphs | science-writer | prose | science-validator |
| 2.6 numerics section | software-validator | prose and table | science-validator |
| 2.7 DE settings | hermes (dispatched) | settings table | software-validator |
| 2.8 Daisy rows | science-validator, aero-validator | NR rows and validation section | Rod |
| 2.9 software section | software-validator | prose | Rod |
| 2.10 outlook | author | prose | Rod |
| 2.11 off-design: sweep or honest statement | analysis room | decision | Rod |
| 2.12 bow output | aero-worker | row | science-validator |
| 3.1 reader-build flag | hermes | builder flag and two builds | software-validator |
| 3.5 figure fixes | figures-images-diagrams | kit deltas | science-validator |

## Rod decisions needed

- 3.2 STE prose for the reader build: keep STE or allow causal joins.
- 3.7 title.
- Posting timeline and abstract timing.

## Tonight (hermes)

Five forensics dispatched: 1.5, 1.6, 1.7, 2.2 and 2.7. The findings
land in the room responses as one packet, then the owners refine.
