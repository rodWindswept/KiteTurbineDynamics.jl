# Draft consistency sweep: the running record

**Slug** `draft-consistency-sweep`. **Status** LIVE. **Seat** science-writer.

**Scope** the report draft against the numbers register. A read-only pass.
The sweep changes no register row and no draft line. This record is its only
artifact.

**Method.** Each sweep runs four checks:

- The STE gate by hand. Command: `python3 ste-lint.py --fail-above 2.0 <file>`.

- A grep for retired solver phrasing. Patterns: `adaptive`, `DifferentialEquations`.

- A value cross-check. Every printed value against its signed row or side block, at the quoted precision.

- A number-token diff. The current draft against the previous one. The pattern: `(?<![\w-])\d+(?:\.\d+)?(?![\w-])`. It ignores identifiers and dates.

## Sweep 1: v0.2, 2026-10-08

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at `25b9e91`.

**Register** `docs/reporting/numbers-register.md` at the same commit.

**Results**

- STE gate: words 2627, total 0, `per100w=0.00`, exit 0. The reading in the author note reproduces.

- Retired phrasing: no hit.

- Value cross-check: every printed value matches its row at the quoted precision.

- The checked set covers NR-001 to NR-018, the rotor-bank note, and the caption rows NR-017 and NR-018.

- Token diff against v0.1 (the attachment staged with the room message): zero value tokens dropped or altered.

- Five tokens arrived: 1.94, 5.18, 21.2, 25.0, 3.55. All five sit inside brackets. Four wait on register rows. The 3.55 arrival carries the non-operating flag.

- Two standalone "2" tokens left. Both were comment text that the fold replaced with the full answers.

**Finding**

One stale token, and no more. The header reads "cited by row ID (NR-001 to NR-018)". The register now carries signed NR-019 and NR-020.

The proposed replacement line, for the author seat:

> Status DRAFT. Numbers come only from signed register rows, cited by row ID.

The range form stales at each sign-off. The register stays the authority.

**Next run** at the next draft push.

## Sweep 2: v0.3, 2026-10-09

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at `0b0d7f1`
(the v0.3 pass). The file carries zero diff to the branch tip `35dec11`.

**Register** `docs/reporting/numbers-register.md` at `a443e26` (zero diff to the
tip). Includes the amended blocks: the rotor-bank note, the caption rows NR-017
and NR-018, the bank-derate rows NR-019 and NR-020, and the mechanism-pair and
ODE rows NR-021 to NR-026.

**Results**

- STE gate: words 2641, total 0, `per100w=0.00`, `em_dash=0`, exit 0.

- Retired phrasing: no hit.

- Value cross-check: every printed value matches its row or side block at the
  quoted precision. The checked set covers NR-001 to NR-018, the rotor-bank
  note, and the caption rows NR-017 and NR-018.

- Both v0.3 edits verify clean: the k bracket close and the NR-016 read.

- Rows NR-019 to NR-026 print no values in this draft, so nothing from them
  enters the value check yet.

- Number-token diff against v0.2 (at `25b9e91`): one arrival, all removals
  accounted.

  - Arrived: `3` (the v0.3 pass note).

  - Left: one duplicate `3.55` (the open k bracket collapsed to a single
    flagged mention). The open-requests bullets that carried the `§2.3` and
    `§3.3` references became status lines.

  - Held, inside their brackets: `1.94` and `5.18` (§4.2 ledger), `21.2` and
    `25.0` (§2.3 length screen), `3.55` (flagged non-operating).

**Finding**

The v0.3 pass closed the sweep-1 finding and retired the status range. The
header now reads "cited by row ID". No value discrepancy found.

One carry-note for the author seat: the §2.3 bracket reads "Step-ceiling and
protocol figures". The draft uses "figure" for a diagram elsewhere (§8). If
the intent is the step-law and protocol values, "values" may read cleaner.

**Next run** at the next draft push.

## Sweep 3: v0.5, 2026-10-09

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at `2432a77`
(the v0.5 pass). The file carries zero diff to the branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `a443e26` (zero diff to the
tip). Covers NR-001 to NR-026 and the appended blocks: the aero counter-read, the
rotor-bank note, the caption rows, the bank-derate rows and the mechanism-pair rows.

**Results**

- STE gate: words 3024, total 0, `per100w=0.00`, `em_dash=0`, exit 0.

- Retired phrasing: no hit on the solver patterns or the stale-phrase list. One
  near-hit reviewed and cleared: "without a rigid driveshaft" (§1) contrasts the
  shaft with a rigid drive, not a label for the TRPT.

- Value cross-check: every printed value matches its row or side block at the
  quoted precision. The checked set covers NR-001 to NR-018, the rotor-bank note,
  the caption rows NR-017 and NR-018, and the NR-026 fold values (`1.5` and the
  70° line angle).

- Rows NR-019 to NR-025 print no values. The length screen values and the
  fidelity counters stay inside their brackets.

- Arithmetic on the stated totals: the status mix sums to 930 (508 + 301 + 110 + 11).
  Three islands of 310 designs also give 930.

- Span note: this pass covers three pushes, v0.4, v0.4a and v0.5. No sweep ran
  since Sweep 2, so the token diff below closes the full span.

- Number-token diff, v0.3 to v0.5, per push:

  - v0.3 to v0.4: eight arrivals. `1.5` and `70` are the lift-spec fold, both
    rowed at NR-026. `2`, `3`, `8`, `10` and `11` are figure-map row refs from
    the margin-ask fold. `4` is the version token of the pass header. No removals.

  - v0.4 to v0.4a: no token change. The split pass moved line breaks only.

  - v0.4a to v0.5: six arrivals. `3.4` and `5` are the pass header. `6` and `7`
    arrive twice each, at the header and at the two seat markers. No removals.

- No value token dropped or altered across the span. Every arrival accounts to a
  named edit: a register-cited fold, a figure-map reference or a pass-note token.

**Finding**

No value discrepancy found.

The v0.4 pass applied the sweep-2 carry-note: the §2.3 bracket now reads
"Step-ceiling and protocol values". The v0.5 seats verify clean: each marker
names its slug and its source rows.

Held, inside their brackets: `1.94` and `5.18` (§4.2 ledger), `21.2` and `25.0`
(§2.3 length screen), `3.55` (flagged non-operating).

**Next run** at the next draft push.

## Sweep 4: v0.7, 2026-10-09

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at `a3d1496`
(the v0.7 pass), spanning the v0.6 pass at `eb0251d`. The file carries zero diff
to the branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `a443e26` (zero diff to the
tip). Covers NR-001 to NR-026 and the appended blocks: the aero and science
counter-reads, the rotor-bank note, the caption rows NR-017 and NR-018, the
bank-derate rows NR-019 and NR-020, and the mechanism-pair and ODE rows NR-021
to NR-026.

**Results**

- STE gate: words 3166, total 0, `per100w=0.00`, `em_dash=0`, exit 0. The reading in the push note reproduces.

- Retired phrasing: no hit on the solver patterns or the stale-phrase list.

- Value cross-check: every printed value matches its row or side block at the
  quoted precision. The checked set covers NR-001 to NR-018, the rotor-bank
  note, the caption rows NR-017 and NR-018, and the NR-026 fold values (`1.5`
  and `70`).

- The span adds no new value. The v0.5 checks carry forward.

- Arithmetic on stated totals: the status mix sums to 930 (508 + 301 + 110 + 11).
  Three islands of 310 designs also give 930.

- References counts: the section 7 line reads 15 of 18 verified, 3 pending.
  `references-verification.md` carries the same counts.

- Span note: this pass covers two pushes, v0.6 and v0.7. No sweep ran since
  Sweep 3, so the token diff below closes the full span.

- Held tokens: `21.2` and `25.0` inside the §2.3 length-screen bracket. `3.55`
  inside its flag bracket. `1.94` and `5.18` in the §4.2 ledger prose, gated by
  the closing note "the other values need rows first".

- Number-token diff, v0.5 to v0.7, per push:

  - v0.5 to v0.6: four arrivals. `3.5` and the two `9` refs are the strip seat.
    `6` is the version digit. Eight occurrences added, four removed, in the two
    heading joins. No value token arrived or left.

  - v0.6 to v0.7: two arrivals. `3.3` is the lift-spec seat in the pass note.
    `7` is the version digit. The `70` of the lift spec persists through the
    line edit. No value token arrived or left.

  - Net across the span: six arrivals. No value token dropped, arrived or
    altered. Every arrival is a section reference or a version digit.

  - Push-note check: the v0.7 note reads "+8 numeric tokens, none lost". The
    recount confirms nothing left. Added: eight at v0.6, three at v0.7.
    Removed: five. Net: six.

**Finding**

No value discrepancy found. The v0.6 strip seat and the v0.7 lift-spec passage
verify clean.

**Next run** at the next draft push.

## Sweep 5: v0.8, 2026-10-09

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at `11eb78e`
(the v0.8 pass). The file carries zero diff to the branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `f86228a` (zero diff to the
tip). Covers NR-001 to NR-026 and the appended blocks: the aero and science
counter-reads, the rotor-bank note, the caption rows NR-017 and NR-018, the
bank-derate rows NR-019 and NR-020, the mechanism-pair and ODE rows NR-021 to
NR-026, and the wording amends (NR-022, NR-025).

**Results**

- STE gate: words 3199, total 0, `per100w=0.00`, `em_dash=0`, exit 0. The reading in the push note reproduces.

- Retired phrasing: no new hit. The §1 contrast line "without a rigid driveshaft" stays the only near-hit, cleared in Sweep 3 and unchanged here.

- Value cross-check: every printed value matches its row or side block at
  the quoted precision. The checked set covers NR-001 to NR-018, the
  rotor-bank note, and the caption rows NR-017 and NR-018. The span adds
  no new value, so the Sweep 4 set carries forward.

- The two cited commits resolve in the tip ancestry. `570be73` carries the science counter-read. `f86228a` carries the wording amends. The bracket sentence on future quotes matches the rule in the amends block.

- The amended quote forms print no value in this draft. They stand as rules for future prose.

- Arithmetic on stated totals: the status mix sums to 930 (508 + 301 + 110 + 11). Three islands of 310 designs also give 930.

- Held tokens: `21.2` and `25.0` inside the §2.3 length-screen bracket.
  `3.55` inside its flag bracket. `1.94` and `5.18` in the §4.2 ledger
  prose, gated by the closing note "the other values need rows first".
  No held token moved in this span.

- Number-token diff against v0.7 (at `a3d1496`): one arrival, no removals. The arrival is the `8` of the v0.8 pass note, a header artifact. No value token arrived, dropped or altered.

- Push-note check: the v0.8 note reads "delta +33 words (8 insertions, 3 deletions)". The recount holds: the diff stat reads 8 insertions and 3 deletions, and the word count moves 3166 to 3199. The additions-only claim holds for the numeric tokens, with the lone header digit excepted. No figure fold and no new term arrives in the span.

**Finding**

No value discrepancy found. The closed counter-read fold and the open-requests
update verify clean. No new domain term arrives.

**Next run** at the next draft push.

## Sweep 6: v0.9, 2026-10-09

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at `e0abbce`
(the v0.9 pass). The file carries zero diff to the branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `f86228a` (zero diff to the
tip). Covers NR-001 to NR-026 and the appended blocks: the aero and science
counter-reads, the rotor-bank note, the caption rows NR-017 and NR-018, the
bank-derate rows NR-019 and NR-020, the mechanism-pair and ODE rows NR-021 to
NR-026, and the wording amends (NR-022, NR-025).

**Results**

- STE gate: words 3263, total 0, `per100w=0.00`, `em_dash=0`, exit 0. The
  push-note readings reproduce (v0.8 read 3199, the fold sim read 3234).

- Retired phrasing: no new hit. The §1 contrast line "without a rigid
  driveshaft" stays the only near-hit, cleared in Sweep 3 and unchanged here.

- Value cross-check: the span adds no value token. The lift text and the
  extension sentence carry none. The pass note contributes only its header
  digit. The checked set of Sweeps 4 and 5 carries forward.

- The two cited commits resolve in the tip ancestry. `570be73` carries the
  science counter-read. `f86228a` carries the wording amends. No new commit
  quote arrives in the span.

- Arithmetic on stated totals: the status mix still sums to 930 (508 + 301 +
  110 + 11).

- Held tokens: `21.2` and `25.0` inside the §2.3 length-screen bracket.
  `3.55` inside its flag bracket. `1.94` and `5.18` in the §4.2 ledger
  prose, gated by the closing note "the other values need rows first".
  No held token moved in this span.

- Number-token diff against v0.8 (`11eb78e`): two arrivals, no removals.
  Both are header artifacts: the `9` of the v0.9 pass note and the `2.1`
  of its §2.1 reference.

- No value token arrived, dropped or altered. The fold-sim to landed diff
  carries the pass note and the extension sentence, nothing else.

- Push-note check: the v0.9 note quotes the fold readings (words 3199 to
  3263, sim 3234) and the sim-to-landed diff as the pass note plus the
  extension line. The recount holds, and the commit stat reads 11 insertions
  and 4 deletions.

**Finding**

No value discrepancy found. The §2.1 lift lands clean: the handed blocks
rode untouched, the blessed extension sentence folded at the count block,
both §2.1 brackets stay open, no figure fold, and no new domain term
arrives (`vertex` rides the candidates count row).

**Next run** at the next draft push.
