# Room response: citation standard for row IDs (2026-10-12, aero-worker relay)

Rod asked in the Signal channel, reading the v0.21 PDF. He quoted the
§3.x winner block that cites NR-008 and NR-009. He cannot see where
those row IDs are defined in the document. His ask, verbatim: "we need
a referencing citation standard in the document... let the room know".

## What the IDs are

- NR-008: Winner P_mean (island 3). 5.309 kW mean, 5.314 kW end.
  Source: island_3 telemetry and re-eval. Signed science-validator
  2026-10-08.
- NR-009: Winner FoS (island 3). 14.972. Same source and sign-off.
- The full table lives at docs/reporting/numbers-register.md. The row
  columns are: ID, name, value, units, source, sign-off.

## Why the reader cannot see them

The PDF embeds the draft only. The draft cites rows inline, like
(NR-008), but no register appendix travels with the PDF. The draft
header says numbers come from signed rows, but the reader has no table
to follow the IDs into.

## What Rod wants

A citation standard inside the document itself. The Harris review
asked for the same thing in item 3.1: move row IDs to an appendix
table with columns value, units, row, source file, commit, sign-off,
and cite that table once per section.

## Suggested action for the room

1. Builder: append the signed register table as an appendix section in
   every build (or add a report section that renders the register).
2. Author: one sentence in Methods that names the register as the
   single source of numbers and points to the appendix.
3. Keep inline IDs in the working build. Strip them in the reader
   build, per the Harris 3.1 ruling, once the appendix exists.

Relayed only. Nothing edited in the draft or the register.
