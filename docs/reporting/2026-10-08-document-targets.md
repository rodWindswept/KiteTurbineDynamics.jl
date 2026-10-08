# Document targets and status: the running account

**Slug** `document-targets`

**Date** 2026-10-08. **Status** LIVE. **Owner** @hermes (lead). **Readers**
all report-team bots and Rod.

## 1. Purpose

The room keeps one running account of the targets of the report. It names the
budget of each section, the current status, the next gate and the owner.

The room works to these numbers. The numbers move only when work lands.

A change commits like any doc change. At each milestone, @hermes reconciles
the rows against the repo artifacts and reports the deltas to the room.

## 2. The report budget (proposed targets)

Main body target: about 10,000 words, about 20 A4 pages in the assembled PDF,
10 to 12 figures, 4 to 6 tables. Rod confirms these numbers (open item 1).

| # | Section (scientific structure) | Unit | Words | Figures / tables | Owner | Status | Next gate |
|---|---|---|---|---|---|---|---|
| 1 | Title, authors, abstract, keywords | - | 250 | 0 | @author | not started | Write last, from the signed register |
| 2 | Introduction | U1 | 1,200 | 1 figure | @author + @science-writer | prep (`outline/awe-context-outline.md` v1) | Track A reconciliation, then draft prose |
| 3 | Methods | - | 1,800 | 2 figures + 1 table | @science-writer | not started | Register v1 + physics-topology |
| 4 | Results: levers | U2 | 1,500 | 4 figures + 1 table | @figures-images-diagrams + @science-writer | not started | Landscape Phases 1 to 2 |
| 5 | Results: evolution | U3 | 1,200 | 2 figures | @figures-images-diagrams + @author | prep (figures/machine-renderer SPEC v1, R1 mock) | Phase 3 + renderer |
| 6 | Results: design implications | U4 | 1,000 | 1 table | @science-writer + @figures-images-diagrams | not started | Phase 3 regime table |
| 7 | Discussion: failure ledger + boundaries | U6 | 1,200 | 0 | @author + @science-writer | not started | Track B + the trust log |
| 8 | Conclusion: achievements | U5 | 700 | 0 | @author | not started | Signed register |
| 9 | Nomenclature | - | 500 | 0 | Track D | prep (`glossary-candidates.md` v3) | Track D ratification |
| 10 | References | - | 25 entries | 0 | @science-writer | prep (seed a7ca235, 15 of 18 verified) | 3 source calls, then sources verified |
| 11 | Data availability + Reproducibility | - | 400 | 0 | @software-validator | not started | Assembly |

Row sum: about 9,750 words, 9 figures, 3 tables. The headroom (1 to 3
figures, 1 to 3 tables) sits in the budget for the sections that grow as
Phases 1 to 3 land.

Row 10 detail: @author seeded references.bib at a7ca235 with 18 entries.
The verification pass e272e6a checks 15 of 18. Three entries wait for a
source call.

## 3. Status vocabulary (fixed set)

The production states:

- **not started**, no artifact exists.
- **prep**, an outline, a spec or a seed exists.
- **drafting**, prose or a figure is in production.
- **room check**, waiting on Track A/B reconciliation.

The release states:

- **validator gate**, with a validator (science, aero or software).
- **signed**, a validator signature sits in the repo.
- **assembled**, in the single report document.
- **released**, shipped to the channels per framework section 8.

## 4. The update loop

1. The owner bot updates its row when work lands. The update goes in the same
   commit or the one right after it. The commit message names the row.

2. @hermes reconciles the rows against the repo artifacts at each milestone:
   register v1 sign, the end of each landscape phase, whole-report assembly.

3. At each milestone @hermes posts the deltas to the room: rows moved, rows
   stuck, rows whose gate slipped. The room re-plans only the slipped rows.

4. This doc is the account of the room. The repo stays the authoritative
   record, with the same discipline as the numbers register.

## 5. Conventions ledger (rulings that bind every section)

1. **Acronyms.** Spell out at first use. Rod ruling 2026-10-08: write
   "ordinary differential equation (ODE)", never bare "ODE" at first use.
   The rule binds every acronym in the report, TRPT and MTR included.

2. **Numbers.** A number reaches prose only from a signed register row, by
   row ID.

3. **Captions.** Every figure carries the dual caption: one plain-English
   sentence and the technical caption.

4. **Voice.** First person, no AI voice, numbers exact.

5. **Failures.** Each failure enters the report with its stated lesson
   (Track B).

6. **Boundaries.** The Track E boundaries are mandatory statements, not
   footnotes.

7. **Terms.** Writers use glossary terms only. A shortcut term with no entry
   is a release blocker, gated like a number.

8. **Rotor model.** A banked rotor uses the cp/ct disc model with the
   cos(bank)^2.65 derate on power (physics-topology section 4.0.1).
   Bank is not yaw.
   The banked expansion model is banned.
   The derate does not extend to thrust.

9. **Machine figures.** A machine figure draws the built state only: decode,
   build, render. No re-derivation. A spec fixes no values. Every slot
   resolves at GENERATE, bound to the register.

## 6. Open items for the room

1. **Budget sign-off.** Rod confirms the section budgets in section 2. Until
   then they stay proposals, not rulings.

2. **References source calls.** Three entries wait for a source decision:
   Ranneberg EK_FT_0018, the Jamieson deck, the Hancock deck. The options sit
   in references-verification.md. They block nothing else.

3. **Subagent dispatch.** When the budgets hold, split the remaining
   production into work items: section drafts, figure specs, `references.bib`,
   the machine renderer. Launch subagents against those items. Each work item
   reads this doc first, so the whole amount of work runs against one plan.

## Deltas

- v2 (2026-10-08): rows 4 to 6 pin the figures seat as
  @figures-images-diagrams.
  Row 5 moves to prep (renderer SPEC v1, R1 mock, seed c84f874).
  Row 9 cites glossary v3.
  Row 10 gains its owner @science-writer (ruling 3a78490) and its seed
  status (a7ca235, e272e6a).
  The references-owner open item closes.

- Ledger rules 8 and 9 join. The framework doc pins the same seat name in
  four places (section 4 table, section 6 item 3).
