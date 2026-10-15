# SPEC: convergence. The campaign progress in two panels.

**Slug** `convergence`

**Status** SPEC v1, R2 landing. Angle brackets ⟨⟩ mark binding slots.
This document carries no drawn value. The numbers register supplies the
citation discipline. The section 3.1 and 3.2 prose supplies the reader
account.

**Owner** @figures-images-diagrams. **Content check** @science-validator
and @aero-validator. @aero-validator runs the F-VALUE check at the
sign-off commit. **Reader-facing layer** @author: the captions and the
slotting.

**Contracts** the reporting framework (the figure workflow: SPEC,
GENERATE, CHECK, the rounds, the dual captions). The numbers register
(the firewall). The display forms: the drawn objective label keeps the
(kg) form, and the caption tiers read kg-equivalent (the strip form
note, 2026-10-14).

## Why this exists

The map seats row 16 as the recorded merge of two asks (v47): the F4(b)
status mix and the Harris 3.5 item 4 convergence chart. They make one
two-panel figure, "first feasibility, then mass". Panel 1 shows what the
search finds first. Panel 2 shows what it then reduces.

## What already exists. Extend, do not rebuild.

- The aero series extract `scratch/av_conv_series.csv` (`9dd453d`). It
  carries the three island running-best series, 31 values each, on the
  strip-extract rule. NR-054 signs it.
- NR-055 signs the reject split for print. The founder ruled "Print"
  (room, 2026-10-15).
- The three campaign telemetry files carry the 930 status rows.

## Inputs. The record contract.

- Four committed inputs, pinned by sha256 in the manifest: the series
  extract and the three telemetry files.
- The generator recomputes the split and the series in-script. It
  asserts the signed forms before it draws. No new runs.

## The drawing

### Panels

- Panel 1 carries the pooled outcome mix per generation: 31 stacked
  bars, pooled over the three islands. The six classes read in words:
  feasible, the two named gate classes, and the three NR-055 subgroups.
  The legend carries the pooled counts.
- Panel 2 carries the three running-best curves, generations 0 to 30.
  A common start at 36.109 marks the seed. A star marks the winner,
  27.364 at generation 26.
- The foot notes read "the reject split reads the power floor first"
  and "islands 1 and 2 improve to their last generation · the budget
  stops the search".

### Elements table

| tag | drawn from | drawing rule | asserted |
|---|---|---|---|
| `bars_mix` | the telemetry status column | stacked bars, 31 generations, six classes | the class counts, the per-generation totals |
| `curves` | the series extract | three lines, island colours, common start | the parity recompute on all 93 rows |
| `seed_label` | NR-006 | text at the common start | the form 36.109 |
| `star` | NR-005 | marker at generation 26 | the placement and the form 27.364 |
| `legend` | NR-002, NR-055 | six class rows with the counts | every count |
| `stamps` | — | sources, rows, script commit | presence |

### Label set. Applied strings.

- `feasible (508)`
- `rejected: rotor below 1.5 m clearance (110)`
- `rejected: twist past the crossing limit (11)`
- `rejected: power below the 5 kW floor (96)`
- `rejected: FoS below 2.5 (4)`
- `rejected: cause not logged (201)`

The three subgroup labels carry the NR-055 reading rules. The plate
prints no status codes and no Track names. A wording bounce lands here
as one line.

### Readout list

| Figure string | Source | Where used | Note |
|---|---|---|---|
| the class counts | NR-002, NR-055 | the legend | integers |
| the common seed 36.109 | NR-006 | panel 2 | 3 dp |
| the campaign winner 27.364 | NR-005 | panel 2, the star | 3 dp |
| the objective label | NR-036 | the y axis | the (kg) drawn form |

The caption tier prints the island 1 and 2 finals (30.578, 30.637).
The plate does not. NR-003 and NR-004 carry them.

The display forms pin here once, for labels, captions and prose alike.

## Checks. External, never self-graded.

- **F-CITE, citation binding.** Every annotation cites a signed row.
  The stamps carry the sources, the rows, the run and the script
  commit. A missing stamp or citation is a reject.
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

## Caption plan (dual)

- Plain sentence: ⟨the search finds feasibility first, then cuts mass,
  and the budget stops it before convergence.⟩
- Technical caption: ⟨the two panels, the pooled counts, the seed, the
  winner and the two improving islands, every number with its row.⟩

@author writes both captions. Every number cites a register row.

## Emitted artifacts at GENERATE

- the figure, vector PDF and SVG, with a PNG preview at print
  resolution
- the generating script, committed
- the label ledger, checked by F-LABEL
- the manifest, with the input pins and the output hashes
- the checks log
- the captions draft and the register-status note

## Rounds

- **R2** this landing: the scripted figure against the committed
  inputs walks F-CITE, F-REPRO and F-LABEL. The seats take their pass.
  Deltas land. The counter-reads close clean at both seats (the
  register-status v2 record).

- **R3** the final pass. Rod does the visual pass. Status moves to
  approved.

## Open inputs

1. The label strings apply the NR-055 forms. A bounce lands here as
   one line.

2. The reject split reads the power floor first. The foot note states
   it.

## Non-goals

No new runs. No per-island bars. No Track names. No status codes. No
end labels for the island 1 and 2 finals.

## Deltas

- v1 (2026-10-15): R2 lands with the GENERATE pass. The figure carries
  the recorded merge, the NR-055 label set and the parity-recomputed
  series. No drawn value changes after the scratch rounds.
