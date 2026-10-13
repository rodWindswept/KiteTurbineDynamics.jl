# Feedback round 2: science-validator seat plan

**Date drafted:** 2026-10-13 (overnight pass)

**Seat:** `@science-validator` (data validation, register signing, second-read verification)

**Source:** `docs/reporting/feedback/feedback-on-report2.md`, landed 2026-10-12 23:10, 18 parts.

**Instruction:** the user asked every seat to read the complete set of recommendations and prepare plans for its own parts. Save the plans for execution tomorrow.

## Coverage

I read all 18 parts of the feedback document.

This plan covers the validation, data verification, and register signing work for this seat.

A map at the end lists the parts that sit with other seats.

## Already landed from this seat (context, not new work)

- Display-form note signed in `docs/reporting/numbers-register.md` (`43fb0bc`).

- Objective values display as kg-equivalent (NR-003 to NR-006, NR-036, NR-039).

- Physical mass keeps kg (NR-018).

- Fitness decomposition signed in NR-039 (`7b3fc8c`).

- The decomposition reads mass 25.698 kg plus 1.665 kg-equivalent of penalties.

- NR-013 extension signed for the F3 timeline (`21e941d`), with clean aero counter-read (`4616641`).

- Least segment torque margin 2.03 at S1 signed (NR-040).

- Lift-line derived set signed (NR-037).

- Window trace endpoints signed (NR-038).

## Work items

### SV1. Status mix share derivations (feedback §7.1, §16 Priority 2)

The feedback asks for a status mix table with percentage shares on the 930 evaluation base.

- Work: derive and sign percentage share rows on the base 930 from the counts on NR-002.

- Deliverable: signed derived share rows.

- The rows read ok 54.6%, reject 32.4%, clearance_reject 11.8%, and reject_twist 1.2%.

- Acceptance: shares sum to 100.0% at one decimal place. Derivation recipe pinned to NR-001 and NR-002.

- Deps: feeds `@science-writer` SW2a and `@author`.

### SV2. Claim-evidence matrix row audit (feedback §2, §16 Priority 2)

The feedback asks for a claim-evidence matrix linking every major claim to signed register rows.

- Work: audit the row pointers for each claim in the proposed matrix.

- Claims to audit: campaign scale (NR-001, NR-002), winner power (NR-008), winner mass (NR-018), and structural margin (NR-009, NR-021).

- Further claims: twist and torque margin (NR-022, NR-040), search improvement (NR-003 to NR-006), instrument fidelity (NR-012, NR-013), and model boundaries (PRD 0006:147).

- Deliverable: verification receipt certifying that every matrix entry maps to a signed row.

- Acceptance: zero unbacked claims in the matrix.

- Deps: `@author` drafts the matrix.

### SV3. Wind profile parameter signing (feedback §6.2)

The feedback asks for a scored wind profile parameter table anchored to the Daisy flight reference.

- Work: review and counter-read the parameter extracts prepared by `@aero-validator` (W2).

- Parameters: shear model form, reference height, reference speed, hub-height speed, and ground speed.

- Deliverable: signed register rows for verified values. Sign unconstrained boundary notes where parameters remain model assumptions.

- Acceptance: every signed cell reproduces from dated Daisy records and runner configs.

- Deps: `@aero-validator` supplies W2 extracts.

### SV4. FoS reconciliation second-read (feedback §7.5, §16 Priority 1)

The feedback asks to explain the difference between the global window-minimum FoS 14.972 (NR-009) and the final-step hub ring FoS 15.033 (NR-021).

- Work: counter-read the trace and reconciling sentence drafted by `@aero-validator` (W3).

- Deliverable: signed second-read note.

- The note confirms that NR-009 is the window minimum, while NR-021 is the final capture step readout.

- Acceptance: trace reproduces bit-for-bit from stored re-eval bytes.

- Deps: `@aero-validator` supplies W3 trace.

### SV5. Gate margin derived set (feedback §7.4, §16 Priority 2)

The feedback asks for numeric gate margins rather than bare pass or fail markers.

- Work: derive and sign margin rows for the winner gate table.

- Rows to derive: power floor margin (+0.309 kW, +6.2% above 5.0 kW floor, NR-008 / NR-027).

- Structural margin: FoS margin ratio 5.99x floor (NR-009 / NR-015). Torsional margin: 2.03 at S1 (NR-040).

- Review `@aero-validator` W7 scoping for numeric blade clearance. Sign numerical clearance if logged, or certify pass status.

- Deliverable: signed derived margin block in the register.

- Acceptance: all margins trace to signed base rows with exact recipes.

- Deps: `@aero-validator` W7, feeds `@science-writer` SW2d.

### SV6. Mass budget component scoping (feedback §7.6)

The feedback asks for a mass budget breakdown across rings, lines, blades, and lifter stack.

- Work: probe decoded build geometry (`build_system_from_v10`) and stored mass model outputs.

- Deliverable: sign component rows if masses verify at stored precision.

- If not ready, sign the total mass (25.698 kg, NR-018) and net sizing mass (20.698 kg, NR-037) with the fallback statement.

- Acceptance: component sum equals 25.698 kg at stored precision, or fallback statement stands.

- Deps: feeds `@science-writer` SW2f.

### SV7. Instrument trust, failure ledger, and era map audit (feedback §6.4, §11.1, §11.2, §11.3)

The feedback asks for structured tables for evaluation fidelity, the failure ledger, and project eras.

- Work: audit the six failure ledger entries against repository trust logs and commit records.

- Audit the four era boundaries against register anchors (NR-019, NR-020, NR-027, NR-028).

- Deliverable: audit receipt verifying table dates, event classes, and status markers.

- Acceptance: every ledger date matches commit history. Every era maps to signed data anchors.

- Deps: feeds `@science-writer` SW3a and SW3b.

### SV8. Figure provenance and reproduction audit (feedback §13, §16 Priority 3)

The feedback proposes a 13-figure system.

- Work: audit data inputs and provenance manifests for new figures produced by `@fig-img-diagrams` (Figures 1 to 13).

- Deliverable: signed figure provenance stamps in `docs/reporting/figures/`.

- Acceptance: every plotted data series matches committed CSV extracts and signed register rows.

- Deps: `@fig-img-diagrams` produces figure drafts.

## Part map (not this seat)

- `@author`: parts 1, 2, 5, 6.1, 6.3, 8, 9, 10, 11.4, 12, 14, 15, 16 Priority 4, 17.

- `@science-writer`: parts 3, 4, 7, 11.2, 11.3, narrative sweeps (SW1 to SW4).

- `@aero-validator`: physics derivations and extracts W1 to W8 (line length, wind profile, FoS trace, penalty table, warm path, time series, clearance).

- `@fig-img-diagrams`: rendering and layout for Figures 1 to 13 (parts 13 and 16 Priority 3).

- `@hermes`: coordination, routing, and code seats.

## Order for 2026-10-13

1. SV1 (Status mix shares) and SV2 (Claim-evidence matrix): draft-facing support for author and writer folds.

2. SV4 (FoS reconciliation) and SV5 (Gate margins): sign derived rows as aero extracts land.

3. SV3 (Wind profile signing) and SV6 (Mass budget scoping): audit and sign component data.

4. SV7 (Ledger and Era audit) and SV8 (Figure provenance): continuous verification across report folds.

## Guards

- No signed value changes without a dated superseding row.

- No figure moves without a signed provenance stamp.

- STE gate at `--fail-above 2.0` on every commit.

- Narrow commits only. Receipts land in `scratch/sv_*.log`. Counter-reads read from committed bytes only.
