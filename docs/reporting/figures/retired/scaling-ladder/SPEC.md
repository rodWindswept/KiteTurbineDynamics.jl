# SPEC: scaling ladder. The value track rungs, from the validated rung.

**Slug** `scaling-ladder`

**Status** SPEC v1, R2 landing. Angle brackets ⟨⟩ mark binding slots.
This document carries no drawn value. The value-claims ledger section 4
is the seed. The section 5 close ("Where this goes") is the reader
account.

**Owner** @figures-images-diagrams. **Content check** @aero-validator
(the ledger owner) and @science-validator. **Reader-facing layer**
@author: the slot and the captions.

**Contracts** the reporting framework (the figure workflow: SPEC,
GENERATE, CHECK, the rounds, the dual captions). The value-claims
ledger (the classed seed). The visual analogue rule from the ledger
section 1: solid ink stands for landed artifacts and signed values.
Open ink plus the label stands for targets. No target mark sits on a
value axis.

## Why this exists

The close ("Where this goes") prints two movements: what the
instrument does, and the programme targets. The plate carries the
second movement as one look: the validated rung and the rungs above
it. The author seat named the slot on 2026-10-16 (the close, after the
target paragraph). The ledger seeds the rungs element by element, one
row per rung.

## What already exists. Extend, do not rebuild.

- The rung seed: the value-claims ledger section 4. One row per rung.
  The 5 kW rung reads `capability`, solid. The 7 to 50 kW rungs read
  `target`, open plus label.
- The code set: `const RUNGS` in `scripts/compute_seeds.jl` reads 5.0
  to 50.0 kW.
- No new runs. The plate draws the classed rungs only.

## Inputs. The record contract.

- Two committed inputs, pinned by sha256 in the manifest: the
  value-claims ledger and `scripts/compute_seeds.jl`.
- The generator parses the rung set from the code and the class split
  from the ledger section 4. It asserts the class split, the ink
  classes and the plain label before it draws.

## The drawing

- Seven rungs, bottom to top, at equal spacing, on a ladder frame.
  The bottom rung reads 5 kW, solid: the validated rung. The six rungs
  above read 7 to 50 kW, open, each labelled `programme target`.
- The key states the ink rule: filled stands for the validated rung
  (the campaign dataset and the register back it). Open stands for
  programme targets (forward-looking, under the plain label
  `programme target — no repo artifact`).
- The foot states: rungs at equal spacing, not a value scale. No
  screen value prints.

### Label set. Applied strings.

- the title `The scaling ladder` and the subtitle `the rungs above the
  validated machine are programme targets, not results`
- the rung values: `5 kW` · `7 kW` · `10 kW` · `15 kW` · `25 kW` ·
  `35 kW` · `50 kW`
- the class labels: `the validated rung` · `programme target`
- the key lines: `filled — the validated rung: landed` · `the campaign
  dataset and the register back it` · `open — programme targets:
  forward-looking` · `the plain label: programme target — no repo
  artifact` · `Rungs sit at equal spacing. The plate is not a value
  scale.` · `No screen value prints.`
- the stamps: the source stamp (the ledger seed and the code set) and
  the script-commit stamp

### Readout list

| Figure string | Source | Where used | Note |
|---|---|---|---|
| the rung values 5 to 50 kW | ledger section 4 and `const RUNGS` | the rung labels | integer kW forms from the code set |
| the class labels | ledger section 4 | the rung labels and the key | `the validated rung` and `programme target` |
| the plain label | ledger section 4 | the key | `programme target — no repo artifact` |

No other number prints. No register row binds the plate. No measured
value prints.

## Checks. External, never self-graded.

- **F-CITE, class binding.** Every drawn element resolves to its
  value-claims ledger section 4 row. The stamps carry the sources and
  the script commit. A missing stamp is a reject.
- **F-REPRO, deterministic reproduction.** A fresh run on the same
  inputs reproduces the figure bit-identically. Script and toolchain
  stay pinned.
- **F-LABEL, ledger equality.** The check enumerates the text layer of
  the emitted vector. Every string equals its ledger entry.
- **F-CLASS, the class split.** The drawn set carries the validated
  rung solid and the six targets open, per the ledger. The aero and
  science seats counter-read this at the sign-off commit.

The framework visual checklist applies, graded from the image alone.
Pixels never validate numbers. Rod does the final visual pass.

## Caption plan (dual)

- Plain sentence: ⟨the rungs above the validated machine are programme
  targets, not results.⟩ Seed only. @author owns the final text.
- Technical caption: ⟨the seven rungs at equal spacing, the solid
  validated rung and the six open targets, each classed by the
  value-claims ledger.⟩ Seed only.

## Emitted artifacts at GENERATE

- the figure, vector PDF and SVG, with a PNG preview at print
  resolution
- the generating script, committed
- the label ledger, checked by F-LABEL
- the manifest, with the input pins and the output hashes
- the checks log
- the captions draft and the register-status note

## Rounds

- **R2** this landing: the scripted figure against the committed seed
  walks F-CITE, F-REPRO and F-LABEL. The seats take their pass.
- **R3** the final pass. Rod does the visual pass. Status moves to
  approved.

## Open inputs

1. The caption wording. The author seat holds the pen. The draft here
   is a seed.
2. The counter-reads: @aero-validator (the ledger owner) and
   @science-validator, before the visual pass.
3. The fold: the close, after the target paragraph (the author seat,
   2026-10-16). The seat marker and the appendix row land at the fold.

## Non-goals

No value axis. No screen values. No cost or carbon digits (the held
set in ledger section 5). No interior rungs from earlier phrasings
(one set only). No register-row claim.

## Deltas

- v1 (2026-10-16): R2 lands with the GENERATE pass. The rungs draw
  from the ledger section 4 seed, at the class split the room agreed
  (aero proposed, science mapped, fig gave the visual analogue).
