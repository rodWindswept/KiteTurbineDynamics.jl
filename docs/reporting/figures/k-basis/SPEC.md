# SPEC: the k basis. The load sweep behind the campaign load.

**Slug** `k-basis`

**Status** SPEC v1, R2 landing. Angle brackets ⟨⟩ mark binding slots.
This document carries no drawn value. The numbers register supplies the
citation discipline. The section 2.3 prose supplies the reader account.

**Owner** @figures-images-diagrams. **Content check** @science-validator
and @aero-validator. @aero-validator runs the F-VALUE check at the
sign-off commit. **Reader-facing layer** @author: the captions and the
slotting.

**Contracts** the reporting framework (the figure workflow: SPEC,
GENERATE, CHECK, the rounds, the dual captions). The numbers register
(the firewall). The glossary forms (the term reads "measurement
window").

## Why this exists

The section 2.3 prose states that one load scored the whole search and
that a load sweep of the seed machine selected the value. The reader
asks why. The prose carries the account. This plate carries the shape:
the sweep readings, the floor, the plateau and the pick.

The plate re-derives nothing and smooths nothing. It draws the
committed record.

## What already exists. Extend, do not rebuild.

- The sweep record `scripts/results/k_sweep_daisy_5kw.csv` carries the
  ten readings. The run landed at `adea1a3` (2026-08-22). The file blob
  is `d17d1377` at HEAD.

- NR-041 binds the ten pairs at 2 dp, the reject row and the plateau
  band. The aero counter-read closed.

- NR-015 carries the pick and the protocol settings.

- The floor numeral rides the section 2.4 pair (NR-027 and NR-039). No
  dedicated floor row exists. The author check passed the pair and sent
  no bounce.

- The template and the seams come from the mechanism-pair kits. The
  renderer draws ten points. It selects nothing.

## Inputs. The record contract.

- One committed CSV. Ten rows. The columns: `k`, `status`, `P_mean`,
  `P_end`, `omega_eq`, `omega_final`, `FoS_min`, `T_lift` and `wall_s`.
  The plate draws `k`, `status` and `P_mean`. Nothing else draws.

- The `omega_eq` column reads zero in every row. The plate draws
  nothing from it and quotes nothing from it.

- No clamp line draws. The plateau annotation names no cause. A clamp
  annotation is era-bound, and the sweep-era form differs from the
  current law.

- No derivation formula draws. The values read at their seated forms.

## The drawing

### Panel and axes

- One panel. The x axis carries the load constant with its units. The
  y axis carries the window mean power in kilowatts.

- Ten points sit at the recorded settings, joined in k order. Straight
  segments only.

- The floor line is horizontal and dashed. The reject point carries a
  ring. The pick carries a star and a vertical guide. The plateau
  carries a bracket.

### Elements table

| tag | drawn from | drawing rule | asserted |
|---|---|---|---|
| `sweep_points` | the CSV | ten points, joined in k order | count, positions |
| `floor_line` | the floor value | horizontal, dashed | presence |
| `reject_ring` | the status column | ring on the reject row | presence |
| `pick_star` | the pick value | star plus guide | presence |
| `plateau_bracket` | the plateau rows | bracket over the band | presence |
| `subtitle_form` | — | the one form of the sweep event | presence |
| `source_stamp` | — | blob, run, rows, script commit | presence |

### Readout list

| Figure string | Source | Where used | Note |
|---|---|---|---|
| the load constant | the `k` column, units at the axis | axis | the sweep settings read as listed |
| window mean power | the `P_mean` column | axis | the plotted basis |
| the floor | the floor value | line label | the section 2.4 citation pair |
| reject | the `status` column | point label | the light end |
| the campaign load | the pick value (NR-015) | pick label | one load for the whole search |
| the plateau | the plateau rows | bracket | the heavy end |

The display forms pin here once, for labels, captions and prose alike.

## Checks. External, never self-graded.

- **F-CITE, citation binding.** Every annotation cites a signed row.
  The source stamp carries the blob, the run, the register rows and the
  script commit. A missing stamp or citation is a reject.

- **F-REPRO, deterministic reproduction.** A fresh run on the same
  inputs reproduces the figure bit-identically. Script and toolchain
  stay pinned.

- **F-LABEL, ledger equality.** The check enumerates the text layer of
  the emitted vector. Every string must equal its ledger entry.

- **F-VALUE, register equality.** Every drawn value equals its signed
  row at the stated precision. @aero-validator owns this check, at the
  sign-off commit. No tolerance widening.

The framework visual checklist applies, graded from the image alone.
Pixels never validate numbers. Rod does the final visual pass.

## Caption plan (dual, from the first figure)

- Plain sentence: one load scored every design. This figure shows how
  the sweep chose it, between the loads that fall short and the loads
  that gain nothing.

- Technical caption (undergrad register, STE-clean form): the ten
  readings, the floor, the reject row, the plateau band and the pick.
  @author writes both captions. Every number cites a register row.

## Emitted artifacts at GENERATE

- the figure, vector PDF and SVG, with a PNG preview at print
  resolution
- the generating script, committed
- the label ledger, checked by F-LABEL
- the manifest, with the input pin and the output hashes
- the checks log
- the captions draft and the register-status note

## Rounds

- **R2** this landing: the scripted figure against the committed
  record walks F-CITE, F-REPRO and F-LABEL. The image-reader and the
  validators take their pass. Deltas land.

- **R3** the final pass. @aero-validator runs F-VALUE at the sign-off
  commit. Rod does the visual pass. Status moves to approved.

## Open inputs

1. **Data side:** none. Every drawn value carries a signed row.

2. **Redraw guard:** a fixed-seed redraw would need fresh rows before
   anything prints from it (@science-validator).

## Non-goals

The plate re-derives no physics and reads no other file. No clamp
line. Nothing from the `omega_eq` column. No anchor formula. No
smoothed curve. No second panel.

## Deltas

- v1 (2026-10-12): R2 lands with the GENERATE pass. The scratch draft
  carried the round-1 reads before the kit. No value changed at the
  landing.
