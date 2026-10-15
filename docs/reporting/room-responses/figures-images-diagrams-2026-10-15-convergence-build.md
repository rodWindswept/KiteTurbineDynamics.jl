# Room response: the convergence two-panel build (2026-10-15, figures seat)

**Status** LANDED. **Seat** figures-images-diagrams. **Generator**
`0db99ac`. The outputs and the records ride this commit.

Row 16 carries the merged two-panel figure, "first feasibility, then
mass": panel 1, the pooled status mix with the NR-055 reject split.
Panel 2, the three island running-best curves. The build reads from
the aero extract (`9dd453d`) and the three telemetry files. No new
runs.

## What landed

- `convergence.py`, the generator, with the SPEC (v1).
- The outputs: `convergence.svg` / `.pdf` / `.png`, the label ledger,
  the manifest and the checks log.
- The captions draft and the register-status note.
- Figure-map row 16 moves to R2. The slug `convergence` fills. Delta
  v48 records the build.

## Receipts

- F-REPRO: three runs at `0db99ac` stay byte-identical across all five
  outputs. The md5 table reads 15 of 15 equal
  (`scratch/fig_cvp_repro.md5`).
- F-LABEL: the self-check passes. The ledger carries every drawn string
  (34 strings).
- The in-script set reads 22 checks, 0 fail. It includes the NR-002
  mix, the NR-055 split and the parity recompute on all 93 series
  rows.
- The label set applies the 301 print ruling and the NR-055 forms:
  "feasible", "rejected: rotor below 1.5 m clearance", "rejected:
  twist past the crossing limit", "rejected: power below the 5 kW
  floor", "rejected: FoS below 2.5", "rejected: cause not logged".
  The pooled counts ride the legend.
- The drawn values: the counts (NR-002, NR-055), the seed 36.109
  (NR-006) and the winner 27.364 (NR-005). The caption tier prints the
  island 1 and 2 finals (NR-003, NR-004).
- The foot notes read "the reject split reads the power floor first"
  and "islands 1 and 2 improve to their last generation · the budget
  stops the search".

## Notes carried

- The drawn objective label keeps the (kg) form. Both caption tiers
  read kg-equivalent, matching the strip form note.
- The label wording applies the NR-055 forms. A bounce lands as one
  line.
- The visual pass by Rod joins after the counter-reads.

## Pending

- The counter-reads: F-VALUE at the aero seat, the register read at
  the science seat.
- The visual pass by Rod.
- The §3.2 fold takes the seat marker and the appendix row after the
  pass. Marker line reads: `[Figure seated: figure-map row 16
  (convergence and the status mix, slug `convergence`). Values cite
  NR-002, NR-003, NR-004, NR-005, NR-006, NR-036, NR-054 and
  NR-055.]`

## Deltas

- v1 (2026-10-15): the kit lands. Row 16 moves to R2.

figures-images-diagrams, 2026-10-15.
