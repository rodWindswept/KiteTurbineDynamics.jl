**Status** Gate 3 drafted, held for the fold.

**Seat** @science-writer.

**Read at** `33bc8289`.

# Gate 3: the abstract rewrite

## The ruling and this lane

Rod ruled on 2026-11-17 that the Strathclyde send (Hong and Amjad) reads a formal release.
Three gates clear in order before the send.
They read the whole-report sign-off, the reader-build strip and the abstract rewrite.
The map seat records the ruling at `docs/reporting/room-responses/hermes-2026-11-17-hong-send-ruling.md`.

This seat shares gate 3 with @author.
This pass drafts the new abstract and plans the fold.
It commits no draft byte.

## Gate order at this read

The room holds one receipt from 2026-11-17 at this tip.
That receipt carries the ruling.
No receipt carries the gate 1 sign-off at this read.
No receipt carries the gate 2 strip at this read.
So the fold waits on gate 2.
When gate 2 lands, the fold takes the block below.

## The baseline

The committed draft reads v0.91 at `33bc8289`.
The v0.91 bump landed at `5d4b0067`.
The abstract sits at draft lines 14 to 37.
It measures 245 STE words with one violation at 0.41 per 100 words.
That violation counts one long line, 21 words.
The sentence follows.

```text
Its mean mechanical power is 5.309 kW at the site wind, 11.01 m/s at 9.41 m (NR-008, NR-032).
```

The working tree carries a staged revert to v0.90.
It stays in place.
It takes no byte from this pass.

## The proposed block

@author holds the ruling on this text.
The fence carries the block byte for byte.

```text
**Abstract.** This report asks one question.
Can a kite turbine of about 5 kW carry its power to the ground on a shaft of tethers?
The machine is a ground-generation rotary kite turbine.
A tensile rotary power transmission (TRPT) carries the torque down as tension in the tethers.
The generator stays on the ground.

A differential-evolution campaign searched 930 candidate designs (NR-001).
The search varies ring geometry, polygon count, rotor count, blade bank angles and blade scale.
Every design runs under one fixed power-law generator load.
The campaign scores each design over the same simulation window.

Of the 930 designs, 508 pass every gate (NR-002).
The campaign ranks designs on an objective that reads in kilograms equivalent.
The best feasible value reads 27.364 kg-equivalent against 36.109 at the common start point (NR-005, NR-006).

At the winner operating point the mean mechanical power reads 5.309 kW (NR-008).
The site wind reads 11.01 m/s at 9.41 m (NR-008, NR-032).
The airborne mass reads 25.70 kg (NR-018).
The least factor of safety reads 14.972 (NR-009).
Every checked ring and every checked twist segment stays below its failure boundary at that point (NR-021, NR-022).

The least segment torque margin reads 2.03 at S1, the first of the five segments between the rings (NR-040).
That margin divides the torque capacity of the segment by the torque the segment carries.
The least margin governs.

One version of the model supplies every number here.
That version stays fixed across the search.
The study reads as a simulation study.

Four items stay open, and this report does not settle them.
Blade integrity has no gate yet.
The outer stiffening bridles of real field turbines sit outside the model.
The report assumes that a lifter kite can hold its tension across the wind range.
Launch, recovery and atmospheric realism stay as future work.

The search reads as a first pass over a limited design space, not as a survey.
The report does not claim a global optimum.
```

## Why the reader gains

An external reader meets the report cold.
So the block asks the question first and names the machine second.
It prints each number in plain units.
It names the four open items in one paragraph.
It drops the internal era name from the body text.
The header still binds every number to one model version.

The register IDs stay in the block.
The header rule binds every number to a signed row.
The appendix resolves each row in turn.

The v0.91 block carries one circular line.
It reads that the winner is the best feasible candidate under the objective and the gates.
The new block replaces that line with the feasible count and the objective value.
Both values carry signed rows.

## Number provenance

The campaign rows follow.

| Number | Row | Sign |
|---|---|---|
| 930 designs | NR-001 | science-validator, 2026-10-08 |
| 508 pass of 930 | NR-002 | science-validator, 2026-10-08 |
| 27.364 kg-equivalent | NR-005 | science-validator, 2026-10-08 |
| 36.109 kg-equivalent | NR-006 | science-validator, 2026-10-08 |

The winner rows follow.

| Number | Row | Sign |
|---|---|---|
| 5.309 kW mean | NR-008 | science-validator, 2026-10-08 |
| 11.01 m/s at 9.41 m | NR-008, NR-032 | science-validator, 2026-10-11 |
| 25.70 kg airborne | NR-018 | science-validator, 2026-10-08 |
| 14.972 least FoS | NR-009 | science-validator, 2026-10-08 |

The structural rows follow.

| Number | Row | Sign |
|---|---|---|
| rings and segments below limit | NR-021, NR-022 | aero-validator, 2026-10-08 |
| 2.03 margin at S1 | NR-040 | science-validator, 2026-10-12 |

Every row above carries a sign.
This pass adds no row and renames no row.
The block cites two rows that the draft body already prints, NR-002 and NR-018.
So the cited count holds at 59.

## The open items, plainly

Four items stay open.
Blade integrity has no gate yet.
The outer stiffening bridles of real field turbines sit outside the model.
The report assumes that a lifter kite can hold its tension across the wind range.
Launch, recovery and atmospheric realism stay as future work.

The block names each item in one short sentence.
No item hides behind a model name.

## The fold plan

The fold runs in this order.

1. Gate 2 lands and its receipt reads at the tip.

2. Read the tip and confirm the gate 2 receipt.

3. Replace draft lines 14 to 37 with the block above.

4. Keep the Keywords line and the Summary for decision as they stand.

5. Measure the draft. This desk expects 12,817 STE words, 30 violations at 0.23 per 100 words and 1,554 lines.

6. Bump the draft to v0.92 and log the tracker entry.

7. Run the STE gate at 2.0 on the draft and the tracker.

8. Stage the draft and the tracker only, then commit and push.

9. @author counter-reads the folded block at the tip.

The fold acts on the committed line only.
The staged revert stays untouched and unnamed.

## What this pass moves

It moves no draft byte.
It moves no register row.
It moves no cited count.
It lands this receipt.

## STE

| Artefact | Words | Violations | Per 100 words |
|---|---|---|---|
| proposed block | 336 | 0 | 0.00 |
| v0.91 abstract | 245 | 1 | 0.41 |
| this receipt | 756 | 0 | 0.00 |

## Next action

@author rules the block.
The fold waits on gate 2.
This seat folds the block when gate 2 clears.

- @science-writer
