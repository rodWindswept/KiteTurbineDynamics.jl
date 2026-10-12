# Feedback round 2: aero-validator seat plan

**Date drafted:** 2026-10-13 (overnight pass)
**Seat:** `@aero-validator` (aero analysis and validation support)
**Source:** `docs/reporting/feedback/feedback-on-report2.md` (landed 2026-10-12 23:10, 18 parts)
**Instruction:** the user asked every seat to read the complete set of recommendations and prepare plans for its own parts. Save the plans for execution tomorrow (2026-10-12 23:13 and 23:30).

## Coverage

I read all 18 parts of the feedback document. This plan covers the parts that need work from this seat. A map at the end lists the parts that sit with other seats.

## Already landed from this seat (context, not new work)

- The section 2.3 explanation pass and the window term rename: commits `b14f87b` and `f96e96b`.

- This covers the window definition ask from the feedback in substance. It describes the 10 s relax run, the 40 s measurement window, the fixed k and the fixed length.

- The window-trace extract: `6175f83` (`docs/reporting/figures/window-trace-extract/`), the row-4 data.
- The NR-041 counter-read (`7b3fc8c`) and the NR-013 extension counter-read (`4616641`). Both read clean. The validation-table items from the feedback now have row-backed digits.

## Work items

### W1. Define the campaign line length (feedback §6.2 and §16 Priority 1)

The feedback asks what "line" means in "line length of 18.8 metres (NR-015)". It says to correct the meaning if it differs.

- Work: confirm the scored quantity against the code. The leading candidate is `tether_length`, the unstretched total TRPT length L0 (`src/parameters.jl` line 44).

- Then draft the definition clause for @author.

- Deliverable: a proposed sentence: "The campaign line length is the unstretched total TRPT length L0, 18.8 m (NR-015)."

- The second sentence separates it from the lift-line geometry of section 3.3.

- Acceptance: the clause names the quantity, its datum and its unit. The length-screen rows (NR-027) stay consistent. No value changes.
- Deps: @author folds. @science-validator checks the row pointers.

### W2. Wind profile table values (feedback §6.2)

The feedback asks for the scored wind profile in a table and marks the parameters as unsigned.

- Work: pull the scored parameters from the dated records (regime, shear form, reference height, reference speed, hub speed, ground speed).

- Separate signed values from unsigned ones.

- Deliverable: a filled table with a source per cell. Unsigned cells carry the "cited by register row" note.
- Acceptance: every filled cell maps to a dated record. No value enters the draft without a row.
- Deps: @science-validator signs new rows.

### W3. NR-009 to NR-021 FoS reconciliation (feedback §7.5 and §16 Priority 1)

The feedback asks where the 14.972 window minimum FoS comes from, since the ring plate reads 15.033.

- Work: trace the gated minimum to its element and time step. Write the reconciling sentence.
- Deliverable: a short note with the trace, a proposed sentence, and row pointers.
- Acceptance: the trace reproduces from stored bytes. The sentence separates the global gated minimum from the final-step ring readout.
- Deps: @science-validator counter-reads.

### W4. Penalty breakdown for the 1.665 kg-equivalent (feedback §3)

The feedback asks for the objective penalty split by source, or an explicit unsigned statement.

- Work: probe the objective terms for the winner. List each contributing penalty with its stored value.
- Deliverable: a breakdown table with row support, or a fallback sentence. The fallback would state that the register records the total and that the breakdown follows the rows.
- Acceptance: the parts sum to 1.665 kg-equivalent at stored precision, or the fallback lands. No invented terms.

### W5. Warm-path gate fix support (feedback §6.4, §11.1, §11.4)

The feedback asks to make the path finding impossible to miss. It also asks to restrict the rope-break gate to the measurement window, "as ruled". That placement is not yet in the code. The fix-or-drop call (decision 5) sits with @user.

- Work, fix branch: support the evaluator gate change.

- Re-run the three winners on the warm path. Mint the fresh rows.

- Work, drop branch: keep the condition-run framing.

- Make sure the section 11.1 table cites the NR-013 extension block.

- Deliverable, fix branch: a validated re-gate with rows. Deliverable, drop branch: the framing note.
- Acceptance, fix branch: the warm path no longer false-rejects at stored precision, and cold parity holds. Acceptance, drop branch: the table and its caption name the basis.
- Deps: the @user decision and a code seat for the evaluator change (@hermes to route).

### W6. Figure data support (feedback §13 and §16 Priority 3)

Figures 3 and 7 draw from existing extracts (the cold dense extract, the window-tap extract, the F3 kit inputs). Figure 12 needs dated correction events. Figure 13 needs the winner provenance chain.

- Work: answer figure data requests. Mint provenance-stamped extracts as needed.

- Supply the event dates and chain pointers held by this seat.

- Deliverable: extracts and lists on request from @fig-img-diagrams. No drawing work comes from this seat.
- Acceptance: every plate draws from committed bytes. Provenance stamps hold.

### W7. Clearance margin numeric (feedback §7.4, scoping item)

The feedback asks for a number "if available".

- Work: check whether the clearance gate stores a usable margin. If yes, propose the value and row. If no, the current "pass" stands.
- Deliverable: the value plus a row, or the "pass" note with the reason.
- Acceptance: any derivation reads from stored values. @science-validator signs.

### W8. Term guard during folds (feedback §6.2 and §13 captions)

The feedback text uses "honest window". The report form is "measurement window" (section 2.3, glossary v10, the nine-figure brief).

- Work: check each adopted text and caption for the old form as the folds land. Flag stragglers to @author.
- Deliverable: flags in the sweep receipts.
- Acceptance: no adopted report text returns to the old form. The feedback record itself stays untouched.

## Part map (not this seat)

- @author: parts 1, 2, 5, 6.1, 6.3, 8, 9, 10.

- @author, further parts: 11.2, 12, 14, 15, 16 Priority 4, 17.

- @science-writer: parts 3, 4, 7, 11.2, 11.3, and the sweeps.
- @science-validator: row signing for W2, W3, W4 and W7. Also the claim-evidence matrix rows (part 2).
- @fig-img-diagrams: parts 13 and 16 Priority 3.
- @hermes: coordination and routing, including the W5 code seat.

## Order for 2026-10-13

1. W1, W2, W3: draft-facing items. They feed the author early.
2. W4 and W7: evidence items.
3. W5 waits behind the user decision. W6 answers figure requests. W8 runs continuously.

## Guards

- No signed value changes value. No figure moves.
- STE gate at `--fail-above 2.0` on every commit.
- Narrow commits only. Receipts go in `scratch/`. Counter-reads read from committed bytes only.
