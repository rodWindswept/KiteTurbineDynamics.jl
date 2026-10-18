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

## Sweep 15: v0.27, 2026-10-13

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`546fc1f` (v0.27, the founder docx-return fold), spanning one push from
`d91b93b` (v0.26). The file carries zero diff to the branch tip at sweep
time.

**Register** `docs/reporting/numbers-register.md` at `8fb529e` (zero
diff to the tip).
Moved since Sweep 14: `8c278a5` (NR-042 signed, the SV5 margin block)
and `8fb529e` (the FoS 1 dp display note at NR-009).
No signed row changed (66 added lines, none removed).

**Results**

- Span note: this pass closes the one push since Sweep 14, v0.27, the
  founder docx-return fold, abstract to section 2.2.
  The queue file also moved in the span (`699a2d6`, `04d2179`). It sits
  outside this gate.

- STE gate: words 4222, total 5, `per100w=0.12`, `em_dash=0`, exit 0.
  The hook lines read `passive_voice x1` and `long_paragraph x4`.

- The span readings (words/total): v0.26 3949/5, v0.27 4222/5, tip 4222/5.

- Offender delta, `d91b93b` to tip: no offender line moves, entry for
  entry. The fold adds 273 words and no category count.

- Retired phrasing: no hit. The section 1 contrast line stays the only
  near-hit, reworded by the fold to the negation form "It is not a
  rigid driveshaft". Sweep 3 cleared this line class.

- Term check, bank derate, against the queue v12 (`04d2179`): the
  abstract reads: "a calculated depowering of the ring output,
  because banked blades sweep less streamtube frontal area". The row
  carries the same mechanism and form.

- Term check, the segment torque margin gloss. The gloss reads capacity
  over the segment torque it carries, and the least value governs. The
  row reads the same ratio and rule, with the same-state pairing added.

- Term check, the S1 label. The gloss reads the register form: "the
  first of the five segments between the rings". The label carries no
  queue row.

- Value cross-check, every span arrival accounts to a row, a marker ref
  or a header digit.

- `11.01` and `9.41`: the wind basis. The pair matches the register
  trace-row phrase "One trace, one machine, one wind: 11.01 m/s at
  9.41 m", the NR-029 to NR-034 block, and the NR-032 `v_ref` cell.
  The sentence cites NR-008 and NR-032.

- `15.0`: the FoS 1 dp display form. The display note at `8fb529e`
  signs it, and NR-009 keeps 14.972 at the row form.

- `27`: the version pin. `19`: the systems block diagram marker,
  "figure-map row 19". A marker ref, not a value.

- The retitle: `2.2` net +2, plus the numerals `1` and `2`. The
  heading "### 2.2 The genome" leaves. Three headings arrive: the
  pipeline title, `2.2.1` and `2.2.2`.

- Removals: `26` (the version pin), `2.3` (the old evaluator heading)
  and `14.972` (the abstract form). Section 3.3 and section 5 keep
  14.972, and four prints live at the tip.

- Raw side: 14 added token occurrences against 8 removed. The net
  reads 9 arrivals and 3 removals. The identity check holds on the
  `2.2` pair, net +2 against raw 3 and raw 1.

- The line multiset reads +only 99 lines, -only 52 lines. The joins
  are the fold rewrites and the retitles. The splits are the returned
  forms they replace.

- Arithmetic on stated totals: the status mix still sums to 930
  (508 + 301 + 110 + 11). Three islands of 310 give 930.

- Superseded forms: no hit on the retired value set (63.8695, 20.1056,
  14.4651, 14.46 and 0.101631) and no NR-031 quote form. A grep reads
  no hit.

- Cited commits: the draft names six (`dd3cc6a`, `a76c5e9`, `31ca00d`,
  `eacf073`, `74cfef9` and `df8a2b4`). All six resolve in the tip
  ancestry.

- Held tokens: no change. `1.94` and `5.18` stay under the section 4.2
  note "The other values need rows first", and `3.55` stays in the
  tracker. The section 5 Daisy gate stands.

- Tracker check: the readings reproduce (1663 to 1785 words, 10 total
  each, context only). The tracker takes the v0.27 entry, the row-19
  request and the two open asks, 16 added lines.

- Push-note check: the author receipt declares add 11.01, 9.41, 15.0,
  27, 19, 2.2 x2, 1, 2 and remove 26, 14.972, 2.3. The recount holds,
  token for token.

- Cascade note: the retitle holds sections 2.4 to 2.6 as returned, so
  the 2.3 slot stands open until the cascade call.

**Finding**

No value discrepancy found.
Every arrival accounts to a row, a marker ref or a header digit.
The fold takes the returned forms and keeps every value.
The two glosses pair with the queue v12 rows.
The offender delta reads zero, and no category count moves.
The draft passes the gate at the push.

**Next run** at the next draft push.

## Sweep 16: v0.28, 2026-10-13

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`5d19bde` (v0.28, the AeroDyn pre-cone gloss fold), spanning one push
from `546fc1f` (v0.27). The file carries zero diff to the branch tip at
sweep time.

**Register** `docs/reporting/numbers-register.md` at `88277f6` (zero
diff to the tip).
Moved since Sweep 15: `88277f6` (NR-043 signed, the winner blade span).
No signed row changed (52 added lines, none removed).

**Results**

- Span note: this pass closes the one push since Sweep 15, v0.28, the
  pre-cone gloss fold at section 2.1.
  The queue file holds across the span.

- STE gate: words 4229, total 5, `per100w=0.12`, `em_dash=0`, exit 0.
  The v0.27 baseline reads 4222. The hook lines hold at
  `passive_voice x1` and `long_paragraph x4`.

- Offender delta, `546fc1f` to tip: no offender line moves, entry for
  entry. The fold adds 7 words and no category count.

- Retired phrasing: no hit. The section 1 contrast line stays the only
  near-hit, in the negation form "It is not a rigid driveshaft".

- Term check, the pre-cone gloss, against the aero read (`2db50f9`):
  the sentence reads "The equivalent term in AeroDyn is pre-cone", the
  installed form. The bank definition above it stands unchanged.

- Value cross-check: one value token moves in the span. The `28`
  arrives at the header line, and the `27` leaves it. Both classify as
  the version pin.

- The diff reads two hunks: the version line, and the section 2.1
  split, where the bank sentence takes the gloss and the blade-scale
  block splits at the sentence boundary.

- Raw side: one added token occurrence against one removed. The net
  reads one arrival and one removal.

- Push-note check: the author receipt declares add 28 and remove 27.
  The recount holds token for token.

- Cited commits: the draft names six (`dd3cc6a`, `a76c5e9`, `31ca00d`,
  `eacf073`, `74cfef9` and `df8a2b4`). All six resolve in the tip
  ancestry. The era label carries `95c385d`, which resolves too.

- Arithmetic on stated totals: the status mix still sums to 930
  (508 + 301 + 110 + 11), and three islands of 310 give 930.

- Superseded forms: no hit on the retired value set (63.8695, 20.1056,
  14.4651, 14.46 and 0.101631) and no NR-031 quote form.

- Held tokens: no change. `1.94` and `5.18` stay under the section 4.2
  note "The other values need rows first", and `3.55` stays in the
  tracker. The section 5 Daisy gate stands.

- Tracker check: the readings reproduce (1785 to 1824 words, 10 total
  each, context only). The tracker takes the v0.28 entry and the
  note-10 closure, 7 added lines and 2 removed.

- Cascade note: the retitle still holds sections 2.4 to 2.6 as
  returned, so the 2.3 slot stands open until the cascade call.

**Finding**

No value discrepancy found.
The gloss moves the version pin and splits one block.
No value token arrives or leaves.
The register moved append-only, and no signed row changed.
The offender delta reads zero, and no category count moves.
The draft passes the gate at the push.

**Next run** at the next draft push.

## Sweep 17: v0.29, 2026-10-13

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`eb0e08d` (v0.29, the AU1 front-summary block), spanning two movers
from `5d19bde` (v0.28): the figure v4 appendix pass (`a66b8d2`) and
the AU1 push (`eb0e08d`). The file carries zero diff to the branch tip
at sweep time.

**Register** `docs/reporting/numbers-register.md` at `88277f6` (zero
diff to the tip). No movement since Sweep 16.

**Results**

- Span note: this pass closes the two draft movers since Sweep 16.
  The figure push moves provenance text alone, and the AU1 push lands
  the front summary block. The token diff breaks out per mover.

- Queue note: the queue moved in the span at `724b226` (the v13
  era-map routing, this seat). It sits outside this gate.

- STE gate: words 4441, total 5, `per100w=0.11`, `em_dash=0`, exit 0.
  The readings: v0.28 4229, the figure pass 4231, v0.29 4441. The
  hook lines hold at `passive_voice x1` and `long_paragraph x4`.

- Offender delta, `5d19bde` to tip: no offender line moves, entry for
  entry, across both movers. The span adds 212 words and no category
  count.

- Retired phrasing: no hit. The section 1 contrast line stays the only
  near-hit, in the negation form "It is not a rigid driveshaft".

- Term check, the FoS forms. The AU1 block prints `14.972`, the row
  form (NR-009). The abstract keeps the signed 1 dp form `15.0`. Both
  read the display note (`8fb529e`).

- Value cross-check, the figure mover: no value token moves. The lone
  raw pair reads "row 2" in the seat marker, unchanged on both sides.
  The exhibit row and the appendix hash block take the v4 pins, and
  the old plate pin `df8a2b4` leaves the draft for `9cecee3`.

- Value cross-check, the AU1 mover: every arrival accounts to a
  signed row. `29` is the version pin. `930` twice (NR-001), `508`
  and `422` summing to 930 (NR-002), and `5` twice, the class label.

- The other arrivals: `5.309` (NR-008), `25.698` (NR-018), `14.972`
  (NR-009), `2.03` (NR-040), `36.109` (NR-006), `27.364` (NR-005)
  and `3`, the island label. The only removal is `28`, the pin.

- Raw side, the AU1 mover: 14 added token occurrences against one
  removed. The net reads 13 arrivals and one removal. The identity
  check holds for every token.

- Push-note check: the author receipt declares add 29, 930 twice, 5
  twice, 508, 422, 5.309, 25.698, 14.972, 2.03, 36.109, 27.364, 3 and
  remove 28. The recount holds, token for token.

- Version/tracker check: the tracker takes the v0.29 entry (`29`
  added, nothing removed). The readings reproduce (1824 to 1869
  words, 10 total each, context only).

- Cited commits: the draft names six (`dd3cc6a`, `a76c5e9`, `31ca00d`,
  `eacf073`, `74cfef9` and `9cecee3`, the new plate commit). All six
  resolve in the tip ancestry. The era label carries `95c385d`, which
  resolves too.

- Arithmetic on stated totals: `508` plus `422` gives 930, against
  NR-001. Three islands of 310 give 930.

- Superseded forms: no hit on the retired value set (63.8695, 20.1056,
  14.4651, 14.46 and 0.101631) and no NR-031 quote form.

- Held tokens: no change. `1.94` and `5.18` stay under the section 4.2
  note "The other values need rows first", and `3.55` stays in the
  tracker. The section 5 Daisy gate stands.

- Cascade note: the retitle still holds sections 2.4 to 2.6 as
  returned, so the 2.3 slot stands open until the cascade call. The
  AU1 placement stands open to the room bounce, and a move would be
  order-only.

**Finding**

No value discrepancy found.
The span closes the figure appendix pass and the AU1 block.
Every arrival accounts to a signed row, and no value token is lost.
The register holds still, and the offender delta reads zero.
The draft passes the gate at the push.

**Next run** at the next draft push.

## Sweep 18: v0.29, 2026-10-13

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`eb0e08d` (v0.29, carried over from Sweep 17). The span holds no
draft mover, and the file carries zero diff to the branch tip at
sweep time.

**Register** `docs/reporting/numbers-register.md` at `88277f6` (zero
diff to the tip). No movement since Sweep 16.

**Results**

- Span note: this pass covers one mover, the tracker edit at
  `2ebbd22` (the founder-calls record). The push carries the tracker,
  the receipt and the evidence alone. The draft and the register hold
  at their Sweep 17 revisions, and the queue file holds too.

- STE gate, draft: words 4441, total 5, `per100w=0.11`, `em_dash=0`.
  The readings stand from Sweep 17. The hook lines hold at
  `passive_voice x1` and `long_paragraph x4`.

- STE gate, tracker: words 1954, total 10, `per100w=0.51`.
  The base at `f5e8e7d` reads 1869 words, total 10, `per100w=0.54`.
  No category gains sit on either side.
  Both carry `long_sentence x1`, `semicolon x1`, `contraction x1`,
  `passive_voice x2` and `long_paragraph x5`.

- Token diff, tracker: arrivals `2.2`, `2.4`, `2.6` and `1`.
  The removals set is empty. The raw side reads five added
  occurrences against one removed.
  The cascade rewrite keeps `2.2` on both sides of the edit.

- Push-note check: the author receipt declares add `2.2`, `2.4`,
  `2.6` and `1`, nothing removed. The recount holds, token for
  token.

- Offender delta, tracker: no offender line moves, entry for entry,
  base to tip. Only the header line changes, with the word count.

- Tracked rulings: the founder calls land as ruled text.
  The 2.2 retitle holds, and any renumber rides the structure pass.
  The machine and pipeline distinction rides the structure pass.

- Display forms: the factor of safety prints at 1 dp in the report.
  Span and measurement values print no finer than the nearest
  millimetre. Full precision stays internal.
  The abstract keeps `15.0` under NR-009 and the display note
  `8fb529e`.

- Display item: the new rules gate one draft site. Section 3.3 prints
  `20.698468` in the vertical-load line, beyond the nearest
  millimetre rule. One display ruling remains, and it sits with
  @science-validator.

- Value cross-check: the tracker additions carry no value token.
  The lone added digit `1` reads "1 dp", the display-form label.
  No signed value moves.

- Cited commits: `2db50f9` and `8fb529e` resolve in the tip
  ancestry. `eb0e08d`, the review copy draft pin, resolves too.

- Held tokens: no change. `1.94` and `5.18` stay under the section
  4.2 note. `3.55` stays flagged in the tracker. The section 5
  Daisy gate stands.

- Cascade note: the renumber item closes as ruled. Sections 2.4 to
  2.6 keep their numbers, and the 2.3 slot stands open until the
  structure pass. The AU1 placement bounce stays open from Sweep 17,
  author seat.

**Finding**

No value discrepancy found.
The span is tracker-only, and the founder calls land as ruled text.
Four label arrivals account, with no value arrival and no removal.
The draft and the register hold, and the offender delta reads zero.
The draft passes the gate at the push.

**Next run** at the next draft push.

## Sweep 19: v0.30, 2026-10-13

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`a90122b` (v0.30, the display folds), one draft mover from `eb0e08d`
(v0.29). The file carries zero diff to the branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `d7f8871`,
zero diff to the tip.
Moved since Sweep 18: `d7f8871`, the two display-form notes.
Append-only: 57 added lines, none removed.
No signed row changed.

**Results**

- Span note: the span `0415d18..a90122b` carries three non-draft
  landings outside this gate: `d7f8871` (the display rulings, its
  register block reads above), and the PCA kit pushes `3d36c7a` and
  `e501c03`. One draft mover: `a90122b`.

- Queue note: the queue file holds. No movement since `724b226`.

- STE gate, draft: words 4441, total 5, `per100w=0.11`, `em_dash=0`.
  The v0.29 base reads the same. The hook lines hold at
  `passive_voice x1` and `long_paragraph x4`.

- STE gate, tracker: words 1954 to 2019, total 10 to 10,
  `per100w=0.51` to `0.50`. No category gains on either side.
  Both carry `long_sentence x1`, `semicolon x1`, `contraction x1`,
  `passive_voice x2` and `long_paragraph x5`.

- Offender delta: no offender line moves, entry for entry, on the
  draft and on the tracker. Only the header lines change.

- Token diff, draft: arrivals `15.0` five times, `20.698`, `304.6`
  and `30`, the version pin. Removals: `14.972` five times,
  `20.698468`, `304.58` and `29`, the pin.
  The raw side reads 12 added occurrences against 12 removed.

- Push-note check: the author receipt declares the same set.
  The recount holds, token for token.

- Token diff, tracker: arrivals `30` twice, `15.0`, `20.698` and
  `304.6`, and the removals set is empty.
  The raw side reads six added occurrences against one.
  The `1` of the display bullet pairs out across the edit.

- Value cross-check, the FoS sites: every arrival accounts to the
  display note (`d7f8871`, NR-009 basis): the front summary, the
  window-minimum sentence, the operating table, the gate table and
  section 5. The abstract held its form.

- Value cross-check, the chain: `20.698` and `304.6` read the
  lift-chain note. The `15.033` hub ring boundary keeps its form,
  and `14.972` no longer prints. NR-009 keeps the row.

- Arithmetic: the chain holds as displayed. The rounded operands
  give 304.571, and 1.5 × 20.698 × 9.81 prints 304.6 at 1 dp.
  The full value reads `304.5779603905257`, matching the
  register note.

- The Sweep 18 display item closes: the section 3.3 site takes
  the report form, and the fold reaches all five report sites.

- Retired phrasing: no hit on the banned forms.
  The standing near-hit holds: the section 1 negation, "It is not
  a rigid driveshaft". The lift-chain terms read in their split
  sense, "bridles" and "cyan line", never the conflated form.

- Superseded forms: no hit on the retired value set and no
  NR-031 quote form.

- Held tokens: no change. `1.94` and `5.18` stay under the
  section 4.2 note. `3.55` stays flagged in the tracker.
  The section 5 Daisy gate stands.

- Cited commits: the draft names six (`dd3cc6a`, `a76c5e9`,
  `31ca00d`, `eacf073`, `74cfef9` and `9cecee3`). All resolve in
  the tip ancestry, with the era label `95c385d`.

- Cascade note: the renumber item stays ruled.
  The AU1 placement bounce stays open from Sweep 17, author seat.

**Finding**

No value discrepancy found.
The span folds the two display rulings, and every token accounts.
Five FoS sites take their ruled form, and the chain takes its operands.
The register holds, and the offender delta reads zero.
The draft passes the gate at the push.

**Next run** at the next draft push.

## Sweep 20: v0.31, 2026-10-14

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`76655cb` (v0.31, the AU3 wording set), one draft mover from `a90122b`
(v0.30). The file carries zero diff to the branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `6255268`, zero diff to the tip.

Moved since Sweep 19: `2ad023c` (the NR-044 sign, the δcrit close-out)
and `6255268` (the NR-045 sign on the island generation counts).
Append-only: 62 added lines, none removed.
No signed row changed.

**Results**

- Span note: the span `4ce4b91..ec56301` carries one draft mover,
  `76655cb`, and non-draft landings outside this gate:
  `08e1d95` (the NR-044 kit fold), `ecdf369` (the author plan), the
  feedback-3 routing pair `04de685` and `c434fa4`, the F-VALUE
  counter-read `331f60d`, the levers recut chain `e23f226`, `3afdf3c`
  and `d6d4db9`, and the AU2 supplies `ec56301`.

- Queue note: the queue file holds. No movement since `724b226`.

- STE gate, draft: words 4441 to 4538, total 5 to 5,
  `per100w=0.11` to `0.11`, `em_dash=0`.
  The hook lines hold at `passive_voice x1` and `long_paragraph x4`.

- STE gate, tracker: words 2019 to 2094, total 10 to 10,
  `per100w=0.50` to `0.48`. No category gains on either side.
  Both carry `long_sentence x1`, `semicolon x1`, `contraction x1`,
  `passive_voice x2` and `long_paragraph x5`.

- Offender delta: no offender line moves, entry for entry, on the
  draft and on the tracker. Only the header lines change.

- Token diff, draft: arrivals `1`, `2` and `31`, the version pin.
  Removals: `30`, the pin.
  The raw side reads 8 added occurrences against 6 removed.
  The five raw pairs that net out ride the rewritten sentences:
  `0.82`, `0.20`, `6`, `7.088` and `22` keep on both sides of the edit.

- Push-note check: the author receipt declares the pin and the two
  slot numerals as the only delta. The recount holds, token for token.

- Value cross-check, the AU3 set: the slot numerals `1` and `2` arrive
  in the blade-scale sentences, and `7.088` and `22` stay in the bank
  sentences at their row forms. The polygon, era, seed and wind
  rewrites carry no value token.

- Retired phrasing: no hit on the banned forms.
  The standing near-hit holds: the section 1 negation, "It is not a
  rigid driveshaft". The lift-chain terms read in their split sense.

- Held tokens: no change. `1.94` and `5.18` stay under the
  section 4.2 note. `3.55` stays flagged in the tracker.
  The section 5 Daisy gate stands.

- Cited commits: the draft names six (`dd3cc6a`, `a76c5e9`,
  `31ca00d`, `eacf073`, `74cfef9` and `9cecee3`). All resolve in the
  tip ancestry, with the era label `95c385d`.

- Cascade note: the renumber item stays ruled.
  The AU1 placement bounce stays open from Sweep 17, author seat.

**Finding**

No value discrepancy found.
The span folds the AU3 wording set, and every token accounts.
The register signs two rows, both append-only, and the offender
delta reads zero.
The draft passes the gate at the push.

**Next run** at the next draft push.

## Sweep 21: v0.33, 2026-10-14

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`dcf8213` (v0.33, the polish pair one), spanning two movers from
`76655cb` (v0.31): `5a7a6b4` (v0.32, the levers fold and the matrix)
and `dcf8213` (v0.33). The file carries zero diff to the branch tip
at sweep time.

**Register** `docs/reporting/numbers-register.md` at `6255268`, zero
diff to the tip. No movement since Sweep 20.

**Results**

- Span note: this pass closes the two draft movers since Sweep 20.
  The span `ec56301..f6e7f4e` carries non-draft landings outside this
  gate: the F-VALUE re-census (`7329191`), the claim-evidence audit
  (`2074a5d`), the caption leads (`60ee728`), the handover pages
  (`bc2c529`, `21b821b`, `9c6cb68`, `f6e7f4e`) and the seating-header pair
  (`0ea9da4`, `efc44f3`).

- Queue note: the queue moved in the Sweep 20 tail at `4e559de`
  (glossary candidates v14 and the three projection terms, this seat).
  It sits outside this gate. No movement since.

- STE gate, draft: words 4538 to 5461 across the two movers (4538,
  5124, 5461), total 5 to 5, `per100w=0.11` to `0.09` and `em_dash=0`
  to `2`, the guidance-only pair inside the frozen axis names. The
  hook lines hold at `passive_voice x1` and `long_paragraph x4`.

- STE gate, tracker: words 2094 to 2193, total 10 to 10, `per100w`
  0.48 to 0.46.
  The category set holds at `long_sentence x1`, `semicolon x1`,
  `contraction x1`, `passive_voice x2` and `long_paragraph x5`.
  One guidance-only dash arrives at v0.32 in the claim and evidence
  phrase, not scored.

- Offender delta, draft: one line moves each way at v0.32.
  The section 3.3 winner-intro line clears on its linebreak-only
  split, and the matrix table takes the structural flag.
  The count holds at four long-paragraph flags.
  v0.33 moves nothing, and only the header lines change.

- Offender delta, tracker: no offender line moves, entry for entry.
  Only the header lines change.

- Token diff, draft, mover one (`76655cb` to `5a7a6b4`): 33 arrival
  forms, 39 occurrences, no removal. The pointers, the section
  numerals, the PRD digits and the pin `32` are identifiers.

- Value cross-check, mover one: every arrival accounts to a signed row.
  The block holds NR-044 shares and loadings at the drawn forms, NR-001
  (`930` twice) and the NR-005 and NR-006 pair (`36.109` twice,
  `27.364` twice, `26`).
  The matrix adds NR-002 (`508`, `301`, `110`, `11`) and restates
  `15.0`, `2.03`, `25.698` and `5.309`.

- Raw side, mover one: 44 added occurrences against 5 removed.

- Raw pairs, mover one: the net-out set rides the rewritten lines.
  `1` and `2` leave the retired section 3.4 bracket for the folded
  block, and `31` leaves the version pin for the block generation
  count.
  `15.0` and `3.4` keep on both sides of their edits.

- Push-note check, mover one: the v0.32 receipt declares the same 33
  forms and 39 occurrences, and no removal. The recount holds, token
  for token.

- Token diff, draft, mover two (`5a7a6b4` to `dcf8213`): 26 arrival
  forms, 29 occurrences, one removal (the pin `32`). The generation
  frames and the pin `33` are identifiers.

- Value cross-check, mover two: every arrival accounts to a signed
  row. NR-036 grounds the strip chain, NR-021 the ring readings,
  NR-022 the twist forms, NR-040 the margins, NR-018 and NR-039 the
  decomposition, NR-011 the geometry.

- Raw side, mover two: 31 added occurrences against 3 removed. The
  net-out pairs: `3` leaves the retired section 3.5 bracket and arrives
  in "island 3", and `3.5` leaves the bracketed heading for its plain
  form.

- Push-note check, mover two: the v0.33 receipt declares the same 26
  forms and 29 occurrences, and the pin removal. The recount holds,
  token for token.

- Arithmetic: `508` plus `301` plus `110` plus `11` reads 930
  (NR-002, NR-001).
  The strip step reproduces, 28.315 minus 27.364 reading 0.951 (NR-036).
  The generation frame holds, 31 per island and 930 in all (NR-045).
  `3.816` correctly stays unwritten.

- Carry-note, the section 3.5 decomposition: the printed pair
  25.698 plus 1.665 sums to 27.363, while the winner prints 27.364.
  The full-value sum rounds to 27.364.
  The intended read: the objective splits into the mass and the
  penalties. Held for the room.

- Retired phrasing: no hit on the banned forms. The standing near-hit
  holds: the section 1 negation, "It is not a rigid driveshaft". The
  lift-chain terms read in their split sense.

- Superseded forms: no hit on the retired value set. `3.816` and
  `14.972` stay unwritten.

- Head status note: the v0.13 draft-status line still reads "Sections
  3.4 to 3.6 await the Phase 1 to 3 interpretation." Sections 3.4 and
  3.5 have since landed their text. Flagged for the next pass of the
  author seat.

- Held tokens: no change. `1.94` and `5.18` stay under the section
  4.2 note. `3.55` stays flagged in the tracker. The section 5 Daisy
  gate stands.

- Cited commits: the draft names six (`dd3cc6a`, `a76c5e9`, `31ca00d`,
  `eacf073`, `74cfef9`, `9cecee3`), and the era label `95c385d`. All
  seven resolve in the tip ancestry.

- Freeze re-check: the levers block re-reads byte-identical in the
  draft at `dcf8213`. The draft region, the receipt region and the
  block file carry the same bytes. Block md5
  `7bbd964db09d2b33269ce5cb8c334054`.

- Cascade note: the renumber stays ruled. The AU1 placement closes as
  landed, with no flip in four sweeps. Pair two, sections 3.6 and 5,
  is the next mover.

**Finding**

No value discrepancy found.
The span folds the levers reading, the matrix and the polish pair one.
Every token accounts, and both pushes match their declared sets.
The register holds and the frozen block re-checks.
The offender delta reads one swap with the count held.
The draft passes the gate at the push.

**Next run** at the next draft push.

## Sweep 22: v0.36, 2026-10-14

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`57c77cf` (v0.36, the objective block and the rename), spanning three
movers from `dcf8213` (v0.33): `a3c2def` (v0.34, the polish pair two),
`ef36c6c` (v0.35, the appendix re-pin) and `57c77cf` (v0.36). The file
carries zero diff to the branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `4a86e6f`, zero
diff to the tip.
Moved since Sweep 21: the NR-046 sign, the objective seam forms, the
weights, the thresholds and the reject placement.
The move is append-only, 48 added lines and none removed.
No signed row changed.

**Results**

- Span note: this pass closes the three draft movers since Sweep 21.
  The span `f6e7f4e..e0919ff` carries non-draft landings outside this
  gate.

- Span landings: the sweep-21 train (`f153802` to `852d4bd`), the
  housekeeping set (`576cdb1`, `748127a`, `48aafab`, `13df740`), the
  claim audit `90cd692`, the Harris-3.5 deltas (`671ab96`, `e4ff3c1`),
  the round-4 routing and reads (`25eb0eb`, `a3f4ae3`, `7b8c101`) and
  the NR-046 sign `4a86e6f` with the author handover `e0919ff`.

- Queue note: the queue takes candidates v15 at `57c77cf`, the rename
  delta with the kg-equivalent row. It rides mover three. Noted, not
  gated. No other movement.

- STE gate, draft: words 5461 to 5902 across the three movers (5461,
  5721, 5738, 5902), total 5 to 6, `per100w=0.09` to `0.10`, and
  `em_dash=2` throughout, the guidance-only pair inside the frozen
  axis names.
  The hook lines move at v0.35, `long_paragraph x4` to x5, one
  structural table flag, the appendix class.

- STE gate, tracker: words 2193 to 2350, total 10 to 10, `per100w`
  0.46 to 0.43. The category set holds at `long_sentence x1`,
  `semicolon x1`, `contraction x1`, `passive_voice x2` and
  `long_paragraph x5`.

- STE gate, glossary: words 4565 to 4598, total 12 to 12,
  `per100w=0.26`. The category set holds at `contraction x2`,
  `long_paragraph x10` and the guidance-only dash.

- Offender delta, draft: v0.34 and v0.36 move nothing, and only the
  header lines change. v0.35 adds one line, the appendix table header,
  the structural class the other tables carry. The count reads 11 to
  12 lines across the span.

- Offender delta, tracker and glossary: no offender line moves,
  entry for entry. Only the header lines change.

- Token diff, draft, mover one (`dcf8213` to `a3c2def`): 11 arrival
  forms, 12 occurrences, raw 21/11. Removals: `3`, net one (one list
  marker arrives against two Phase numerals), and `33`, the pin.

- Raw pairs, mover one: the net-out set rides the rewritten lines.
  `1` (the head-line Phase retirement against the first list marker),
  `3.4` and `3.6` (the head line and the heading), and `930` (the
  abstract rewrite). The kept pairs: `15.0`, `2.03` and `5.309`.

- Value cross-check, mover one: every arrival accounts to a signed
  row. NR-002 grounds `110`, NR-009 `15.0`, NR-040 `2.03`, NR-008
  `5.309` and NR-018 `25.698` twice. The list markers `2` and `4` to
  `7`, and the pin `34`, are identifiers.

- Push-note check, mover one: the v0.34 receipt declares the same 11
  forms and 12 occurrences, the net-one `3` removal and the pin `33`.
  The recount holds, token for token.

- Token diff, draft, mover two (`a3c2def` to `ef36c6c`): raw 7/1.
  The additions: the appendix path cells carry `1`, `2` and `3`, twice
  each, and the pin `35` arrives. The removal: the pin `34`. No value
  form moves.

- Push-note check, mover two: the figures receipt counts a wider digit
  class, +34 forms against -11.
  It covers the sixteen hash forms, the four commit cells, the paths,
  the register IDs and the pins.
  The numeric-token recount reads the path pairs and the pin pair alone.
  Both sides agree on the boundary, and no signed value form moves.

- Token diff, draft, mover three (`ef36c6c` to `57c77cf`), 11 forms,
  19 occurrences, raw 19/1.
  The formula carries `5.0` three times, `2.5` twice, `2` three times,
  `1.0` twice, `1` twice, `0` twice, `20.0`, `10.0` and `0.20`.
  The prose carries `20`, the swing in per cent.
  The pin `36` arrives, and the pin `35` retires.

- Value cross-check, mover three: every arrival accounts to NR-046.
  The weights `5.0`, `20.0`, `1.0` and `10.0` read at the signed forms,
  as do the ceilings `5.0` and `2.5` and the stationarity threshold
  `0.20`. The draft formula matches the row string term for term.

- Push-note check, mover three: the v0.36 receipt declares the same 11
  forms and 19 occurrences, and the pin `35` removal. The recount
  holds, token for token.

- Arithmetic: the status mix holds at 508 plus 301 plus 110 plus 11
  reading 930 (NR-002, NR-001).
  The pass and fail counts hold at 508 and 422 reading 930 (NR-002).
  The winner decomposition holds at 25.698 plus 1.665 reading 27.364
  (NR-039, NR-005).

- Rename census: the old form reads zero sites across the draft, the
  glossary and the tracker.
  The new form reads at three draft sites and the glossary row, one
  form.
  The old-form sites survive in the verbatim feedback records alone.
  The near-neighbour uses of the word gate keep their form.

- Retired phrasing: no hit on the banned forms. The standing near-hit
  holds, the section 1 negation, "It is not a rigid driveshaft". The
  lift-chain terms read in their split sense.

- Superseded forms: no hit. `3.816`, `14.972` and the message example
  `14.97` all stay unwritten.

- Head status note: the sweep-21 finding closes. The head line now
  reads "Sections 3.4 to 3.6 carry their text." The nomenclature and
  the references stubs keep their pending brackets.

- Carry-note, the section 3.5 decomposition: closed by disposition at
  v0.34. The pair 25.698 plus 1.665 sums to 27.363 against the 27.364
  winner print, and the full-value sum rounds to 27.364 (NR-039).
  The line keeps the register form.

- Held tokens: no change. `1.94` and `5.18` stay under the section 4.2
  note. `3.55` stays flagged in the tracker. The section 5 Daisy gate
  stands.

- Cited commits: the draft names seven (`dd3cc6a`, `a76c5e9`,
  `31ca00d`, `74cfef9`, `9cecee3`, `671ab96`, `e23f226`), plus the era
  label `95c385d`. All resolve in the tip ancestry. The retired plate
  cell `eacf073` left the draft with v0.35.

- Freeze re-check: the levers block re-reads byte-identical in the
  draft at `57c77cf`. The draft region, the receipt region and the
  block file carry the same bytes. The block md5 reads
  `7bbd964db09d2b33269ce5cb8c334054`.

- Pins note: the two Harris-3.5 plate pins recompute on the delivered
  bytes. The ring PNG reads `f49aaaa1` and the twist PNG `00cd857a`,
  both matching the appendix cells. The appendix carries six exhibit
  rows, and its count sentence reads six.

- Cascade note: the renumber stays ruled. The AU1 placement stays
  closed. The consistency sweep on the author seat is the next
  expected mover.

**Finding**

No value discrepancy found.
The span folds the polish pair two, the appendix re-pin and the objective block with the rename.
Every token accounts, and the three pushes match their declared sets.
The register takes one append-only row, and the frozen block re-checks.
The offender delta reads one structural line at v0.35.
The draft passes the gate at the push.

**Next run** at the next draft push.

## Sweep 23: v0.37, 2026-10-14

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`7dd91a9` (v0.37, the consistency sweep), spanning one mover from
`a3ca2f6` (the Sweep 22 tip). The file carries zero diff to the branch
tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `9d96a4b`, zero
diff to the tip.
Moved since Sweep 22: the NR-046 counter-read block, the thirty-site
re-read and the reject census.
The move is append-only, 40 added lines and none removed.
No signed row changed.

**Results**

- Span note: this pass closes the one draft mover since Sweep 22.
  The span `a3ca2f6..68092dc` carries non-draft landings outside this gate.

- Span landings: the k-story pair (`3b8e099`, `4203bec`), the aero
  gates (`c30b2ca`, `9d96a4b`), the term gate `cadf83d`, the figures
  closure `9ae8097`, the v0.37 mover `7dd91a9`, the handover refreshes
  (`bb1709d`, `c75b28b`, `3caf8e6`, `cb4a52f`, `68092dc`), the queue
  `e4e108b` and the review-copy last mile `d9d4fc4`.

- Queue note: no candidates or glossary movement in the span.

- Bracket count: the body carries the two number-gate brackets and the
  six seated markers, per part 11.

- STE gate, draft: words 5902 to 5884, total 6 to 6, `per100w=0.10`,
  and `em_dash=2` throughout, the guidance-only pair inside the frozen
  axis names.
  The hook lines hold at `passive_voice x1` and `long_paragraph x5`.

- STE gate, tracker: words 2350 to 2401, total 10 to 10, `per100w`
  0.43 to 0.42. The category set holds at `long_sentence x1`,
  `semicolon x1`, `contraction x1`, `passive_voice x2` and
  `long_paragraph x5`.

- Offender delta, draft and tracker: no offender line moves, entry for
  entry. Only the header lines change.

- Token diff, draft (`a3ca2f6` to `7dd91a9`), 6 arrival forms, 6
  occurrences, raw 31/27. The arrivals: `301`, `110` and `11` on the
  classified line, the pin `37`, and the de-hyphenised `5` and `50`.
  The removals: `19` (the retired request bracket) and `36` (the pin).

- Raw pairs: the net-out set rides the rewritten lines, the unit
  conversions (`0.029`, `10.170`, `11.01`, `13.38`, `127.772`,
  `25.698`, `5.02`, `5.18`, `5.309`, `5.314`, `6.32`, `9.41`), the
  classified-line rewrite (`508`, `422`, `930`) and the island tag `3`.
  No kept pair reads.

- Value cross-check: every arrival accounts. NR-002 grounds `301`,
  `110` and `11`. The pin `37` is the version mark.
  The de-hyphenised `5` and `50` expose digits already on the line.

- Push-note check: the v0.37 receipt declares the same 6 forms and 6
  occurrences, and the removals `19` and `36`. The recount holds,
  token for token.

- Arithmetic: the classified counts hold at 301 plus 110 plus 11
  reading 422, and 508 plus 422 reading 930 (NR-002, NR-001).

- Rename census: the old form reads zero sites across the draft, the
  candidates and the tracker.
  The new form reads at three draft sites and both candidates sites,
  one form.
  The old-form sites survive in the record and verbatim classes (`cadf83d`).

- Retired phrasing: no hit on the banned forms. The standing near-hit
  holds, the section 1 negation, "It is not a rigid driveshaft".
  The lift-chain terms read in their split sense.

- Superseded forms: no hit. `3.816`, `14.972` and the message example
  `14.97` all stay unwritten.

- Head status note: no change. The head line reads "Draft v0.37", and
  the nomenclature and references stubs keep their pending markers.

- Held tokens: no change. `1.94` and `5.18` stay under the section 4.2
  note. `3.55` stays flagged in the tracker. The section 5 Daisy gate
  stands.

- Cited commits: the draft names seven (`dd3cc6a`, `a76c5e9`,
  `31ca00d`, `74cfef9`, `9cecee3`, `671ab96`, `e23f226`), plus the era
  label `95c385d`. All resolve in the tip ancestry.

- Freeze re-check: the levers block re-reads byte-identical in the
  draft at `7dd91a9`. The draft region, the receipt region and the
  block file carry the same bytes. The block md5 reads
  `7bbd964db09d2b33269ce5cb8c334054`.

- Pins note: the two Harris-3.5 plate pins recompute on the delivered
  bytes. The ring PNG reads `f49aaaa1` and the twist PNG `00cd857a`,
  both matching the appendix cells.

- Review copy: the copy verifies current at v0.37 for the founder
  read. Nothing moved since the build (md5
  `94619634bd1374abc8327050cf13874d`), and the build inputs carry zero
  diff from `7dd91a9` to the tip.

- Cascade note: the renumber stays ruled. The AU1 placement stays
  closed. PL13 and the Nomenclature fold are the next expected movers.

**Finding**

No value discrepancy found.
The span folds the consistency sweep, the unit forms and the classified counts.
Every token accounts, and the one push matches its declared set.
The register takes one append-only block, and the frozen block re-checks.
The offender delta reads header-only.
The draft passes the gate at the push.

**Next run** at the next draft push.

## Sweep 24: v0.38, 2026-10-14

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`ed3d202` (v0.38, the safety-shorthand pass), spanning one mover from
`68092dc` (the Sweep 23 span end). The file carries zero diff to the
branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `9d96a4b`, zero
diff to the tip.
No movement since Sweep 23.
No signed row changed.

**Results**

- Span note: this pass closes the one draft mover since Sweep 23.
  The span `68092dc..5821a8f` carries non-draft landings outside this gate.

- Span landings: the kmppt addendum `dc29965`, the sweep-23 train
  (`80685c3` to `9553780`), the rope-break reads (`2c97d57`, `ea51b25`),
  the queue `e9355ae` and the v0.38 set (`ed3d202`, `e021ab8`, `5821a8f`).

- Queue note: the safety shorthand joins the queue at `e9355ae`, and
  the NR-025 row amend waits at the aero seat. Noted, not gated.

- Bracket count: the body carries the two number-gate brackets and the
  six seated markers, per part 11.

- STE gate, draft: words 5884 to 5918, total 6 to 6, `per100w=0.10`,
  and `em_dash=2` throughout, the guidance-only pair inside the frozen
  axis names.
  The hook lines hold at `passive_voice x1` and `long_paragraph x5`.

- STE gate, tracker: words 2401 to 2438, total 10 to 10, `per100w`
  0.42 to 0.41. The category set holds at `long_sentence x1`,
  `semicolon x1`, `contraction x1`, `passive_voice x2` and
  `long_paragraph x5`.

- Offender delta, draft and tracker: no offender line moves, entry for
  entry. Only the header lines change.

- Token diff, draft (`68092dc` to `ed3d202`), 1 arrival form, 1
  occurrence, raw 1/1.
  The arrival: the pin `38`. The removal: the pin `37`.
  No other token reads, and no pair reads.

- Value cross-check: no value form moves. The pin pair is a version
  mark, and the reworded lines and the new set carry no digits. The
  classified counts and the standing sums hold (NR-002, NR-001).

- Safety census: the `enabl` and `breaks only` forms read zero across
  the draft. The detector pair, the safety set and the 2026-08-14
  form read their candidate text.

- Push-note check: the v0.38 receipt declares the same single-form
  arrival and the pin removal. The recount holds, token for token.

- Rename census: the old form reads zero sites across the draft, the
  candidates and the tracker.
  The new form reads at three draft sites and both candidates sites,
  one form.
  The old-form sites survive in the record and verbatim classes (`cadf83d`).

- Retired phrasing: no hit on the banned forms. The standing near-hit
  holds, the section 1 negation, "It is not a rigid driveshaft".
  The lift-chain terms read in their split sense.

- Superseded forms: no hit. `3.816`, `14.972` and the message example
  `14.97` all stay unwritten.

- Head status note: no change. The head line reads "Draft v0.38", and
  the nomenclature and references stubs keep their pending markers.

- Held tokens: no change. `1.94` and `5.18` stay under the section 4.2
  note. `3.55` stays flagged in the tracker. The section 5 Daisy gate
  stands.

- Cited commits: the draft names seven (`dd3cc6a`, `a76c5e9`,
  `31ca00d`, `74cfef9`, `9cecee3`, `671ab96`, `e23f226`), plus the era
  label `95c385d`. All resolve in the tip ancestry.

- Freeze re-check: the levers block re-reads byte-identical in the
  draft at `ed3d202`. The draft region, the receipt region and the
  block file carry the same bytes. The block md5 reads
  `7bbd964db09d2b33269ce5cb8c334054`.

- Pins note: the two Harris-3.5 plate pins recompute on the delivered
  bytes. The ring PNG reads `f49aaaa1` and the twist PNG `00cd857a`,
  both matching the appendix cells.

- Review copy: the copy verifies current at v0.38 for the founder
  read. Nothing moved since the build (md5
  `9f9ef1adb753bea5f8d544dc3e13bd96`), and the build inputs carry zero
  diff from `ed3d202` to the tip.

- Copy census: the detector form and the safety set read in the copy,
  and the v0.37 marks read zero.

- Cascade note: the renumber stays ruled. PL13, the Nomenclature fold
  and the k-story fold head the author queue.

**Finding**

No value discrepancy found.
The span folds the safety-shorthand pass with the pin move alone.
Every token accounts, and the one push matches its declared set.
The register holds, and the frozen block re-checks.
The offender delta reads header-only.
The draft passes the gate at the push.

**Next run** at the next draft push.

## Sweep 25: v0.39, 2026-10-14

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`12a5753` (v0.39, the k = 2.24 story fold), spanning one mover from
`5821a8f` (the Sweep 24 span end). The file carries zero diff to the
branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `d2bf63d`, zero
diff to the tip.
Moved since Sweep 24: the k-sweep display-rows sign, NR-047 and NR-048
with the six display rows, the tip pair, the retirements and the sizing pair.
The move is append-only, 101 added lines and none removed.
No signed row changed.

**Results**

- Span note: this pass closes the one draft mover since Sweep 24.
  The span `5821a8f..7d46148` carries non-draft landings outside this gate.

- Span landings: the sweep-24 train (`17a9016` to `ad3eec8`), the queue
  `8d8901a`, the k-sweep sign (`d2bf63d`, `07e2eb9`), the item-5 set
  (`51ffc0d` to `96adbf8`) and the v0.39 set (`12a5753`, `08a91c0`, `7d46148`).

- Queue note: the queue takes the v0.38 span at `8d8901a`, and the
  k-sweep sign and the item-5 extract join the record. Noted, not gated.

- Bracket count: the body carries the two number-gate brackets and the
  six seated markers, per part 11.

- STE gate, draft: words 5918 to 6229, total 6 to 6, `per100w=0.10`,
  and `em_dash=2` throughout, the guidance-only pair inside the frozen
  axis names.
  The hook lines hold at `passive_voice x1` and `long_paragraph x5`.

- STE gate, tracker: words 2438 to 2490, total 10 to 10, `per100w`
  0.41 to 0.40. The category set holds at `long_sentence x1`,
  `semicolon x1`, `contraction x1`, `passive_voice x2` and
  `long_paragraph x5`.

- Offender delta, draft and tracker: no offender line moves, entry for
  entry. Only the header lines change.

- Token diff, draft (`5821a8f` to `12a5753`), 39 arrival forms, 49
  occurrences, raw 49/1.
  The removals: the pin `38` alone. No pair reads.

- Arrival set, the table: `0.5`, `1.0`, `1.5`, `1.94`, `2.24` and
  `3.0`, with the cells `3.49`, `19.14`, `51.8`, `5.45`, `17.64`,
  `47.8`, `6.78`, `16.59`, `42.8`, `7.56`, `15.80`, `40.1`, `8.00`,
  `15.34`, `36.4`, `8.89`, `14.42` and `24.3`.
  `0.5`, `1.5` and `1.94` repeat at the block heads.
  `1.0`, `36.4` and `24.3` take a second site in the side paragraphs, and `2.24` and `3.0` a third.

- Arrival set, the prose: the tips (`17.6`, `85`, `100`, `15.3`,
  `73`), the ceiling path `103`, the retirements (`3.55`, `5.39`,
  `9`), the sizing set (`1278`, `87.9`, `78.8`) and the charge
  (`5`, `5.0`).
  The pin closes the set (`39` in).

- Value cross-check: every arrival accounts to a signed row.
  The table set, the tips and the retirements read NR-047.
  The sizing set reads NR-048 at the record forms, and the charge reads NR-046.
  The pin `39` is the version mark, and `103` is a source path.

- Push-note check: the v0.39 receipt declares the same 39 forms and 49
  occurrences, and the pin `38` removal. The recount holds, token for
  token.

- Arithmetic: no value moves, and the standing sums hold (NR-002, NR-001).

- K-story census: the table reads at the NR-047 display forms, and the
  reject row prints its status and power.

- Safety census: the `enabl` and `breaks only` forms read zero across
  the draft.

- Rename census: the old form reads zero sites across the draft, the
  candidates and the tracker.
  The new form reads at three draft sites and both candidates sites,
  one form.
  The old-form sites survive in the record and verbatim classes (`cadf83d`).

- Retired phrasing: no hit on the banned forms. The standing near-hit
  holds, the section 1 negation, "It is not a rigid driveshaft".
  The lift-chain terms read in their split sense.

- Superseded forms: no hit. `3.816`, `14.972` and the message example
  `14.97` all stay unwritten.

- Head status note: no change. The head line reads "Draft v0.39", and
  the nomenclature and references stubs keep their pending markers.

- Held tokens: `1.94` and `5.18` stay under the section 4.2 note, and
  the k `1.94` row reads NR-047. `3.55` stays flagged in the tracker.
  The section 5 Daisy gate stands.

- Cited commits: the draft names seven (`dd3cc6a`, `a76c5e9`,
  `31ca00d`, `74cfef9`, `9cecee3`, `671ab96`, `e23f226`), plus the era
  label `95c385d`. All resolve in the tip ancestry.

- Freeze re-check: the levers block re-reads byte-identical in the
  draft at `12a5753`. The draft region, the receipt region and the
  block file carry the same bytes. The block md5 reads
  `7bbd964db09d2b33269ce5cb8c334054`.

- Pins note: the two Harris-3.5 plate pins recompute on the delivered
  bytes. The ring PNG reads `f49aaaa1` and the twist PNG `00cd857a`,
  both matching the appendix cells.

- Review copy: the copy verifies current at v0.39 for the founder
  read. Nothing moved since the build (md5
  `f1ceae4d2278361756ba6c9b631f310d`), and the build inputs carry zero
  diff from `12a5753` to the tip.

- Copy census: the table rows, the retirements and the sizing pair
  read in the copy, and the v0.38 marks read zero.

- Cascade note: the renumber stays ruled. PL13 heads the author queue,
  and the Nomenclature fold joins it.

**Finding**

No value discrepancy found.
The span folds the k = 2.24 story with the display-rows sign.
Every token accounts, and the one push matches its declared set.
The register takes the two append-only rows, and the frozen block re-checks.
The offender delta reads header-only.
The draft passes the gate at the push.

**Next run** at the next draft push.

## Sweep 26: v0.40, 2026-10-14

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`0e7d396` (v0.40, the decision shape), spanning one mover from
`7d46148` (the Sweep 25 span end). The file carries zero diff to the
branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `a7d09eb`, zero
diff to the tip.
Moved since Sweep 25: the item-8 aero leg, two appended blocks.
The blocks carry the NR-047/NR-048 counter-read verdict and the NR-025 wording amend.
The move is append-only, 54 added lines and none removed.
No signed row changed.

**Results**

- Span note: this pass closes the one draft mover since Sweep 25.
  The span `7d46148..ad56692` carries non-draft landings outside this gate.

- Span landings: the sweep-25 train (`ff159d7` to `bbc214e`), the queue
  `9166686`, the item-8 aero leg (`a7d09eb` to `8d3b61d`), the item-5
  counter-read `d0679d3`, the figures seat page (`e04e072`, `7fc0717`)
  and the v0.40 set (`0e7d396`, `bacf9e2`, `716bd3a`, `ad56692`).

- Queue note: the queue takes the v0.39 span at `9166686`.
  Item 8 and the item-5 counter-read close, and PL13 closes at the
  author seat. Noted, not gated.

- Register companion note: the aero leg takes the room-consultation
  line to the detector form (one line, 1/1), and the `.ste-exempt`
  takes the consultation row under its comment extension.
  Noted, not gated.

- Bracket count: the body carries the two number-gate brackets and the
  six seated markers, per part 11.

- STE gate, draft: words 6229 to 6281, total 6 to 6, `per100w=0.10`,
  and `em_dash=2` throughout, the guidance-only pair inside the frozen
  axis names.
  The hook lines hold at `passive_voice x1` and `long_paragraph x5`.

- STE gate, tracker: words 2490 to 2542, total 10 to 10, `per100w`
  0.40 to 0.39. The category set holds at `long_sentence x1`,
  `semicolon x1`, `contraction x1`, `passive_voice x2` and
  `long_paragraph x5`.

- Offender delta, draft and tracker: no offender line moves, entry for
  entry. Only the header lines change.

- Token diff, draft (`12a5753` to `0e7d396`), 1 arrival form, 1
  occurrence, raw 1/1.
  The arrival is the pin `40`. The removal is the pin `39`.
  No pair reads.

- Value cross-check: no value form moves.
  The pin pair is a version mark, and the shape additions carry no digits.

- Push-note check: the v0.40 receipt declares the same pin pair and
  the tracker `40` add. The recount holds, token for token.

- Arithmetic: no value moves, and the standing sums hold (NR-002, NR-001).

- Shape census: the six shape lines read at their sites in sections
  3.4 to 3.6.
  Sections 4 and 5 hold byte-identical against the base.

- K-story census: the table reads at the NR-047 display forms, and the
  reject row prints its status and power.

- Safety census: the `enabl` and `breaks only` forms read zero across
  the draft. The detector pair and the safety set read at their sites.

- Rename census: the old form reads zero sites across the draft, the
  candidates and the tracker.
  The new form reads at three draft sites and both candidates sites,
  one form.
  The old-form sites survive in the record and verbatim classes (`cadf83d`).

- Retired phrasing: no hit on the banned forms. The standing near-hit
  holds, the section 1 negation, "It is not a rigid driveshaft".
  The lift-chain terms read in their split sense.

- Superseded forms: no hit. `3.816`, `14.972` and the message example
  `14.97` all stay unwritten.

- Head status note: no change. The head line reads "Draft v0.40", and
  the nomenclature and references stubs keep their pending markers.

- Held tokens: `1.94` and `5.18` stay under the section 4.2 note, and
  the k `1.94` row reads NR-047. `3.55` stays flagged in the tracker.
  The section 5 Daisy gate stands.

- Cited commits: the draft names seven (`dd3cc6a`, `a76c5e9`,
  `31ca00d`, `74cfef9`, `9cecee3`, `671ab96`, `e23f226`), plus the era
  label `95c385d`. All resolve in the tip ancestry.

- Freeze re-check: the levers block re-reads byte-identical in the
  draft at `0e7d396`. The draft region, the receipt region and the
  block file carry the same bytes. The block md5 reads
  `7bbd964db09d2b33269ce5cb8c334054`.

- Pins note: the two Harris-3.5 plate pins recompute on the delivered
  bytes. The ring PNG reads `f49aaaa1` and the twist PNG `00cd857a`,
  both matching the appendix cells.

- Review copy: the copy verifies current at v0.40 for the founder
  read. Nothing moved since the build (md5
  `835de8d8dc92e209d23cba39e7c11549`), and the build inputs carry zero
  diff from `0e7d396` to the tip.

- Copy census: the shape lines read in the copy, and the v0.39 marks
  read zero.

- Cascade note: the renumber stays ruled. AU9 and the partner-gated
  tails head the author queue.

**Finding**

No value discrepancy found.
The span folds the decision shape with the pin move alone.
Every token accounts, and the one push matches its declared set.
The register takes the two append-only blocks, and the frozen block re-checks.
The offender delta reads header-only.
The draft passes the gate at the push.

**Next run** at the next draft push.

## Sweep 27: v0.41, 2026-10-14

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`e8159b0` (v0.41, the machine winner hero fold), spanning one mover from
`ad56692` (the Sweep 26 span end). The file carries zero diff to the
branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `a7d09eb`, zero
diff to the tip. No register movement reads in this span.

**Results**

- Span note: this pass closes the one draft mover since Sweep 26.
  The span `ad56692..e8159b0` carries non-draft landings outside this
  gate.

- Span landings: the sweep-26 train (`89ddfde` to `a359061`), the v0.40
  counter-read set (`b0d7f70`, `84dbfd6`, `3ac48af`), the glance
  `f030fe6`, the queue set (`4a7cc8d`, `4936b16`, `dce5e61`), the status
  note `150b145` and the hero set (`599d0fb`, `c438398`, `e8159b0`).

- Queue note: the queue takes the v0.40 span at `4a7cc8d`.
  The consultation flip call reads kept, and its comment row lands in
  `.ste-exempt`. Noted, not gated.

- Bracket count: the body carries the two number-gate brackets and the
  seven seated markers.

- STE gate, draft: words 6281 to 6309, total 6 to 6, `per100w=0.10`,
  and `em_dash=2` throughout. The hook lines hold at `passive_voice x1`
  and `long_paragraph x5`.

- STE gate, tracker: words 2542 to 2609, total 10 to 10, `per100w`
  0.39 to 0.38. The category set holds at `long_sentence x1`,
  `semicolon x1`, `contraction x1`, `passive_voice x2` and
  `long_paragraph x5`.

- Offender delta, draft and tracker: no offender line moves, entry for
  entry. Only the header lines change.

- Token diff, draft (`0e7d396` to `e8159b0`):
  2 arrival forms, 2 occurrences, raw 2/1.
  The arrivals are the pin `41` and the marker row number `10`.
  The removal is the pin `40`.
  No pair reads.

- Raw pairs: no net-out pair and no kept pair reads.
  The one-sided tokens account for the net exactly.

- Value cross-check: no register value form moves.
  The marker and the appendix row carry cited row IDs and file hashes
  only.

- Push-note check: the hero landing declares the capture set, the
  three-run byte identity, the rebuilt copy and "No value moves".
  The recount holds, token for token.

- Arithmetic: no value moves, and the standing sums hold (NR-002,
  NR-001).

- Hero census: the seat marker reads `1x` at section 3.3, and the
  appendix count line reads "All seven". The slug reads at the marker,
  and the title reads at the appendix row and the hash block (`2x`).

- Span censuses: the safety set reads at section 4.1.
  The detector pair reads via the flat census, because a line grep
  misses one wrapped form. The shape lines and the k-story rows hold
  at their sites.

- Rename census: the old form reads zero sites across the draft, the
  candidates and the tracker. The new form reads at three draft sites
  and both candidates sites, one form. The old-form sites survive in
  the record and verbatim classes (`cadf83d`).

- Retired phrasing: no hit on the banned forms or the sampled
  stale-phrase stems. The standing near-hits, including the section 1
  negation, hold.

- Superseded forms: no hit. `3.816`, `14.972` and the message example
  `14.97` all stay unwritten.

- Head status note: the head line reads "Draft v0.41", and the
  nomenclature and references stubs keep their pending markers.

- Held tokens: `1.94` and `5.18` stay under the section 4.2 note, and
  the k `1.94` row reads NR-047. `3.55` stays flagged in the tracker.
  The section 5 Daisy gate stands.

- Cited commits: the draft names eight (`dd3cc6a`, `a76c5e9`,
  `31ca00d`, `74cfef9`, `9cecee3`, `671ab96`, `e23f226`, `c438398`),
  plus the era label `95c385d`. All resolve in the tip ancestry.

- Freeze re-check: the levers block re-reads byte-identical in the
  draft at `e8159b0`. The draft region, the receipt region and the
  block file carry the same bytes. The block md5 reads
  `7bbd964db09d2b33269ce5cb8c334054`.

- Pins note: all twenty-eight appendix cells recompute on the delivered
  bytes, the four hero cells included. No mismatch reads.

- Review copy: the copy rebuilds at `e8159b0`, and the build inputs
  carry zero diff from the stamp to the tip. The live copy matches its
  stamp (md5 `7192f4a9dd4694b63c73cf49944a5844`).

- Copy census: the hero reads in the copy through its caption and the
  seats line. The appendix keeps the mark "All seven".
  The v0.40 marks read zero.

- Guard census: the register appendix keeps the NR-009 value `14.972`
  once. The forms `3.816`, the rounded `27.363` and the unresolved
  notice read zero.

- Cascade note: the renumber stays ruled. AU9 and the partner-gated
  tails head the author queue.

**Finding**

No value discrepancy found.
The span folds the hero with the pin move and the marker line alone.
Every token accounts, and the one draft push matches its declared set.
The register holds, the frozen block re-checks, and the pins recompute.
The copy rebuilds current at v0.41, and the offender delta reads header-only.

**Next run** at the next draft push.

## Sweep 28: v0.42, 2026-10-14

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`38c77f8` (v0.42, the gate-margin column fold), spanning one mover from
`e8159b0` (the Sweep 27 span end). The file carries zero diff to the
branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `2510886`, zero diff to the tip.
Moved since Sweep 27: the display-form note block for the gate-margin column
(NR-009 on NR-015). The move is append-only, 32 added lines and none removed.
No signed row changed.

**Results**

- Span note: this pass closes the one draft mover since Sweep 27.
  The span `e8159b0..d2744fe` carries non-draft landings outside this
  gate, the currency set included.

- Span landings: the sweep-27 train (`b526161` to `0f46aa7`), the hero
  counter-read set (`e3446db`, `54a539e`, `0cbb9b8`), the display-form
  note `2510886`, the row-10 closure `60f5a32`, the v0.42 set (`38c77f8`,
  `dff427f`, `bfb8f55`, `467ffc1`) and the currency set (`b86b750`, `d2744fe`).

- Bracket count: the body carries the two number-gate brackets and the
  seven seated markers.

- STE gate, draft: words 6309 to 6388, total 6 to 6, `per100w` 0.10 to
  0.09, and `em_dash=2` throughout.
  The hook lines hold at `passive_voice x1` and `long_paragraph x5`.

- STE gate, tracker: words 2609 to 2660, total 10 to 10, `per100w`
  0.38 to 0.38.
  The category set holds at `long_sentence x1`, `semicolon x1`,
  `contraction x1`, `passive_voice x2` and `long_paragraph x5`.

- Offender delta, draft and tracker: the offender sets hold, entry for
  entry.
  One display line moves with the fold, the flagged gate-table line
  that takes the margin column. The tracker delta reads header-only.

- Token diff, draft (`e8159b0` to `38c77f8`):
  18 arrival forms, 19 occurrences, raw 22/5.
  The pin moves, the margin set arrives, and the power cell swaps
  `5.309` for `5.314`.

- Raw pairs: the net-out pair reads `5.0` on the power-row rewrite.
  The kept pairs read `2.5` and `15.0` at net `+1` each.
  No other pair reads.

- Value cross-check: the six gate rows read their signed sources.
  The power pair reads NR-008, the FoS row the display-form note, the
  clearance row NR-042.
  The twist and torsional pairs read NR-022 and NR-040.
  The rope-break cell states the NR-013 reading, and no signed row
  changes.

- Push-note check: the v0.42 checker declares 18 forms and 19
  occurrences adding, and `41` and `5.309` removing.
  The recount matches at the checker.
  The receipt prose list omits the end-power form `5.314`.
  The checker log carries it.

- Arithmetic: the printed margins reproduce on the printed operands
  (power `+0.314` on `5.0`, FoS `+12.5` on `2.5`, clearance `+3.968`
  on `1.5`).
  The twist and torsional margins reproduce on their row digits.

- Margin census: the six rows read at the table, and the margin column
  forms read at their cells.
  The corrected cells read (`P_end 5.314 kW`, `5.468 m`).

- Guard census: the display guards hold (`14.97`, `14.972`, `3.816`
  and the rounded `27.363` read zero), and the internal margin forms
  read zero (`+12.472`, `+498.9`, `5.99`).
  The FoS outcome cell keeps "pass, 15.0 minimum".

- Glossary check: the term `torsional capacity` reads its candidates
  entry (`860572d`).
  The gate row prints the term once at section 3.3.

- Rename census: the old form reads zero sites across the draft, the
  candidates and the tracker. The new form reads at three draft sites
  and both candidates sites, one form.
  The old-form sites survive in the record and verbatim classes
  (`cadf83d`).

- Retired phrasing: no hit on the banned forms or the sampled
  stale-phrase stems. The standing near-hits, the section 1 negation
  included, hold.

- Superseded forms: no hit. `3.816`, `14.972` and the message example
  `14.97` all stay unwritten.

- Head status note: the head line reads "Draft v0.42", and the
  nomenclature and references stubs keep their pending markers.

- Held tokens: `1.94` and `5.18` stay under the section 4.2 note, and
  the k `1.94` row reads NR-047. `3.55` stays flagged in the tracker.
  The section 5 Daisy gate stands.

- Cited commits: the draft names eight (`dd3cc6a`, `a76c5e9`,
  `31ca00d`, `74cfef9`, `9cecee3`, `671ab96`, `e23f226`, `c438398`),
  plus the era label `95c385d`. All resolve in the tip ancestry.

- Freeze re-check: the levers block re-reads byte-identical in the
  draft at `38c77f8`. The draft region, the receipt region and the
  block file carry the same bytes. The block md5 reads
  `7bbd964db09d2b33269ce5cb8c334054`.

- Pins note: all twenty-eight appendix cells recompute on the delivered
  bytes. No mismatch reads.

- Review copy: the copy rebuilds at `38c77f8`, and no copy input moves
  from the stamp to the tip.
  The live copy matches its stamp (md5 `1bec17262fa4a97686a0158d2f2c31d1`).
  The one post-stamp script change (`doc_currency_check.py`, `b86b750`)
  sits outside the copy chain.

- Copy census: the margin forms read in the copy at their cells, and
  the v0.41 marks read zero.
  The hero forms and the count line hold ("All seven").

- Copy guards: the register appendix keeps the NR-009 value `14.972`
  once.
  The internal margin forms read zero there, and the unresolved notice
  reads zero.

- Cascade note: the renumber stays ruled. The partner-gated tails and
  the kMppt plain pass head the author queue.

**Finding**

No value discrepancy found.
The span folds the gate-margin column with the pin move and the margin set.
The register takes the display-form note, append-only.
Every token accounts, and the copy rebuilds current at v0.42.
The offender sets hold, and the frozen block and the pins re-check.

**Next run** at the next draft push.

## Sweep 29: v0.43, 2026-10-14

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`e5541e9` (v0.43, the round-5 wording set), spanning one mover from
`d2744fe` (the Sweep 28 span end). The file carries zero diff to the
branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `94aa219`, zero diff to the tip.
Moved since Sweep 28: the NR-049 and NR-050 derived rows append.
The move is append-only, 110 added lines and none removed.
No earlier signed row changed.

**Results**

- Span note: this pass closes the one draft mover since Sweep 28.
  The span `d2744fe..8a1e552` carries 18 landings.
  The non-draft sets sit outside this gate, the caption set included.

- Span landings: the sweep-28 train (`4b19592` to `d2a57aa`), the queue
  set (`28b00e3`, `c039aa6`, `d1e9bf1`), the counter-read set (`658e7bb`,
  `cd779dd`), the fb5 source reads `94aa219`, the caption set (`12f4b59`,
  `c177213`), and the v0.43 set (`e5541e9` to `8a1e552`).

- Caption note: the round-5 caption dedupe (`12f4b59`, figures seat)
  moves text only, on rows 6, 7 and 9.
  Each plain tier takes one takeaway sentence.
  No render byte moves, and the map takes delta v34.
  The copy built at `e5541e9` reads the new sentences at their exhibits.

- Bracket count: the body carries the two number-gate brackets and the
  seven seated markers.

- STE gate, draft: words 6388 to 6545, total 6 to 6, `per100w` 0.09 to
  0.09, and `em_dash=2` throughout.
  The hook lines hold at `passive_voice x1` and `long_paragraph x5`.

- STE gate, tracker: words 2660 to 2714, total 10 to 10, `per100w`
  0.38 to 0.37.
  The category set holds at `long_sentence x1`, `semicolon x1`,
  `contraction x1`, `passive_voice x2` and `long_paragraph x5`.

- Offender delta, draft and tracker: the offender sets hold, entry for
  entry.
  The delta reads header-only on both surfaces.
  No offender entry moves.

- Token diff, draft (`38c77f8` to `e5541e9`):
  4 arrival forms, 5 occurrences, raw 8/6.
  The base pair arrives, the cone `22` lands twice, and the pin moves
  `42` to `43`.
  The removals read `1`, `2` and `42`.

- Token diff, tracker: the pin `43` arrives, seven added lines and none
  removed.

- Raw pairs: the net-out pairs read `0.82` and `0.20` on the slot
  rewrites.
  The kept pair reads `22` at net `+2`, raw removed-side 1 and
  added-side 3.
  No other pair reads.

- Value cross-check: the fold values read their signed sources.
  The base pair reads NR-050, and the cone `22` reads NR-049 at both
  sites.
  The bank slot reads NR-011 and NR-017, and no signed row changes.

- Push-note check: the v0.43 checker declares the same sets, and the
  recount matches token for token.
  The receipt prose carries the sets in full, with no transcription
  item.

- Arithmetic: the base fractions re-derive on the NR-050 decode.
  The base span reads `1.8255879832269168`, and the span times the
  scale reads the NR-043 form `1.4994019682084492`.
  The chord chain closes at `0.22590989654340632`.

- Cone census: the two cone statements name the shaft transition cone,
  at sections 2.1 and 3.5.
  The bank site names `bank_bottom` at section 3.3.
  The `22 degrees` census reads three sites, and the bare-22 sweep adds
  no other degree site.

- Tulloch guard: the compound form reads zero, and `Jensen` reads zero.
  The single standing `Tulloch` mention sits in section 1, away from
  both cone sites.

- Slot census: `blade_scale_top`, `blade_scale_bottom` and `bank_bottom`
  read once each in the body.
  The old slot labels read zero.
  The cold-path line reads at section 2.5, and the campaign-scale
  context reads at section 3.1.

- Glossary note: the phrase `physics-validation era` enters section 3.1.
  The candidates carry no entry for it yet.
  The row rides the era pack at this seat.

- Fold census: each new sentence in the wording set reads once.
  The set covers the base clause, the two cone statements, the cold-path
  line, the campaign-scale context, the swing reading, the lifter
  rationale, the staged launch, the slot names and the bank split.

- Head status note: the head line reads "Draft v0.43", and the
  nomenclature and references stubs keep their pending markers.

- Held tokens: `1.94` and `5.18` stay under the section 4.2 note, and
  the k `1.94` row reads NR-047.
  `3.55` stays flagged in the tracker.
  The section 5 Daisy gate stands.

- Cited commits: the draft names `dd3cc6a`, `a76c5e9`, `31ca00d`,
  `74cfef9`, `9cecee3`, `671ab96`, `e23f226` and `c438398`, plus the
  era label `95c385d`.
  All resolve in the tip ancestry.
  The hex inventory holds at 66 entries, zero diff against the Sweep 28
  read.

- Freeze re-check: the levers block re-reads byte-identical in the
  draft at `e5541e9`.
  The draft region, the receipt region and the block file carry the
  same bytes.
  The block md5 reads `7bbd964db09d2b33269ce5cb8c334054`.

- Pins note: all twenty-eight appendix cells recompute on the delivered
  bytes. No mismatch reads.

- Review copy: the copy rebuilds at `e5541e9`, and no copy input moves
  from the stamp to the tip.
  The live copy matches its stamp (md5 `3374a638aa89e61e9957193dffc1536d`).
  The build record reads 40 cited all signed and seven seats resolved.

- Copy census: the v0.43 forms read in the copy at their cells.
  The base clause, the three `22 degrees` sites, the slot names, the
  cold-path line and the staged launch all read.
  The old slot labels read zero, and the v0.42 marks read zero.

- Copy captions: the three takeaway sentences read at their exhibits in
  the copy, and the retired reading key reads zero.

- Copy guards: the register appendix keeps the NR-009 value `14.972`
  once.
  The internal margin forms read zero there, and the unresolved notice
  reads zero.

- Cascade note: the era pack rides this seat next.
  The partner-gated tails stay with the author, and the figure-pack
  legs stay at the figures seat.

**Finding**

No value discrepancy found.
The span folds the round-5 wording set with the base clause, the two cone
statements, the slot names and the line folds.
The register takes NR-049 and NR-050, append-only.
Every token accounts, and the copy rebuilds current at v0.43.
The offender sets hold, and the frozen block and the pins re-check.

**Next run** at the next draft push.

## Sweep 30: v0.47, 2026-10-15

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`d0ed902` (v0.47, the round-6 fold), spanning four movers from
`8a1e552` (the Sweep 29 span end). The file carries zero diff to the
branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `cb862df`, zero diff to the tip.
Moved since Sweep 29: the NR-051 corner-picks row appends.
The move is append-only, 62 added lines and none removed.
No earlier signed row changed.

**Results**

- Span note: this pass closes the four draft movers since Sweep 29.
  The span `8a1e552..4ded913` carries 48 landings.
  The non-draft sets sit outside this gate, the receipts and the kits included.

- Span landings: the sweep-29 train and the v0.43 counter-reads.
  Next, the v5 re-cut, the corner mint and the v0.45 set.
  Then, the fb6 routing, the round-6 sign and the copy walk.
  The figure train, the v0.47 fold and the term gate follow.
  The counter-reads, the fold-back, the rebuild and the legs follow.
  The closure re-reads and the corner build close the span.

- Queue note: the round-6 legs (`69ec727` to `50e0300`) re-form the
  tracker, the candidates and the stale-phrases list.
  The leg receipt carries their full check set.
  The aero re-read counts the folds exact, tracker 2/2, candidates 10/3,
  stale-phrases 4/3.

- Bracket count: the body carries the two number-gate brackets and the
  seven seated markers.

- STE gate, draft: words 6545 to 6889, total 6 to 8, `per100w` 0.09 to
  0.12. The two new flags are the two table blocks, the accepted class
  declared at v0.45. The hook lines hold at `passive_voice x1` and
  `em_dash=2`.

- STE gate, tracker: words 2714 to 2927, total 10 to 11, `per100w`
  0.37 to 0.38. One semicolon occurrence arrives with the v0.44 note.
  The offender line sets hold.

- STE gates, candidates and stale-phrases: the candidates read 4598 to
  4687 words at 0.26, flat. The stale-phrases list reads 588 to 610 at
  3.40 to 3.28, whole-file legacy.

- Offender delta: the draft adds the two table block heads, the
  accepted class. The tracker, candidates and stale-phrases sets hold,
  entry for entry. The candidates delta reads header-only.

- Token diff, draft (`e5541e9` to `d0ed902`): four mover pairs.
  The v0.44 pass moves `43` to `44`, its version token.
  The v0.45 set arrives as declared, seven arrivals against `44`.
  The v0.46 pass moves `45` to `46`, its version token.
  The v0.47 pair reads arrivals `47` and `508`, removal `46`.

- Cumulative: eight arrival forms arrive and one token leaves.
  The arrivals read `1.94`, `18.8`, `2`, `2.2`, `2.4`,
  `47`, `5.18` and `508`. The removal reads `43`.

- Token diff, tracker: twelve arrivals and no removal net. The set
  reads `1`, `2`, `3`, `3.3`, `3.4`, `4.2`, `44` to `47`, `508` and `930`.
  Raw 14 and 2.

- Raw pairs: seven net-out pairs ride the v0.47 rewrites. They read
  `0.804`, `1278`, `15.033`, `25.698`, `3.4`, `4.580` and `5.309`.
  Raw 10 and 10, and every value keeps its digits.

- Value cross-check: the count reads NR-002, the winner pair reads
  NR-008 and NR-018, and the ring forms read NR-011 and NR-021.
  The fold values keep their digits at every site.

- Push-note check: the v0.44 to v0.47 notes declare their sets. The
  recount matches each one token for token, with no transcription item.

- Arithmetic: the count sums read 508 plus 422 at 930. The split
  re-reads 301, 110 and 11, and the parts sum to 930 (NR-002).

- Span censuses, folds: the ten top-form sites each read once. The
  count sentence, the winner pair and the section 3.4 title read once.

- Span censuses, tables and carries: the era map reads its four rows,
  and the failure ledger reads its six entries. The three `22 degrees`
  sites, the slot names, the cold-path line and the `physics-validation
  era` phrase all read.

- Rename census: the retired word reads zero, raw and as a word. The
  top forms read `topmost ring` six times and `topmost rotor ring` once,
  and the nine top lines match the term gate.

- Retired phrasing: `adaptive` and `DifferentialEquations` read zero.
  The stale-phrases stems read zero in the body, and the naming-trap
  near-hits read none.

- Display guards: the loose guard forms read zero, `14.97`, `3.816` and
  `27.363`. The finer neighbours keep their spaced forms.

- Head status: the head reads "Draft v0.47", and the two `[PENDING]`
  stubs keep their markers.

- Held tokens: `1.94` and `5.18` hold at the section 4.2 note and the
  failure table, and the k `1.94` row reads NR-047. `3.55` stays
  flagged in the tracker, and the section 5 Daisy gate stands.

- Cited commits: the ten named commits resolve in the tip ancestry.
  The hex inventory reads 64 entries.

- Freeze re-check: the levers block re-reads byte-identical in the
  draft at `d0ed902`. The draft region, the receipt region and the
  block file carry the same bytes. The block md5 reads
  `7bbd964db09d2b33269ce5cb8c334054`.

- Pins note: all twenty-eight appendix cells recompute on the delivered
  bytes. No mismatch reads.

- Plate pins: the re-cut set re-hashes. The ring-utilisation svg reads
  `ce3dee12…`, the twist-limit svg `cc3edf9c…`, the eval-timeline svg
  `30dc05bc…`, the strip svg `6c36b0ff…` and the hero svg `0101b58f…`.

- Review copy: the copy holds at its `d0ed902` build. The live md5
  reads `1115a201…`, and the draft and register inputs carry zero diff
  to the tip. The record reads 42 cited of 51 signed and seven seats.

- Copy census: the top forms read nine sites, and the count and the
  winner pair read once each. The retired word reads five as a word,
  all register-appendix holds by row. No capital form reads.

- Cascade note: the era pack still rides this seat, and the scan-entry
  call sits with the room. The corner grid reads unseated at the next
  fold.

**Finding**

No value discrepancy found.
The span folds the four movers: the two re-pin passes, the AU7 tables
and the round-6 fold.
The register takes NR-051, append-only, and every token accounts.
The rename reads zero old-form sites, and the winner pair reads its row.
The offender sets hold, and the frozen block and the pins re-check.

**Next run** at the next draft push.

## Sweep 31: v0.49, 2026-10-15

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`8169e36` (v0.49, the re-key fold), spanning two movers from
`4ded913` (the Sweep 30 span end). The file carries zero diff to the
branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `cb862df`, zero diff to the tip.
Moved since Sweep 30: none.
The register holds by the sign.

**Results**

- Span note: this pass closes the two draft movers since Sweep 30.
  The span `4ded913..ffc63a7` carries 24 landings.
  The non-draft landings sit outside the token gate.
  The figures tree carries one text move (the generation notes).
  No art byte moves.

- Span landings: the sweep-30 train (`94742ec` to `72115e7`).
  Next, the map-seat set and the corner counter-read set.
  Then, the figures relabel set (`9241b23`, `6f19eee`, `65553d9`).
  The v0.49 set follows (`8169e36` to `3c4d2c8`).
  The lifting-bridles term set closes the span (`97eefdc` to `ffc63a7`).

- Queue note: the lifting-bridles term set re-forms the candidates (v17)
  and the stale-phrases list, and folds the two routed figure-note sites.
  The leg receipt carries the full check set.

- Bracket count: the body carries the two number-gate brackets and the
  seven seated markers.

- STE gate, draft: words 6889 to 6887, total 8 to 8, `per100w` 0.12 to 0.12.
  The offender set holds entry for entry.
  The hook lines hold at `passive_voice x1` and `em_dash=2`.

- STE gate, tracker: words 2927 to 3033, total 11 to 12, `per100w`
  0.38 to 0.40.
  One semicolon occurrence arrives with the v0.49 note.
  The offender line sets hold.

- STE gates, candidates and stale-phrases: the candidates read 4687 to 4733 words
  at 0.26 to 0.25, flat.
  The stale-phrases list reads 610 to 623 at 3.28 to 3.21, whole-file legacy.

- Offender delta: the four sets hold, entry for entry.
  The headers move by construction only.
  The stale-phrases replacement line keeps its standing class.
  It moves 27 to 29 words inside it.

- Token diff, draft (`d0ed902` to `8169e36`): two mover pairs.
  The v0.48 pass moves `47` to `48`, its version token.
  The v0.49 pair reads arrival `49` and removal `48`.
  Cumulative: `49` in and `47` out.

- Token diff, tracker: three arrivals and no removal net.
  The set reads `2`, `48` and `49`. Raw 3 and 0.

- Raw pairs: one net-out pair rides the v0.49 marker rewrite.
  The pair sits at the section 3.3 marker and carries the winner form.
  No value pair reads.

- Value cross-check: the count reads NR-002, the winner pair reads
  NR-008 and NR-018, and the ring forms read NR-011 and NR-021.
  The fold values keep their digits at every site.

- Push-note check: the v0.48 note declares the appendix pins, and the
  recount reads the pin token with the hex cells riding the hex inventory.
  The v0.49 note declares add `49` and remove `48`, and the recount
  matches token for token.
  The changed-line census reads exact (draft lines 3, 484, 539, 946 and 994).

- Arithmetic: the count sums read 508 plus 422 at 930.
  The split re-reads 301, 110 and 11.

- Span censuses, folds: the top forms read `topmost ring` six times and
  `topmost rotor ring` once, and the nine top lines match the term gate.
  The count sentence, the winner pair and the section 3.4 title read once.

- Rename census, hub: the retired word reads zero, raw and as a word.

- Rename census, the founder forms: `lifting bridles` reads once (the section 3.3 load path).
  The winner form reads `Machine winner` twice and `machine winner` once at the marker.
  `hero` reads once, in the slug.
  The hold senses read: the stiffening bridles, the tether-or-bridle definition and the blade bridling.

- Display guards: the loose guard forms read zero, `14.97`, `3.816` and
  `27.363`. The finer neighbours keep their spaced forms.

- Head status: the head reads "Draft v0.49", and the two `[PENDING]`
  stubs keep their markers.

- Held tokens: `1.94` and `5.18` hold at the section 4.2 note and the
  failure table, and the k `1.94` row reads NR-047. `3.55` stays
  flagged in the tracker, and the section 5 Daisy gate stands.

- Cited commits: the eleven named commits resolve in the tip ancestry.
  The hex inventory reads 65 entries (was 64 at Sweep 30).

- Freeze re-check: the levers block re-reads byte-identical in the
  draft at `8169e36`. The draft region, the receipt region and the
  block file carry the same bytes. The block md5 reads
  `7bbd964db09d2b33269ce5cb8c334054`.

- Pins note: all twenty-eight appendix cells recompute on the delivered
  bytes. No mismatch reads. The pins tool takes the winner-form heading
  in its label map.

- Plate pins: the seated kits re-hash. The ring-utilisation svg reads
  `ce3dee12…`, the twist-limit svg `cc3edf9c…`, the eval-timeline svg
  `30dc05bc…`, the strip svg `6c36b0ff…` and the winner svg `0101b58f…`.
  The system-anatomy set takes the v7 re-cut (pdf `c55bd7a8…`, png
  `696be723…`).

- Review copy: the copy holds at its `8169e36` build. The live md5
  reads `24f98df6…`, and the draft and register inputs carry zero diff
  to the tip. The record reads 42 cited of 51 signed and seven seats.

- Copy census: the founder forms read in the copy.
  `Three lifting bridles` once, `down the lifting bridles` once,
  `Machine winner` twice, the slug three times and the top forms nine sites.
  The count sentence and the winner pair read once each.
  The retired word reads its five holds, all in the register appendix.

- Cascade note: the desk-document amends and the term gate re-read sit
  with the validator. The era pack and the explainer block stay open at
  this seat. The corner grid reads seated-ready at the next fold.

**Finding**

No value discrepancy found.
The span folds the two movers: the SA appendix pins and the re-key set.
The register holds, and every token accounts.
The founder forms read at their sites, and the hold senses read.
The offender sets hold, and the frozen block and the pins re-check.

**Next run** at the next draft push.

## Sweep 32: v0.52, 2026-10-15

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`b6cd166` (v0.52, the basics-of-TRPT refresher), spanning three movers from
`ffc63a7` (the Sweep 31 span end): `171f3ea` (v0.50, the kMppt plain pass),
`1061878` (v0.51, the corner-machines fold) and `b6cd166`. The file carries
zero diff to the branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `cb862df`, zero diff to the tip.
No movement since Sweep 31.
The register holds by the sign.

**Results**

- Span note: this pass closes the three draft movers since Sweep 31.
  The span `ffc63a7..1b01453` carries 44 commits.
  The candidates file and the stale-phrases list carry no mover in the span.
  The figures tree carries the eval-timeline placement label re-cut
  (`a269636`, `f5c2d59`).
  No seated plate byte moves.

- Span landings: the relabel fold-back (`e5e147c`, `ef93b84`), the v0.50
  set (`171f3ea` to `a196183`), the corner-machines fold and its reads
  (`1061878` to `228adcd`), the v0.52 set (`b6cd166` to `ec24f4a`), the
  rope-break placement fix (`2bf76a3`, `317d9cd`) and the eval-timeline
  re-cut (`a269636`, `f5c2d59`).

- Bracket count: the body carries the two number-gate brackets and the
  eight seated markers.

- STE gate, draft: words 6887 to 7002 across the three movers (6887, 6890,
  6912, 7002), total 8 to 8, `per100w` 0.12 to 0.11.
  `em_dash=2` throughout, the guidance-only pair inside the frozen axis names.
  The hook lines hold at `passive_voice x1` and `long_paragraph x7`.

- STE gate, tracker: words 3033 to 3177, total 12 to 12, `per100w`
  0.40 to 0.38.

- STE gates, candidates and stale-phrases: the candidates read 4733 words
  at 0.25, flat.
  The stale-phrases list reads 623 words at 3.21, whole-file legacy.

- Offender delta: the four sets hold, entry for entry.
  The headers move by construction only.
  The v0.52 block adds no long_paragraph line, and every offender count
  holds across the three movers.

- Token diff, draft (`171f3ea^` to `b6cd166`), per mover.
  The v0.50 pair reads arrival `50` and removal `49`.
  The v0.51 pair reads arrivals `23` and `51` against removal `50`.
  The v0.52 pair reads arrival `52` and removal `51`.
  Cumulative: `23` and `52` in, `49` out.

- Identity check: every span token reads net == added minus removed.

- Token diff, tracker: arrivals `50`; `3.4` and `51`; `2.1` and `52`.
  No removal net.

- Changed-line census, per mover: v0.50 reads lines 3, 318 and 320 to 321.
  v0.51 reads line 3, a two-line insert at 635, a replace at 936 to 938,
  a one-line insert at 949 and a seven-line insert at 1003.
  v0.52 reads line 3 and a thirteen-line insert at 230.

- Value cross-check: the span adds no value token.
  The lone arrival is the marker numeral `23`.
  The checked set carries forward: NR-001, NR-002, NR-005, NR-006, NR-008,
  NR-009, NR-011, NR-018, NR-021, NR-040, NR-045, NR-048, NR-049 and NR-051.
  Every printed value reads its row or side block at the quoted precision.

- The v0.50 fold holds its values on the changed lines: `1278 N/vertex`,
  `87.9`, `78.8` and all three NR-048 cites.
  The two rewritten sentences carry no value token.

- The v0.52 block reads ten sentences, once each, digit-free and cite-free,
  between the term-set close (NR-049) and the system-anatomy seat marker.
  The block sits at lines 230 to 242.

- Arithmetic: the counts hold at 508 plus 301 plus 110 plus 11 reading 930,
  and 508 plus 422 reading 930 (NR-002, NR-001).
  The lift chain prints 304.6 at one decimal, and the margin recomputes
  1.20815, quoted 1.21.

- Rename census: the retired word reads zero.
  The founder forms read: `lifting bridles` once at section 3.3,
  `Machine winner` twice, `machine winner` once at the marker, and
  `hero` once in the slug.

- Hold senses: the bridle sites read at lines 46, 190 and 863, the
  Sweep 31 set of 46, 190 and 848 plus the fifteen lines the span inserts.

- Top-form census: `topmost ring` reads six times and `topmost rotor ring`
  once.

- Display guards: no loose hit on `14.97`, `3.816` or `27.363`.

- Seat markers: eight, each citing its signed rows.
  The corner marker cites NR-044 and NR-051 only.

- Head status: the head reads "Draft v0.52".
  One `[PENDING]` stub stands, the Nomenclature section.
  The References section carries its text, and the three source calls
  read pending, in step with `references-verification.md` (15 of 18, 3 open).

- Held tokens: `1.94` and `5.18` hold at the section 4.2 sites and the
  failure table, and `3.55` stays flagged in the tracker.
  The section 5 Daisy gate stands.

- Cited commits: the twelve named commits resolve in the tip ancestry,
  and the hex inventory reads 74 entries (was 65 at Sweep 31).

- Freeze re-check: the levers block re-reads byte-identical in the draft
  at `b6cd166`. The draft region and the receipt region carry the same
  bytes. The block md5 reads `7bbd964db09d2b33269ce5cb8c334054`.

- Pins note: all thirty-two appendix cells recompute on the delivered
  bytes. No mismatch reads.
  The corner-machines row takes its EX entry in `pins-check.py` at this
  seat; before the entry the tool walked 28 cells and read the corner
  heading unknown.

- Plate pins: the seated kits re-hash. The ring-utilisation svg reads
  `ce3dee12…`, the twist-limit svg `cc3edf9c…`, the strip svg `6c36b0ff…`,
  the winner svg `0101b58f…` and the corner svg `b2e4055d…`.
  The system-anatomy pair holds (pdf `c55bd7a8…`, png `696be723…`).
  The eval-timeline svg moves to `373c2db3…` with the label re-cut.

- Review copy: the copy holds at its `b6cd166` build. The live md5 reads
  `3c386dc2…` against its archive `draft-b6cd166-20261015-163115.docx`,
  byte-identical, and the draft and register inputs carry zero diff to the
  tip. The record reads 43 cited of 51 signed and eight seats.

- Copy census: the eight media entries hash-match the delivered PNGs, the
  corner plate included.
  The founder forms read in the copy, and the ten block sentences read
  once each.
  The older version marks read zero.

- Eval-timeline note: the re-cut moves nine files, the kit and the map row.
  The plate carries no seat and its slug reads nowhere in the draft, so the
  re-cut touches no draft byte and no copy embed.

- Cascade note: the references leg is ruling-gated (three one-line rulings,
  option A), and the nomenclature leg waits on the Track D ratification.
  The era pack stays open at this seat.

**Finding**

No value discrepancy found.
The span folds the three movers: the kMppt plain pass, the corner-machines
fold and the basics-of-TRPT refresher.
The register holds, and every token accounts.
The founder forms read at their sites, and the hold senses read.
The offender sets hold, and the frozen block and the pins re-check.
One tool gap closed: the pins check takes the corner exhibit row.

**Next run** at the next draft push.

## Sweep 33: v0.64, 2026-10-18

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`de18442` (v0.64, the A-10 to A-19 prose pass), spanning the movers from
`1b01453` (the Sweep 32 span end).
The file carries zero diff to the branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `de18442`, zero diff to the tip.
Moved since Sweep 32 by sixteen landings: the post-fix warm fold, the torsion and convergence set, the 301-split set,
the NR-059 sign and amends, the NR-060 pair, the NR-046 re-pin, the NR-061 sign, display rounds and the NR-062/063 sign.
The numstat reads 689 added and 26 removed, every removed line a
display-amend old string that re-reads by row ID at the tip, no sign-off changed, and the rows now read 63.

**Results**

- Span note: this sweep closes the draft movers since Sweep 32 in one
  pass, keyed at v0.64.
  The span `1b01453..de18442` carries 165 commits.
  The version line reads 52 to 57, then 59 to 64.
  The v0.58 label never printed in the head, and the two folds land in one commit.
  The display pass holds the head at v0.60 without a tick.

- Span landings: the v0.53 to v0.57 set (`89ed222`, `d453530`,
  `2e930a8`, `c9f0560`, `c825a01`), the round-1 fix set
  (`c97a7fd` to `f7de920`), nine commits.
  The v0.58/59 fold (`3321c9a`) and the ring-beam pair (`d360d47`, `646cddf`).
  The v0.60 fold (`ef07533`), the display pass (`5916357`), the six-class fold (`ff60775`) and the figure re-cut (`e7f68a9`).
  The B-20/B-21 land (`3290876`) and the prose pass (`de18442`).

- The candidates file carries four movers, all at this seat: the
  era pack (`1c65d27`), the back-pointer row (`c4bd90d`), the bow row
  and its closed chain (`0d10323`, `ca1b0d1`).
  The stale-phrases list carries none.

- Bracket count: zero.
  The two number-gate brackets closed with the display pass.
  Nine seated markers read, the scaling-ladder embed included.

- STE gate, draft: words 7002 at the span base to 9057 at the tip.
  Totals read 8 through v0.57, 32 from the fix set, 34 from the
  six-class fold, and 20 at v0.64.
  The per100w reads 0.11 to 0.38 to 0.37 to 0.22.
  The em-dash count reads 2 to 0 at `646cddf`, the dashes to colons
  round, and holds at zero.

- STE gate, tracker: words 3177 to 4554, total 12 to 24, per100w
  0.38 to 0.53.
  The additions ride the entries the span itself lands.

- STE gates, candidates and stale-phrases: the candidates read 4733
  to 5329 words at 0.25 to 0.28, the three added offenders the
  four row passes themselves.
  The stale-phrases list reads 623 words at 3.21, flat.

- Offender delta: the five tick pairs through v0.57 read header-only deltas.
  The fix set adds 24 offender lines, all new prose.
  The v0.58/59 fold adds one, and the ring-beam pair rewrites one flagged line in place, count held.
  The display and six-class pair adds one table header and rewrites two flagged lines in place.
  The prose pair removes 13 long_paragraph lines and one contraction, adds none.

- The prose-pass recount: the pass note claimed one accepted
  table-class addition.
  The lint reads zero added offenders.
  The counts read long_paragraph 25 to 12, contraction 2 to 1, every
  other category held, and em dashes zero.

- Token diff, draft, per mover pair: the v0.53 pair reads the tick
  only, 52 out and 53 in.
  The v0.54 pair reads 17 arrival tokens, the 3.3 rows and BEM set, against 53.
  The v0.55 pair matches its note exactly.
  The v0.56 pair reads the tick only, the era pack moved no digit.
  The v0.57 pair matches its note exactly.

- Token diff continued: the fix set reads 76 arrivals against 15
  removals, the FoS correction 15.0 to 14.972 among them.
  The v0.58/59 pair reads 11 arrivals against 3.4 and 57.
  The ring-beam pair reads five arrivals, none removed, and the v0.60 pair reads six against 59.
  The display and six-class pair reads 30 twice and 61, against the k-sweep rows, 29 twice and 3 twice.

- Token diff, closing pairs: the figure pair reads the tick only.
  The B-20/B-21 pair matches its note on every named value.
  The prose pair reads its declared set against 19 removals.

- Token sums: the span raw reads 174 added and 57 removed, net 117.
  The identity check holds: every pair reads net as added minus
  removed.
  The cumulative line reads 149 on the positive side and 32 on the
  negative side.
  Every removal maps to a corrected form or a surviving site.

- Surviving sites, prose-pass removals read 2.03 and 2.69 at
  section 3.4 and the claims table.
  27.364 reads at five sites, and 5.309 at six, 25.698 at five and 13.38 at one.
  1.94 and 5.18 read at the k-sweep row and the ledger rows.
  103 and 1207 drop, file paths.
  4.580 and 0.804 read at section 3.3, and 127.772 survives in the NR-029 row only.

- Value cross-check: every arrival form maps to a signed row.
  The anchors re-read on the twenty-five cited rows, NR-002 through
  NR-063.
  The span removals correct earlier forms, none lost.
  The six-class split reads 93, 37, 36, 30, 3 and 2 against NR-061.
  The bow pair and the steady-and-drifting set read against NR-059.

- Arithmetic: 508 plus 301 plus 110 plus 11 reads 930 (NR-002).
  508 plus 422 reads 930.
  31 times 10 reads 310, and 3 times 310 reads 930 (NR-045).
  The scorecard rows re-anchor on their cited rows.
  The 27.363 note prints its working, 27.36354 rounds to 27.364.

- Span censuses: "campaign winner" reads six times.
  "viable" reads zero.
  "optimum" reads only in the five negations.
  The summary scorecard prints six metric rows plus the header.

- House vocabulary: one site reads "seat checks", the
  scaling-ladder embed, introduced at `ef07533`.
  The reader-facing noun is "the pipeline".
  The replacement goes to the draft owner.
  The "rigid driveshaft" negation reads once, pre-existing at the
  span base, and teaches the opposite.

- Retired phrasing: "adaptive" reads zero and
  "DifferentialEquations" reads zero.
  The stale-phrases list carries no mover.

- Rename census: the bridle forms read at the four ruled sites.
  The founder forms read once each, "lifting bridles" at line 627
  and "Machine winner" at the marker and the map row.
  The topmost forms read nine sites, all consistent with the ruled
  forms.

- Display guards: no loose hit on 14.97 or 3.816.
  The 27.363 form reads at the two rounding-note lines, the
  deliberate pair.

- Head status: the head reads "Draft v0.64".
  One [PENDING] stub stands, the Nomenclature section.
  The References section carries its text after the founder rulings.

- Held tokens: 1.94 and 5.18 print at the merged k-sweep row and
  the two ledger rows, lines 303, 898 and 902.
  The sites shifted with the display pass.
  The tracker flags 3.55 still, at lines 466 and 511.

- Cited commits: twelve real refs resolve in the tip ancestry.
  The scan also reads "feedbac", a word fragment from "feedback",
  an artifact and not a ref.
  The appendix hash block left with the display pass, so the hex
  inventory falls from 74 entries at Sweep 32 to 13 unique forms.

- Freeze re-check: the levers block region breaks at `f7de920`, the T3-7 fix.
  The inactive-slots paragraph enters the region there.
  `646cddf` rewrites the last sentence and the axis labels.
  The prose pass rewraps the region lines.
  The scratch block and the receipt region still match the declared md5, but the draft bytes differ.
  The re-freeze lands in this train with the break commits recorded.

- Pins note: the pins check reads no output-hashes block.
  The display pass replaced the block with the kit-manifest pointer.
  The manifests are the ground truth.
  The tool carries no manifest route yet.

- Plate pins: the ring-utilisation svg reads `38403429…` and the
  twist-limit svg `e58287fe…`, re-cut at `e7f68a9`.
  The strip svg reads `8f54eb9c…`, the winner svg `27746f72…` and
  the corner svg `526cdb1f…`, re-cut at `f696930`.
  The eval-timeline svg holds at `373c2db3…`.
  The system-anatomy pair holds at `c55bd7a8…` and `696be723…`.

- Review copy: the copy holds at its `ef07533` build (v0.60).
  The live md5 reads `53847cd8…`.
  The draft and the register inputs both moved since the stamp, so
  the copy reads stale.

- Review copy, record: the builder holds the rebuild in its queue,
  gated on v0.64, now landed.
  The record the copy prints reads 54 cited of 61 signed and nine
  seats.

- Cascade note: the references leg closed with the founder rulings
  at `55a1a57`.
  The nomenclature leg waits on the Track D ratification.
  The era pack landed at `c9f0560` and `1c65d27`.

**Finding**

No value discrepancy found.
Every token accounts, and the offender sets hold entry for entry.

The frozen levers block re-freezes in this train, per the room call.
The grade holds from the counter-read: wrap-only plus two colon
swaps plus the T3-7 caveat, the signed value set unchanged.
The break commits `f7de920` and `646cddf` record beside the new
md5 `0d9001e4c19c78cc239cc22f8ac6dba7`.
The block file, the receipt region and the draft region all re-read byte-identical at the new bytes.

One house-vocabulary site reads at line 1024.
The draft owner claims the swap, "the seat checks" to "the
pipeline", and it lands after this train.

The review copy reads stale at its v0.60 build, and the rebuild
rides the builder queue.
The six-class split, the bow pair and the B-20/B-21 set all re-anchor
on their signed rows.

**Next run** at the next draft push.

## Sweep 34: v0.65, 2026-10-18

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`a9dc348` (v0.65, the house-vocabulary swap), spanning the movers from
`de18442` (the Sweep 33 span end).
The file carries zero diff to the branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `de18442`.
No movement in the span, the numstat reads empty.

**Results**

- Span note: this pass closes the one draft mover since Sweep 33.
  The span `de18442..7e60f37` carries 13 commits.
  The sweep-33 train itself falls inside the span, seven commits.
  The two validator receipts and the author swap chain ride with it.
  No register, candidates or stale-phrases mover.

- Span landings: the F-VALUE re-check receipt (`c80a443`), the
  counter-read (`11b4cd6`), the sweep-33 train (`c27b677` to
  `79e75df`) and the swap chain (`a9dc348`, `abc12f0`, `7e60f37`).

- Tracker and ledger: the tracker gains its v7 entry and the ledger
  row 29 swaps.
  Both ride `a9dc348`.

- STE gate, draft: words 9057 to 9056, total 20 to 20, per100w 0.22
  to 0.22.
  The removed word is the swap itself.

- STE gate, tracker: words 4554 to 4579, total 24 to 24, per100w
  0.53 to 0.52.

- STE gate, ledger: words 1210 to 1209, total 5 to 5, per100w 0.41.

- Offender delta: the draft set holds entry for entry, empty diff.
  The tracker and the ledger read header-only deltas.

- Token diff, draft: the tick only, 64 out and 65 in.

- Token diff, tracker: one arrival, 65.

- Token diff, ledger: none.

- Identity check: every pair reads net as added minus removed.

- Changed-line census: the draft reads two hunks, the version line
  and line 1024.
  The ledger reads one hunk, row 29.

- Prose-form census: "seat checks" reads zero at the tip draft and
  the tip ledger.
  "the pipeline" reads twice in the draft and once in the ledger.
  The base draft carried one pre-existing site, the expansion-rotor
  sentence, so the counts reconcile.

- Retired phrasing: "adaptive" reads zero and
  "DifferentialEquations" reads zero.
  The stale-phrases list carries no mover.

- Value cross-check: no value form moves on any surface.

- Freeze: the levers region re-reads byte-identical to the
  re-frozen block, md5 `0d9001e4c19c78cc239cc22f8ac6dba7`.

- Cited commits: twelve real refs resolve in the tip ancestry.
  The scan also reads "feedbac", a word fragment, an artifact and
  not a ref.

- Review copy: the copy still reads at its v0.60 build, md5
  `53847cd8`.
  The rebuild holds at the builder, gated on v0.65.
  The scaling-ladder re-stamp rides the swap chain at the figure
  seat, not yet landed at sweep time.

**Finding**

No value discrepancy found.
The swap verifies: one token at each site, the old form zero,
and the declared sets exact.

**Next run** at the next draft push.
