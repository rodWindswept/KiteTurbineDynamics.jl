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

## Sweep 7: v0.11, 2026-10-11

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at `5ef236f`
(the v0.11 pass), spanning the v0.10 fold at `2d77c98`. The file carries zero
diff to the branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at the tip (no change since
`3730bec`, which carries NR-029 to NR-031). Covers NR-001 to NR-031 and the
appended blocks: the aero and science counter-reads, the rotor-bank note, the
caption rows NR-017 and NR-018, the bank-derate rows NR-019 and NR-020, the
mechanism-pair and ODE rows NR-021 to NR-026, the wording amends, the
length-screen rows NR-027 and NR-028, and the operating-point rows NR-029 to
NR-031.

**Results**

- STE gate: words 3444, total 5, `per100w=0.15`, `em_dash=0`, exit 0. The
  hook lines read `passive_voice x1` and `long_paragraph x4`.

- Retired phrasing: no hit.

- Value cross-check, span additions:

  - The lift-margin fold (v0.10, refolded at v0.11): the chain recomputes,
    1.5 × 20.69846825623688 × 9.81 = 304.5779603905257. The draft quotes
    304.58 at two decimals (304.578 at three; NR-026 hands the chain). The
    sizing mass 20.698 reads NR-018 minus the flat 5.0 kg booking. The
    margin 1.21 recomputes to 1.20815. 25.70 rounds NR-018 at two decimals.
    324.1 is NR-010.

  - The length screen: 18.8, 21.2 and 25.0 metres and the six-row count
    cross-read NR-027. The folded class at 18.8 m cross-reads NR-028.

  - The NR-029 citation: 13.38 rad/s and 127.772 rpm are the row's own
    quote forms; the rpm recomputes 127.77207.

  - The blade-scale and bank reads cross-read NR-011 and NR-017: 0.82,
    0.20, 7.088, 22 and the counts.

- Held tokens: `3.55` stays flagged non-operating in its bracket. `1.94`
  and `5.18` in the §4.2 ledger stay gated by "the other values need rows
  first". The `21.2` and `25.0` held tokens moved: the length screen now
  prints them under NR-027.

- Arithmetic on stated totals: the status mix still sums to 930
  (508 + 301 + 110 + 11).

- Number-token diff, v0.9 (`e0abbce`) to v0.11 (`5ef236f`), per push:

  - v0.9 to v0.10: fourteen arrivals, two removals. `1.2`, `1.8`, `3.7`
    and one `1.5` are the pass-note refs. `1.5`, `70`, `9.81`, two `20.70`,
    `304.6`, `25.70` and `1.21` are the lift-margin fold, all rowed
    (NR-026, NR-018, NR-010). `18.8` arrives with the screen text and the
    fold statement. `10` is the version digit of the pass header. Removals:
    `2.3` (the closed screen bracket drops its §2.3 ref) and `8` (the slot-8
    sentence reworded to "a second bank slot").

  - v0.10 to v0.11: nine arrivals, three removals. `13.38` and `127.772`
    are the NR-029 citation. Two `20.698`, `20.698468` and two `304.58` are
    the register chain and the sizing mass; two `20.70` and `304.6` leave
    with them. `11` is the version digit; `3.3` is the pass-note ref.

  - Net: every arrival and removal accounts to a named fold, a register
    citation or a pass-note token.

**Finding**

No value discrepancy found. The v0.11 fixes verify clean against their rows.
The pass also carries the glossary candidates at v8 (the TSR row tightening);
that file sits outside this gate.

One carry-note for the room: the lift-margin sentence reads "The same
tension over the full airborne mass ... gives a margin of 1.21". The 1.21 is
the vertical load over the full weight (1.20815). A reader who divides the
324.1 N tension by the full weight reads 1.29. The item 1.2 text stands; the
room flags it for a wording pass only if it wants the line tighter.

**Next run** at the next draft push.

## Sweep 8: v0.12, 2026-10-11

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`be27cc7` (the v0.12 pass). The file carries zero diff to the branch tip at
sweep time.

**Register** `docs/reporting/numbers-register.md` at `25ff00e`, zero diff to
the tip. Covers NR-001 to NR-036: the counter-reads, the rotor-bank note, the
caption and bank-derate rows, the mechanism pair, the wording amends, the
length screen, the operating-point rows NR-029 to NR-031 and the re-base and
derived rows NR-032 to NR-036.

**Results**

- STE gate: words 3482, total 5, `per100w=0.14`, `em_dash=0`, exit 0. The
  hook lines read `passive_voice x1` and `long_paragraph x4`. The push-note
  readings reproduce (words 3444 to 3482, total 5 to 5).

- Retired phrasing: no hit. The §1 contrast line "without a rigid
  driveshaft" stays the only near-hit, cleared in Sweep 3 and unchanged
  here.

- Value cross-check. The v0.12 pass note carries no value. Its two commit
  quotes resolve in the tip ancestry: `25ff00e` and `b434ded`.

- The §3.3 wording swap recomputes: the vertical load 304.5779604 N over
  the full airborne weight 252.1019736 N reads 1.20815, quoted 1.21. The
  tension chain reads 324.1250954, NR-010 at 324.1. The displayed-operand
  chain reads 304.58.

- The re-base rows NR-032 to NR-034 print no value in this draft. The
  derived rows NR-035 and NR-036 also print none. Nothing from them enters
  the value check yet.

- Held tokens: `3.55` stays flagged non-operating in its bracket. `1.94`
  and `5.18` in the §4.2 ledger stay gated by "The other values need rows
  first". The NR-031 hold lifts with this pass, and no printed value waited
  on it.

- Arithmetic on stated totals: the status mix still sums to 930
  (508 + 301 + 110 + 11). Three islands of 310 designs also give 930.

- References counts: the §7 line reads fifteen of eighteen verified and
  three pending. `references-verification.md` carries the same counts.

- Superseded forms: the draft prints no retired value (63.8695, 20.1056,
  14.4651, 14.46, 0.101631) and no NR-031 quote form (5.566, 0.2944,
  0.1016). A grep over the draft at the tip reads no hit.

- Number-token diff against v0.11 (`5ef236f`): four arrivals, no removals.
  All four are pass-note artifacts: `12` and `11` are version digits, `7`
  the Sweep 7 reference, `3.3` the section reference. No value token
  arrived, dropped or altered.

- Push-note check: the v0.12 note reads 4 arrivals (`12`, `11`, `7`, `3.3`)
  and 0 removals, and the recount holds as the net. Five raw added
  occurrences and one raw removal (`25.70` rides the swapped sentence). The
  commit stat reads 7 insertions and 1 deletion on the draft file.

**Finding**

No value discrepancy found. The Sweep 7 carry-note closes: the §3.3
sentence now reads the vertical load over the full airborne weight, and it
recomputes its own 1.21. The hold lift prints no value, and no
NR-031-dependent token waits inside the draft.

**Next run** at the next draft push.

## Sweep 9: v0.14, 2026-10-12

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`13973f2` (the v0.14 pass), spanning the v0.13 pass at `62fcd5e`. The
file carries zero diff to the branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `25ff00e` (zero diff
to the tip, no change since Sweep 8). Covers NR-001 to NR-036 and every
appended block through the re-base and derived rows.

**Results**

- STE gate: words 3864, total 5, `per100w=0.13`, `em_dash=0`, exit 0.
  The hook lines read `passive_voice x1` and `long_paragraph x4`, both
  pre-existing and unchanged from v0.13. The pass readings reproduce
  (words 3667 to 3864, total 5 to 5).

- Retired phrasing: no hit.

- Value cross-check, span additions:

  - v0.13: six arrivals, no removals. `13` x2 are version digits. `3.4`
    and `3.6` are draft-status section refs. `1` and `3` are the phase
    numerals. `5` is the `5 kW-class` class descriptor (glossary-flagged,
    no row class). No value token.

  - v0.14 arrivals: five, against one removal. `930` cross-reads NR-001
    (3 x 310, and the census sums to 930). `5.309` cross-reads NR-008 at
    the row quote form (full precision 5.3087794439367935). `14.972`
    cross-reads NR-009 (full precision 14.971791422208508).

  - v0.14 non-value tokens: `14` x2 are version digits (the header bump
    and the pass note). The removed `13` is the header version digit the
    bump moved. `5` arrives a second time in the abstract.

  - The abstract cites NR-001, NR-008, NR-009, NR-021 and NR-022, all
    signed.

  - The safety line prints no value. NR-022 holds `has_limit true` on all
    five segments, and NR-021 holds the ring checks at the same capture.

- Arithmetic on stated totals: the status mix sums to 930 (508 + 301 +
  110 + 11). Three islands of 310 designs also give 930.

- References counts: the section 7 line reads fifteen of eighteen
  verified and three pending. `references-verification.md` carries the
  same counts.

- Held tokens: `3.55` stays flagged non-operating in its bracket. `1.94`
  and `5.18` in the section 4.2 ledger stay gated by "The other values
  need rows first". No held token moved.

- Superseded forms: the draft prints no retired value (63.8695, 20.1056,
  14.4651, 14.46, 0.101631) and no NR-031 quote form (5.566, 0.2944,
  0.1016). A grep over the draft at the tip reads no hit.

- Number-token diff against v0.12 (`be27cc7`), per push:

  - v0.12 to v0.13: six arrivals, no removals (the set above).

  - v0.13 to v0.14: five arrivals, one removal (the set above).

  - Net: every arrival and removal accounts to a named edit: a version
    digit, a section ref, a phase numeral or a register-cited abstract
    value. No value token dropped or altered.

- Push-note check, v0.13: the note reads 6 arrivals and no removals,
  words 3482 to 3667, diff 99/69. The recount holds.

- Push-note check, v0.14: the landing reads 5 arrivals and 1 removal,
  words 3667 to 3864, diff 33/3. The recount holds.

**Finding**

No value discrepancy found. The v0.14 abstract verifies clean against its
five cited rows. No held token moved. The v0.13 structural pass carries
no value token beyond the glossary-flagged class descriptor.

**Next run** at the next draft push.

## Sweep 10: v0.16, 2026-10-12

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`b33451f` (the v0.16 follow-up), spanning the v0.15 pass at `0e10114`,
the v0.16 split at `472f318` and the tidy at `f0e5070`. The file
carries zero diff to the branch tip at sweep time.

The room layer of the split sits in `docs/reporting/draft-tracker.md`,
with Deltas v1 and v2 pre-accounting this span.

**Register** `docs/reporting/numbers-register.md` at `25ff00e` (zero
diff to the tip, no change since Sweep 9). Covers NR-001 to NR-036 and
every appended block through the derived rows.

**Results**

- Span note: this pass covers the four pushes since Sweep 9 (v0.15, the
  v0.16 split, the tidy and the follow-up). The token diff below closes
  the full span, per push.

- STE gate: words 3230, total 4, `per100w=0.12`, `em_dash=0`, exit 0.
  The hook lines read `passive_voice x1` and `long_paragraph x3`. Both
  classes are pre-existing.

- The span readings (words/total): v0.14 3864/5, v0.15 3938/5, v0.16
  3292/4, tip 3230/4.

- The tracker reads 0.50 per100w at the split and 0.47 at the tip, exit
  0 both. That reading is context only, outside this gate.

- Retired phrasing: no hit on the solver patterns or the stale-phrase
  list. The section 1 contrast line "without a rigid driveshaft" stays
  the only near-hit, cleared in Sweep 3 and unchanged.

- Value cross-check: every printed value matches its row or side block
  at the quoted precision. The reader-facing set carries forward.

- The checked set spans: NR-001 (930, and the island 310), NR-002
  (508/301/110/11), NR-003 to NR-006, NR-007, NR-008 (5.309/5.314),
  NR-009 (14.972), NR-010 (324.1) and NR-011.

- The set continues: NR-014 (0.029), NR-015 (2.24/10/40/2.5/18.8),
  NR-016 (10.170), NR-017 (7.088 and the 22 slot), NR-018
  (25.70/25.698), NR-026 (the lift chain), NR-027, NR-028 and NR-029
  (13.38/127.772).

- Rows NR-012, NR-013, NR-019 to NR-025 and NR-030 to NR-036 print no
  value in this draft. Their citations, markers and gates carry row IDs
  only.

- The lift chain recomputes: 1.5 x 20.698468 x 9.81 = 304.58 newtons.
  The margin recomputes to 1.20815, quoted 1.21. The rpm recomputes
  127.7721.

- The v0.15 appendix adds no value token. The hashes, commit refs and
  row IDs fall outside the pattern by construction. Its rows cite signed
  rows only (NR-021, NR-022, NR-023, NR-005, NR-006, NR-011 and NR-036).

- Arithmetic on stated totals: the status mix sums to 930
  (508 + 301 + 110 + 11). Three islands of 310 give 930.

- Superseded forms: the draft prints no retired value (63.8695, 20.1056,
  14.4651, 14.46, 0.101631) and no NR-031 quote form (5.566, 0.2944,
  0.1016). A grep reads no hit.

- References counts: the section 7 line reads fifteen of eighteen
  verified, three calls pending (Ranneberg EK_FT_0018, the Jamieson
  deck and the Hancock deck). `references-verification.md` carries the
  same counts.

- Cited commits: the draft quotes five (`dd3cc6a`, `a76c5e9`, `31ca00d`,
  `eacf073` and `74cfef9`). All five resolve in the tip ancestry.

- Moved-unit resolution: every unit the split removed resolves in the
  tracker. The version history sits at tracker section 1, and the seat
  notes sit at section 4 with the two trimmed header fragments.

- The open-requests block joins section 3 at the follow-up. The two
  numbers-gate notes and the three figure markers stay in the report.

- Held tokens: `1.94` and `5.18` stay in the section 4.2 ledger, gated
  by the kept note "The other values need rows first".

- The `3.55` hold closes on the draft side: the token left with its
  bracket and stays flagged non-operating in the tracker. The section 5
  gate carries no numeral.

- Number-token diff, v0.14 (`13973f2`) to the follow-up (`b33451f`), per
  push:

- v0.14 to v0.15: two arrivals, one removal. Both arrivals are the `15`
  version digit (the header bump and the pass note). The removal is the
  `14` header digit the bump retired. The appendix adds no token.

- v0.15 to v0.16 (the split): one arrival, `16`, the header bump.
  Removals read 40 occurrences, none from a reader-facing print.

- The split removals, version-history side: the note digits v0.1 to
  v0.15 and the second v0.11 reference, the item refs 1.2, 1.5, 1.8 and
  3.7, the section refs 2.1, 3.3 three times, 3.4 and 3.5, then 20.698,
  304.58 and the Sweep 7 ref.

- The split removals, figure side: the figure-map row refs 2, 3, 6, 7,
  8, 9, 10, 11 (row 8 from the trimmed section 3.4 header), the
  seat-note numerals 3.55 and 930, and the retired header digit 15.

- The two sets total 40 occurrences. Raw side: 6 added occurrences, 45
  removed.

- v0.16 to the tidy: no token change.

- Tidy to the follow-up: no arrivals. Two removals, `1` and `3`, the
  pair in the open-requests bullet "when Phases 1 to 3 land", as the
  block leaves for the tracker. Raw side: 0 added, 2 removed.

- Net across the span: no value token arrived, dropped or altered. The
  cumulative diff reads one arrival (`16`) and 41 removals. The two `15`
  arrivals of the v0.15 header retire within the span.

- Push-note check, split: the note reads "zero value tokens changed,
  added or moved", with `3.55` named as the only token that left.

- The recount: the reader-facing prints hold, and `3.55` does leave with
  its bracket. The moved-layer instances leave with their blocks. That
  account sits above, pre-accounted in Deltas v1.

- Push-note check, the follow-up: the note reads "zero value tokens
  added, 16 lines removed". The recount holds. The removal set is the
  "1 to 3" pair the note lists, and the diff stat reads 16 deletions.

**Finding**

No value discrepancy found. The split carries no reader-facing number
away. The headline set holds (930, 5.309 and 14.972 still print), and
every moved unit resolves in the tracker.

The readback closes: the open-requests block left the report at the
follow-up, and the section 3.5 fragment sits at tracker section 4. The
split note names the `3.55` move. The sweep reads the full moved set
above.

One carry-note for the author seat: the Document control sentence names
three moved layers. The tracker carries a fourth, the seat notes. The
sentence stands, and a skim may read the list as complete.

**Next run** at the next draft push.

## Sweep 11: v0.16 follow-up 2, 2026-10-12

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`2f83f48` (the document-control fold). The file carries zero diff to
the branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `25ff00e` (zero
diff to the tip, no change since Sweep 9).

**Results**

- STE gate: words 3233, total 4, `per100w=0.12`, `em_dash=0`, exit 0.
  The fold adds three words. Every hook reading holds.

- Retired phrasing: no hit. The change sits in Document control only.

- Value cross-check: the change touches no printed value. The token diff
  below carries the proof.

- Number-token diff against the v0.16 follow-up (`b33451f`): no
  arrivals, no removals. The diff carries one hunk.

- The change: Document control now names all four moved layers. The
  seat notes join the version history, the working notes and the open
  requests.

- Push-note check: the note reads three added words and zero tokens.
  The recount holds (words 3230 to 3233).

- Held tokens: no change. `1.94` and `5.18` stay under the section 4.2
  note, and `3.55` stays in the tracker.

**Finding**

No value discrepancy found. The Sweep 10 carry-note closes: the
Document control list reads exhaustive.

**Next run** at the next draft push.

## Sweep 12: v0.17, 2026-10-12

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`398d4b9` (the F6 correction). The file carries zero diff to the branch
tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `0193c58` (zero
diff to the tip).
Moved since Sweep 11: `1a95ae0` (an NR-011 and NR-017 re-read),
`83ee92f` (NR-037, NR-038 and the Figure 6 label rule), and the
counter-read `0193c58`.
No signed row changed.

**Results**

- Span note: one draft push since Sweep 11 (v0.17). The pass removes
  the §3.3 lift-ratio sentence. The token diff below closes the span.

- STE gate: words 3205, total 4, `per100w=0.12`, `em_dash=0`, exit 0.
  The pass removes 28 words (3233 at the follow-up 2). The hook lines
  read `passive_voice x1` and `long_paragraph x3`, both pre-existing.

- Offender check against the `2f83f48` revision: the probe outputs
  differ in the header line only. The edit adds no offender line and no
  count.

- Retired phrasing: no new hit. The section 1 contrast line "without a
  rigid driveshaft" stays the only near-hit, cleared in Sweep 3 and
  unchanged.

- Held name: the §3.3 "cyan line" site is the held Pick B form of the
  held-term map. This pass leaves it in place.

- Value cross-check: the pass removes two value tokens and adds none.
  The removal set maps to the F6 correction alone. Every other printed
  value carries forward from the Sweep 10 set, because the pass touches
  no other line.

- The draft no longer prints `1.21` or `25.70`. The fine form `25.698`
  still prints at §3.3 with its NR-018 citation.

- The §3.3 chain holds: 1.5 x 20.698468 x 9.81 = 304.58 newtons, and
  the tension 324.1 newtons (NR-010).

- The ratio 1.21 now lives in the Figure 6 build, beside its
  definition, under the NR-037 label rule.

- The register re-read `1a95ae0` covers the draft prints of NR-011 and
  NR-017, and it found no drift. This pass leaves those prints.

- Arithmetic on stated totals: no change from Sweep 10. The status mix
  still reads 930 as 508 plus 301 plus 110 plus 11.

- Cited commits: the draft quotes five hashes (`dd3cc6a`, `a76c5e9`,
  `31ca00d`, `eacf073` and `74cfef9`). All five resolve in the tip
  ancestry.

- Superseded forms: no hit on the retired value set (63.8695, 20.1056,
  14.4651, 14.46 and 0.101631), and no NR-031 quote form. A grep reads
  no hit.

- Number-token diff, v0.16 follow-up 2 (`2f83f48`) to v0.17 (`398d4b9`).
  One arrival, `17`, the header bump. The removals read `16`, the
  retired header digit, plus `1.21` and `25.70` from the removed
  sentence. The raw side reads 1 added occurrence and 3 removed.

- Push-note check: the tracker note names the `1.21` removal and reads
  "no other draft line moves". The recount adds `25.70` from the same
  sentence and the header digit pair. The diff carries two hunks.

- Held tokens: no change. `1.94` and `5.18` stay under the §4.2 note
  "The other values need rows first", and `3.55` stays in the tracker.

**Finding**

No value discrepancy found. The F6 correction lands clean on the draft
side: the ratio no longer prints as a margin, and its home is the
Figure 6 build, beside its definition.

**Next run** at the next draft push.
## Sweep 13: v0.24, 2026-10-12

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`9ab7dd4` (v0.24, the window-term sweep), spanning the seven pushes
from `4330ec5` (v0.18) to `b14f87b` (v0.23). The file carries zero
diff to the branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `c1b6bec` (zero
diff to the tip).
Moved since Sweep 12: `819b09f` (NR-039), `166e48e` (NR-040 margins),
`da1888f` (its counter-read), `025906b` (the NR-041 values), `7b3fc8c`
(its counter-read) and `c1b6bec` (the NR-013 extension).
No signed row changed (283 added lines, none removed).

**Results**

- Span note: this pass covers the seven pushes since Sweep 12, v0.18 to
  v0.24. The token diff below closes the full span, per push.

- STE gate: words 3909, total 6, `per100w=0.15`, `em_dash=0`, exit 0.
  The hook lines read `passive_voice x1` and `long_paragraph x5`.

- The span readings (words/total): v0.17 3205/4, v0.18 3447/4,
  v0.19 3651/4, v0.20 3675/5, v0.21 3695/6, v0.22 3717/6,
  v0.23 3909/6, tip 3909/6.

- Offender delta, `398d4b9` to tip: the v0.18 pass splits three prose
  blocks out of the set. Its three summary tables enter as structural
  flags, the accepted class.

- The v0.20 FoS line brings the section 3.3 winner paragraph into the
  set. The v0.21 reconciliation sentence brings the section 3.2
  convergence paragraph in. Net total 4 to 6, and no other category
  moves.

- Retired phrasing: no new hit. The section 1 contrast line "without a
  rigid driveshaft" stays the only near-hit, cleared in Sweep 3.

- Value cross-check: every arrived value matches its row at the quoted
  precision. The span arrivals, by push:

- v0.18, the summary tables read NR-001 (930, 310, three islands),
  NR-008 (5.309/5.314), NR-009 (14.972), NR-010 (324.1), NR-011
  (4.580/0.804/the three lines/six rings/one active rotor), NR-014
  (0.029), NR-015 (2.24/10/40/2.5/18.8), NR-016 (10.170), NR-017
  (7.088), NR-018 (25.698), NR-026 (the 70 line), NR-027 with NR-039
  (5.0), NR-028 (18.8), NR-029 (13.38) and NR-030 (396.76).

- v0.19: NR-040, twice, at the abstract and the conclusion.

- v0.20: NR-021 (15.033 at the final step). The FoS pair reword nets
  one `2.5` occurrence out, and the pair still reads NR-015.

- v0.21: NR-018 plus NR-039 against NR-005. 25.698 plus 1.665 reads
  27.3635, the NR-005 value at 27.364.

- v0.22: the lone arrival is the figure-map row numeral 2, in the seat
  marker. It is a marker ref, not a value.

- v0.23: 10, 40 and 18.8 each gain one occurrence, all on their
  existing rows.

- v0.24: term swaps only. No token change beyond the header pair.

- The new register blocks print only where the draft cites them. NR-039
  prints through the 1.665 quote and NR-040 through 2.03. NR-041 and
  the NR-013 extension sit in the figure kits.

- Arithmetic on stated totals: the status mix sums to 930
  (508 + 301 + 110 + 11). Three islands of 310 give 930.

- Superseded forms: no hit on the retired value set (63.8695, 20.1056,
  14.4651, 14.46, 0.101631) and no NR-031 quote form. A grep reads no
  hit.

- Cited commits: the draft quotes six, `dd3cc6a`, `a76c5e9`, `31ca00d`,
  `eacf073`, `74cfef9` and `df8a2b4`. All six resolve in the tip
  ancestry.

- Number-token diff, v0.17 (`398d4b9`) to v0.24 (`9ab7dd4`), per push.
  Raw occurrences: added 71, removed 33. The raw side carries the wrap
  churn, and the identity checks pass per token.

- v0.17 to v0.18: twenty-four value arrivals, the summary-table set
  above. One header arrival, `18`. One removal, the `17` header digit.

- v0.18 to v0.19: the `19` header digit and the `2.03` pair. One
  removal, the `18` header digit.

- v0.19 to v0.20: one arrival, `15.033`. One net removal, `2.5`. The
  title block stayed at v0.19, and the v0.21 pass caught it up.

- v0.20 to v0.21: `1.665`, `25.698` and the `21` header digit. One
  removal, the `19` header digit.

- v0.21 to v0.22: the `22` header digit and the seat-marker row
  numeral `2`. One removal, the `21` header digit.

- v0.22 to v0.23: one occurrence each of `10`, `40` and `18.8`, plus
  the `23` header arrival and the `22` header removal.

- v0.23 to v0.24: the `24` header arrival and the `23` header removal.

- Net across the span: no value left the draft and no value changed.
  Every arrival maps to a signed row, a marker ref or a header digit.

- Push-note check: the v0.23 note reads three tokens gaining one
  occurrence each. The recount holds for `10`, `40` and `18.8`. The
  v0.24 note reads the version token only, and the recount holds.

- Held tokens: no change. `1.94` and `5.18` stay under the section 4.2
  note "The other values need rows first", and `3.55` stays in the
  tracker. The section 5 Daisy gate stands.

**Finding**

No value discrepancy found.
The v0.18 tables land fully cited, and the term sweep of v0.23 and
v0.24 moves no token. The span adds two prose long_paragraph flags,
and three structural table flags from the accepted class.
The draft passes the gate at every push.

**Next run** at the next draft push.

## Sweep 14: v0.26, 2026-10-13

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`d91b93b` (v0.26, the score-term fold), spanning the two pushes
`99d09a1` (v0.25, the section 3.3 order pass) and `d91b93b`.
The file carries zero diff to the branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `43fb0bc` (zero
diff to the tip).
Moved since Sweep 13: `4616641` (the aero counter-read of NR-013) and
`43fb0bc` (the display-form note: kg-equivalent for objective values,
NR-003 to NR-006, NR-036 and NR-039, and kg for the physical mass).
No signed row changed (73 added lines, none removed).

**Results**

- Span note: this pass closes the two pushes since Sweep 13, v0.25 and
  v0.26.
  The token diff below runs per push.

- STE gate: words 3949, total 5, `per100w=0.13`, `em_dash=0`, exit 0.
  The hook lines read `passive_voice x1` and `long_paragraph x4`.

- The span readings (words/total): v0.24 3909/6, v0.25 3909/6,
  v0.26 3949/5, tip 3949/5.

- Offender delta, `9ab7dd4` to tip: the v0.25 pass moves no offender
  line, entry for entry.

- The v0.26 rewrite clears one long_paragraph entry, the section 3.2
  island block.

- The three summary tables keep their accepted structural flags. The
  section 3.3 lead block keeps its flag. Net total 6 to 5, and no
  category gains.

- Retired phrasing: no hit. The section 1 contrast line "without a
  rigid driveshaft" stays the only near-hit, cleared in Sweep 3.

- Value cross-check: the span adds no value. The order pass moves
  blocks and no token.

- The v0.26 pass changes the unit words and adds the section 2.4
  definition.
  Every numeral on a moved or changed line reads the same on both
  sides (36.109, 30.578, 30.637, 27.364, 25.698, 1.665 and the
  generation counters).

- The score term lands at the planned sites against the display-form
  note (`43fb0bc`). The physical-mass prints keep "kg" (25.698 kg at
  NR-018).

- Arithmetic on stated totals: the status mix still sums to 930
  (508 + 301 + 110 + 11). Three islands of 310 give 930.

- Superseded forms: no hit on the retired value set (63.8695, 20.1056,
  14.4651, 14.46 and 0.101631) and no NR-031 quote form. A grep reads
  no hit.

- Cited commits: the draft names six (`dd3cc6a`, `a76c5e9`, `31ca00d`,
  `eacf073`, `74cfef9` and `df8a2b4`). All six resolve in the tip
  ancestry.

- Number-token diff, v0.24 (`9ab7dd4`) to v0.26 (`d91b93b`), per push.
  The raw side reads 24 added occurrences and 24 removed. The identity
  checks pass per token.

- v0.24 to v0.25: one arrival, `25`, against one removal, `24`. The
  pair rides the version pin. An order-only check finds the version
  line as the only difference across the two revisions.

- v0.25 to v0.26: one arrival, `26`, against one removal, `25`. The
  `25` leaves with the version pin.

- The `26` rides the version pin and one rewritten block line, the
  generation 26 counter. Its raw side reads two added occurrences and
  one removed.

- Net across the span: no value token arrived, dropped or altered.
  Every arrival maps to the version pin or to a block line that keeps
  its counter.

- Push-note check, v0.25: the note reads a version pin move and no
  value token move. The recount holds.

- Push-note check, v0.26: the note reads a version pin move and no
  numeral move. The recount holds. The tracker readings also reproduce
  (1575, 1621 and 1663 words, 10 total each, context only).

- Held tokens: no change. `1.94` and `5.18` stay under the section 4.2
  note "The other values need rows first", and `3.55` stays in the
  tracker. The section 5 Daisy gate stands.

**Finding**

No value discrepancy found.
The order pass moves text and no token.
The score-term fold lands its unit words with every numeral in place,
and the display note grounds the term.
The section 3.2 block repair clears one long_paragraph flag.
The draft passes the gate at both pushes.

**Next run** at the next draft push.
