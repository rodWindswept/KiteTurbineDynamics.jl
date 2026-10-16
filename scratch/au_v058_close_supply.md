# Supply: the v0.58 close (the "Where this goes" block), author seat, 2026-10-16

**Status** SUPPLY. **Hands to** the science-writer prose pass. The fold waits on that pass.

**Base pin** `f8342d1` (local == origin at the supply).
**Draft base** `docs/reporting/drafts/2026-10-08-report-first-draft.md`, md5 `43ffc00e40b121010d882cf4726d6d5b` (v0.57).
**Companions** the value-claims ledger (`aa76367`, counter-read closed at `ba1a66f`). The section 5 baseline read sits at the science-writer seat (279 body words, STE 0.00/100w).

The seam fix takes science-writer option (b). The section 5 restatement of the section 3.6 recommended next steps cuts. One pointer sentence stands in its place. The labelled close lands as the only forward-looking block in section 5.

## 1. The seam opcodes

Cut (five sentences, 46 words):

- "The next work closes the model gaps."
- "Add blade structural checks and validate lifter modulation."
- "Extend the model to the launch and recovery sequence."
- "Extend the wind cases beyond the steady sheared profile."
- "The large structural margins suggest room for mass reduction, once those checks hold."

Stand in their place (16 words):

- "The next work closes the model gaps."
- "The recommended next steps sit in section 3.6."

The Daisy bracket keeps its bytes. The close inserts after it, before "## 6 Nomenclature".

## 2. The close text (as it lands)

**Where this goes.** This close is forward-looking. It states what the instrument does, then the programme targets. No line in it carries a register row.

The instrument sizes and scores kite-turbine designs. Its physics model stands on the published TRPT lineage, and the cross-check names the matches and the mismatches. Each dataset carries its era, its commits and its geometry fingerprint. The ladder instrument screens each rung and each length on the corrected model. The register, the test suite and the seat checks hold every number. Findings, corrections and retractions land in the record with their lessons.

The validated rung is the machine this report covers. The programme targets form the ladder above it, 7 to 50 kW. Each rung above it is a programme target, not a result. No repo artifact backs the rungs yet. One validation step at the Daisy scale comes first. The mission target is a displaced-cost metric, set out in phase G of the programme strategy.

## 3. The element map (sentence to class and ledger row)

Capability movement (paragraph 2). Rows are ledger section 2 unless said.

- "The instrument sizes and scores kite-turbine designs."
  Row 1, the solver: `src/`, `README.md`.
- "Its physics model stands on the published TRPT lineage, and the cross-check names the matches and the mismatches."
  Row 2: `docs/validation/2026-09-25-trpt-tulloch-model-crosscheck.md`.

- "Each dataset carries its era, its commits and its geometry fingerprint."
  Row 4: `dd3cc6a` on `bankderate2-results`.
- "The ladder instrument screens each rung and each length on the corrected model."
  Row 6: `scripts/ode_ladder_v13.jl`, `scripts/results/ladder_v13.csv`.

- "The register, the test suite and the seat checks hold every number."
  Row 7.
- "Findings, corrections and retractions land in the record with their lessons."
  Row 8, the trust practice.

Rows 3 and 5 (the campaign pipeline, the Daisy anchor) stay unused to keep the close tight. They remain classed for later value text.

Target movement (paragraph 3). Rows are ledger sections 3 and 4.

- "The validated rung is the machine this report covers."
  Section 4 row 1, the 5 kW rung: capability, solid.
- "The programme targets form the ladder above it, 7 to 50 kW."
  Section 3 row 2 and section 4 rows 2 to 7: target, open plus label. Code set only.

- "Each rung above it is a programme target, not a result." and "No repo artifact backs the rungs yet."
  Together these carry the plain label in prose.

- "One validation step at the Daisy scale comes first."
  Section 3 row 3: `reviews/2026-09-15-six-week-review.md`, `DECISIONS.md` [2026-09-15].
- "The mission target is a displaced-cost metric, set out in phase G of the programme strategy."
  Section 3 row 6: phase G of `docs/plans/2026-07-06-strategy-gate2-to-value-maps.md`. The offset figure prints nowhere.

Held: the cost and carbon set (ledger section 5) prints no digit. Withheld: the flagged set (ledger section 6) prints nothing in this fold. That set is the arrays, offshore, the offset figure, the product phrase, the yield line and the interior rungs. Each waits on a pointer or a room call.

## 4. Tokens

New target-class tokens: `7` and `50` (in "7 to 50 kW"). Both sit inside the close, under the label. The pointer adds one "section 3.6" reference.

No signed number repeats. No register row-ID token. No cost or carbon token. No screen value.

The outside-the-close scan carries declared neighbours. The pre-existing `50` mentions read as record context. They are the section 4.2 k-alignment lines, the NR-050 token and the hash lines. None is target ink.

## 5. Counts and the gate (the candidate simulation)

`scratch/au_v058_close_sim.py` (md5 `e2e48a535b6c320e97f000a0b1922866`) rebuilds the candidate `scratch/au_v058_close_draft_candidate.md` (md5 `0cb0d4b31a2fb254b636a63d7ebeaba3`) from the pinned base.

- Section 5 slice (heading to heading): 290 words to 421. The ops: cut 46, pointer 16, close 161 (with the block lead).
- ste-lint: total 8 to 8, no category gained (passive_voice 1, long_paragraph 7). Per100w reads 0.11 to 0.11. Em dash 2 to 2, both pre-existing and outside the close.

- Log: `scratch/au_v058_close_ste.log`.

## 6. The fold check plan

1. Line diff and the declared token diff. Every held form held.

2. The science-writer assertion pass, called by the fold. It checks zero new STE hits against the pre-fold section 5 baseline. It checks no em dash and no marketing or aspiration adjective inside the close. It checks value, station and state on any signed number it repeats (none repeats).

3. The outside-the-close scan: no target-class ink outside the close. Scan terms: the rung set forms, "programme target", "MVP", "offshore", "network", "gigatonne" and the label phrases. Declared neighbours sit in section 4.

4. The ledger binding: every close sentence stands in the map above. Anything unclassed does not print.

## 7. Handoffs

- @science-writer: the prose pass on the text in section 2. The fold calls it.
- @fig-img-diagrams: the caption pass rides `docs/reporting/figures/scaling-ladder/captions.md`. The plate folds into the close after its read closes.

- @aero-validator: the ledger consumed as seeded. No class change proposed. The withheld set stands.
- @science-validator: the close adds no signed cells. The fold read opens at the fold.
