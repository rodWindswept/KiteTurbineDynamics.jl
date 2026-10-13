# Feedback round 2: science-writer seat plan

**Date drafted:** 2026-10-13 (overnight pass)

**Seat:** `@science-writer` (narrative structure, fact order, sweeps)

**Source:** `docs/reporting/feedback/feedback-on-report2.md`, landed 2026-10-12 23:10, 18 parts.

**Instruction:** the user asked every seat to read the complete set of recommendations and prepare plans for its own parts.

Save the plans for execution tomorrow.

The room note of 2026-10-13 adds one lens. The facts must read in a logical order, in one coherent narrative.

## Coverage

I read all 18 parts of the feedback document.

This plan covers the parts that need work from this seat.

The parts: 3, 4, 7, 11.2, 11.3 and the sweeps.

A map at the end lists the parts that sit with other seats.

## The fact-order lens (the room note of 2026-10-13)

The note asks for a logical fact order and one coherent story. The core of the feedback is the three-layer frame: machine, search, instrument. This seat reads every fact against that frame.

The walk this seat works to:

1. Scale. The campaign size and the status mix.

2. Score. How the search verdict reads. The objective score, its parts, the physical mass.

3. Winner. What it does: the operating point. What it must satisfy: the gate margins. What it is: the machine.

4. Instrument. How we know. The fidelity facts, the failure ledger, the eras.

5. Decision. What the evidence supports. The author sections.

Two rules travel with the walk.

- One home, one form. A value has one home. A reprint cross-refers to it in the same form.

- Order follows need. A definition lands at its first use.

Findings against the current draft:

- Section 3.3 interleaves three fact classes. The outcome facts, the machine description and the era note alternate. The order proposal is SW2g.

- The objective score prints as "kilograms" in five prose sites. The term pass is SW1.

## Already landed from this seat (context, not new work)

- Sweep 13 (`4bbc0e5`): the v0.18 to v0.24 span reads clean. No value changed.

- The window-term flip: glossary v10 (`6c0d17d`) and the nine-figure brief (`503f167`).

- Sweep 14 runs at the next draft push. It covers the restructure span.

## Work items

### SW1. The score term and the mass split (feedback parts 3 and 4)

The draft prints the search objective as "kilograms" in five prose sites.

- Section 2.4, the campaign table cell: "search objective (airborne mass plus penalties), kg".

- Section 3.1: "The seed scores 36.109 kilograms (NR-006)."

- Section 3.2: three island sentences and the penalty sentence.

The register carries the unit column "kg" on the fitness rows (NR-003 to NR-006). Its note carries a reading rule for section 3.2. The feedback rules the term "kg-equivalent" for values that carry penalties. The numeral does not move. The two forms do not match, so the room needs one display note.

- Work: draft the replacement text for each site. Request a short display-form note from `@science-validator`. The note names the reference unit for objective values.

- Deliverable: the replacement text below, gate-simmed in scratch.

Proposed section 3.2 block:

> The best recorded objective score on island 1 is 30.578 kg-equivalent at generation 30 (NR-003).
> Island 2 reaches 30.637 kg-equivalent at generation 30 (NR-004).
> Island 3 reaches 27.364 kg-equivalent at generation 26 (NR-005).
> The physical airborne mass of the winner is 25.698 kg (NR-018).
> The objective score adds 1.665 kg-equivalent of penalties (NR-039).

Proposed section 3.1 sentence: "The recorded common seed genome scores 36.109 kg-equivalent under the campaign objective (NR-006)."

Proposed section 2.4 table cell: "Airborne mass + penalties, kg-equivalent".

Proposed section 2.4 definition, from part 4:

> The campaign minimizes a kg-equivalent objective score: the airborne mass plus the gate penalties.
> A lower score is better.
> The objective score is not the physical airborne mass.

- The penalty breakdown table lands with `@aero-validator` (W4). The signed row NR-039 already carries the split. This seat checks the table at the fold and holds the one-writer line.

- Acceptance: every objective-score site takes the ruled term. Every physical-mass site keeps "kg". No value token moves.

- Deps: `@science-validator` (display note), `@author` folds, `@fig-img-diagrams` takes the term on the convergence plate. The machine-evolution strip label stands (NR-036).

### SW2. The Results fact tables (feedback part 7)

Part 7 carries seven items. Items 7.2 and 7.5 ride with SW1 and `@aero-validator` W3. This section covers the rest.

#### SW2a. Status mix with shares (item 7.1)

- The table lands at section 3.1 beside the counts sentence.

- The counts sit on NR-002. The shares need a derived row. Request it from `@science-validator` on the count base 930.

- Proposed rows: ok 508 54.6%, reject 301 32.4%, clearance_reject 110 11.8%, reject_twist 11 1.2%.

- Acceptance: the shares sum to the base at the printed precision. The fallback keeps the counts and drops the shares.

#### SW2b. Convergence units (item 7.2)

- The same pass as SW1. No separate item.

#### SW2c. The winner summary table (item 7.3)

- The operating-point table already seats at section 3.3. The pass adds one row: the least segment torque margin, 2.03 at S1 (NR-040).

- The lead-in line names the table: "The winner operating point and margin summary reads as follows."

- The abstract and the conclusion keep the S1 value in their present form.

#### SW2d. The gate-margin table (item 7.4)

- The gate table seats at section 3.3. The pass upgrades it with a margin column.

- Ready cells: power (NR-008), FoS (NR-009), torque margin (NR-040), rope-break outcome (NR-012, NR-013).

- Requested cells: the power margin pair, +0.309 kW and +6.2 per cent. The FoS ratio form. The least twist value at S1. The clearance numeric margin from the `@aero-validator` W7 answer.

- The likely read: the power floor is the closest gate. That reads only when the margin column lands.

- Acceptance: every margin figure comes from a row or a proportional derivation with its recipe. No cell guesses.

#### SW2e. The FoS origin note (item 7.5)

- The reconciling text lands with `@aero-validator` (W3). This seat sweeps it against NR-009 and NR-021 at the fold.

#### SW2f. The mass budget (item 7.6)

- The register holds the total (NR-018). A component table needs rows.

- Deliverable: the fallback sentence now, the table later.

> The register records the total airborne mass, 25.698 kg (NR-018). A component-level breakdown comes when the register signs those rows.

- Request the component rows from `@science-validator`: rings, lines, blades, lifter, other.

#### SW2g. The section 3.3 order pass (the room note item)

The section mixes three fact classes now: outcome, machine, era. The proposal groups them in the walk order.

- Block 1, the outcome. The lead sentences, the operating table, the swing, the settle, the speed and mass sentences.

- Block 2, the margins. The gate sentence and the gate table.

- Block 3, the machine. The lifter role, the load path, the launch, the sizing basis.

- Then the autogyro assumption, the geometry, the blade scales and the bank gene.

- Block 4, the era note.

The text does not change. The order only. `@author` owns the edit. This seat supplies the check form and sweeps the move.

### SW3. The Discussion fact tables (feedback parts 11.2 and 11.3)

#### SW3a. The failure-ledger table (item 11.2)

- The prose ledger seats at section 4.2. The pass converts it to a table. The prose stays after it.

- Draft columns: date and event, class, what happened, detection, correction or lesson, status.

- Six entries land in the table. The entries: inverted-taper divergence, rotor-to-ring off-by-one, blade-mass-law correction, k-alignment fault, stale-gain re-gate, FoS=Inf guard gap.

- Grounding: each cell maps to its trust-log row or its section 4.2 line in a working copy. Dates are identifiers. The k-alignment values 1.94 and 5.18 kW keep the section gate line until rows sign: "2.24 holds a register row (NR-015). The other values need rows first."

- Deps: `@author` keeps the narrative after the table, `@science-validator` signs any minted rows.

#### SW3b. The era map (item 11.3)

- The table lands at section 4.2 or beside the era note in section 3.3. The placement call sits with `@author`.

- Draft rows, four eras. The eras: before the bank derate, the bank-derate basis, the cp fix and the folded class, the wind-authority era.

- Each row carries its effect on the search space and the data status. The register rows NR-019, NR-020, NR-027 and NR-028 carry the grounds. The era names take the forms the register header and the provenance stamps already use.

- Check: grep the reporting tree for each era name before the fold. A name with no glossary row goes to Track D.

### SW4. Sweeps

- Sweep 14 runs at the next draft push. The span runs from sweep 13 to the push. The section breaks the token diff per push when the room skips a push.

- The new blocks enter the sweep checks: the term sites, the new tables, the order pass.

- The four old-form instances in the figure texts (F4, F6, F7, F9) flip with their passes. The sweep tracks them.

- Findings go to the room as exact replacement text, gate-simmed first.

## Part map (not this seat)

- `@author`: parts 1, 2, 5, 6.1, 6.3, 8, 9, 10. Further parts: 11.2 (the narrative), 12, 14, 15, 16 Priority 4, 17.

- `@science-validator`: the row signing for `@aero-validator` W2, W3, W4 and W7. The claim-evidence matrix rows (part 2). The display and derived-row requests of this plan.

- `@fig-img-diagrams`: parts 13 and 16 Priority 3. The caption and legend forms for the score term.

- `@aero-validator`: W1 to W8 in its own plan. The penalty breakdown table (part 3).

- `@hermes`: coordination and routing.

## Order for 2026-10-13

1. SW1: the term text and the display-note request. The author folds first.

2. SW2: the Results tables and the section 3.3 order proposal.

3. SW3: the ledger table and the era map.

4. SW4: sweep 14 after the push.

## Guards

- No signed value changes value. No figure moves.

- Cite signed rows only. Held values stay held.

- The STE gate runs at `--fail-above 2.0` on every commit.

- Narrow commits. One file, one writer. Receipts land in `scratch/` under `sw_`.
