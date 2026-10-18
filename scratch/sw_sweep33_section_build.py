#!/usr/bin/env python3
# Sweep 33 section builder — science-writer, 2026-10-18.
# Builds scratch/sw_sweep33_section.md with per-line word asserts (<=20,
# code-stripped, decimals as two tokens) and per-block fragment asserts (<=6),
# using the linter's own functions.
import importlib.util, pathlib
spec = importlib.util.spec_from_file_location('stelint', 'ste-lint.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
wc = m.wc; strip = m.strip_code; sentences = m.sentences

blocks = []
def B(*lines):
    blocks.append(list(lines))

B("## Sweep 33: v0.64, 2026-10-18")

B("**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at",
  "`de18442` (v0.64, the A-10 to A-19 prose pass), spanning the movers from",
  "`1b01453` (the Sweep 32 span end).",
  "The file carries zero diff to the branch tip at sweep time.")

B("**Register** `docs/reporting/numbers-register.md` at `de18442`, zero diff to the tip.",
  "Moved since Sweep 32 by sixteen landings: the post-fix warm fold, the torsion and convergence set, the 301-split set,",
  "the NR-059 sign and amends, the NR-060 pair, the NR-046 re-pin, the NR-061 sign, display rounds and the NR-062/063 sign.",
  "The numstat reads 689 added and 26 removed, every removed line a",
  "display-amend old string that re-reads by row ID at the tip, no sign-off changed, and the rows now read 63.")

B("**Results**")

B("- Span note: this sweep closes the draft movers since Sweep 32 in one",
  "  pass, keyed at v0.64.",
  "  The span `1b01453..de18442` carries 165 commits.",
  "  The version line reads 52 to 57, then 59 to 64.",
  "  The v0.58 label never printed in the head, and the two folds land in one commit.",
  "  The display pass holds the head at v0.60 without a tick.")

B("- Span landings: the v0.53 to v0.57 set (`89ed222`, `d453530`,",
  "  `2e930a8`, `c9f0560`, `c825a01`), the round-1 fix set",
  "  (`c97a7fd` to `f7de920`), nine commits.",
  "  The v0.58/59 fold (`3321c9a`) and the ring-beam pair (`d360d47`, `646cddf`).",
  "  The v0.60 fold (`ef07533`), the display pass (`5916357`), the six-class fold (`ff60775`) and the figure re-cut (`e7f68a9`).",
  "  The B-20/B-21 land (`3290876`) and the prose pass (`de18442`).")

B("- The candidates file carries four movers, all at this seat: the",
  "  era pack (`1c65d27`), the back-pointer row (`c4bd90d`), the bow row",
  "  and its closed chain (`0d10323`, `ca1b0d1`).",
  "  The stale-phrases list carries none.")

B("- Bracket count: zero.",
  "  The two number-gate brackets closed with the display pass.",
  "  Nine seated markers read, the scaling-ladder embed included.")

B("- STE gate, draft: words 7002 at the span base to 9057 at the tip.",
  "  Totals read 8 through v0.57, 32 from the fix set, 34 from the",
  "  six-class fold, and 20 at v0.64.",
  "  The per100w reads 0.11 to 0.38 to 0.37 to 0.22.",
  "  The em-dash count reads 2 to 0 at `646cddf`, the dashes to colons",
  "  round, and holds at zero.")

B("- STE gate, tracker: words 3177 to 4554, total 12 to 24, per100w",
  "  0.38 to 0.53.",
  "  The additions ride the entries the span itself lands.")

B("- STE gates, candidates and stale-phrases: the candidates read 4733",
  "  to 5329 words at 0.25 to 0.28, the three added offenders the",
  "  four row passes themselves.",
  "  The stale-phrases list reads 623 words at 3.21, flat.")

B("- Offender delta: the five tick pairs through v0.57 read header-only deltas.",
  "  The fix set adds 24 offender lines, all new prose.",
  "  The v0.58/59 fold adds one, and the ring-beam pair rewrites one flagged line in place, count held.",
  "  The display and six-class pair adds one table header and rewrites two flagged lines in place.",
  "  The prose pair removes 13 long_paragraph lines and one contraction, adds none.")

B("- The prose-pass recount: the pass note claimed one accepted",
  "  table-class addition.",
  "  The lint reads zero added offenders.",
  "  The counts read long_paragraph 25 to 12, contraction 2 to 1, every",
  "  other category held, and em dashes zero.")

B("- Token diff, draft, per mover pair: the v0.53 pair reads the tick",
  "  only, 52 out and 53 in.",
  "  The v0.54 pair reads 17 arrival tokens, the 3.3 rows and BEM set, against 53.",
  "  The v0.55 pair matches its note exactly.",
  "  The v0.56 pair reads the tick only, the era pack moved no digit.",
  "  The v0.57 pair matches its note exactly.")

B("- Token diff continued: the fix set reads 76 arrivals against 15",
  "  removals, the FoS correction 15.0 to 14.972 among them.",
  "  The v0.58/59 pair reads 11 arrivals against 3.4 and 57.",
  "  The ring-beam pair reads five arrivals, none removed, and the v0.60 pair reads six against 59.",
  "  The display and six-class pair reads 30 twice and 61, against the k-sweep rows, 29 twice and 3 twice.")

B("- Token diff, closing pairs: the figure pair reads the tick only.",
  "  The B-20/B-21 pair matches its note on every named value.",
  "  The prose pair reads its declared set against 19 removals.")

B("- Token sums: the span raw reads 174 added and 57 removed, net 117.",
  "  The identity check holds: every pair reads net as added minus",
  "  removed.",
  "  The cumulative line reads 149 on the positive side and 32 on the",
  "  negative side.",
  "  Every removal maps to a corrected form or a surviving site.")

B("- Surviving sites, prose-pass removals read 2.03 and 2.69 at",
  "  section 3.4 and the claims table.",
  "  27.364 reads at five sites, and 5.309 at six, 25.698 at five and 13.38 at one.",
  "  1.94 and 5.18 read at the k-sweep row and the ledger rows.",
  "  103 and 1207 drop, file paths.",
  "  4.580 and 0.804 read at section 3.3, and 127.772 survives in the NR-029 row only.")

B("- Value cross-check: every arrival form maps to a signed row.",
  "  The anchors re-read on the twenty-five cited rows, NR-002 through",
  "  NR-063.",
  "  The span removals correct earlier forms, none lost.",
  "  The six-class split reads 93, 37, 36, 30, 3 and 2 against NR-061.",
  "  The bow pair and the steady-and-drifting set read against NR-059.")

B("- Arithmetic: 508 plus 301 plus 110 plus 11 reads 930 (NR-002).",
  "  508 plus 422 reads 930.",
  "  31 times 10 reads 310, and 3 times 310 reads 930 (NR-045).",
  "  The scorecard rows re-anchor on their cited rows.",
  "  The 27.363 note prints its working, 27.36354 rounds to 27.364.")

B("- Span censuses: \"campaign winner\" reads six times.",
  "  \"viable\" reads zero.",
  "  \"optimum\" reads only in the five negations.",
  "  The summary scorecard prints six metric rows plus the header.")

B("- House vocabulary: one site reads \"seat checks\", the",
  "  scaling-ladder embed, introduced at `ef07533`.",
  "  The reader-facing noun is \"the pipeline\".",
  "  The replacement goes to the draft owner.",
  "  The \"rigid driveshaft\" negation reads once, pre-existing at the",
  "  span base, and teaches the opposite.")

B("- Retired phrasing: \"adaptive\" reads zero and",
  "  \"DifferentialEquations\" reads zero.",
  "  The stale-phrases list carries no mover.")

B("- Rename census: the bridle forms read at the four ruled sites.",
  "  The founder forms read once each, \"lifting bridles\" at line 627",
  "  and \"Machine winner\" at the marker and the map row.",
  "  The topmost forms read nine sites, all consistent with the ruled",
  "  forms.")

B("- Display guards: no loose hit on 14.97 or 3.816.",
  "  The 27.363 form reads at the two rounding-note lines, the",
  "  deliberate pair.")

B("- Head status: the head reads \"Draft v0.64\".",
  "  One [PENDING] stub stands, the Nomenclature section.",
  "  The References section carries its text after the founder rulings.")

B("- Held tokens: 1.94 and 5.18 print at the merged k-sweep row and",
  "  the two ledger rows, lines 303, 898 and 902.",
  "  The sites shifted with the display pass.",
  "  The tracker flags 3.55 still, at lines 466 and 511.")

B("- Cited commits: twelve real refs resolve in the tip ancestry.",
  "  The scan also reads \"feedbac\", a word fragment from \"feedback\",",
  "  an artifact and not a ref.",
  "  The appendix hash block left with the display pass, so the hex",
  "  inventory falls from 74 entries at Sweep 32 to 13 unique forms.")

B("- Freeze re-check: the levers block region breaks at `f7de920`, the T3-7 fix.",
  "  The inactive-slots paragraph enters the region there.",
  "  `646cddf` rewrites the last sentence and the axis labels.",
  "  The prose pass rewraps the region lines.",
  "  The scratch block and the receipt region still match the declared md5, but the draft bytes differ.",
  "  The re-freeze lands in this train with the break commits recorded.")

B("- Pins note: the pins check reads no output-hashes block.",
  "  The display pass replaced the block with the kit-manifest pointer.",
  "  The manifests are the ground truth.",
  "  The tool carries no manifest route yet.")

B("- Plate pins: the ring-utilisation svg reads `38403429…` and the",
  "  twist-limit svg `e58287fe…`, re-cut at `e7f68a9`.",
  "  The strip svg reads `8f54eb9c…`, the winner svg `27746f72…` and",
  "  the corner svg `526cdb1f…`, re-cut at `f696930`.",
  "  The eval-timeline svg holds at `373c2db3…`.",
  "  The system-anatomy pair holds at `c55bd7a8…` and `696be723…`.")

B("- Review copy: the copy holds at its `ef07533` build (v0.60).",
  "  The live md5 reads `53847cd8…`.",
  "  The draft and the register inputs both moved since the stamp, so",
  "  the copy reads stale.")

B("- Review copy, record: the builder holds the rebuild in its queue,",
  "  gated on v0.64, now landed.",
  "  The record the copy prints reads 54 cited of 61 signed and nine",
  "  seats.")

B("- Cascade note: the references leg closed with the founder rulings",
  "  at `55a1a57`.",
  "  The nomenclature leg waits on the Track D ratification.",
  "  The era pack landed at `c9f0560` and `1c65d27`.")

B("**Finding**")

B("No value discrepancy found.",
  "Every token accounts, and the offender sets hold entry for entry.")

B("The frozen levers block re-freezes in this train, per the room call.",
  "The grade holds from the counter-read: wrap-only plus two colon",
  "swaps plus the T3-7 caveat, the signed value set unchanged.",
  "The break commits `f7de920` and `646cddf` record beside the new",
  "md5 `0d9001e4c19c78cc239cc22f8ac6dba7`.",
  "The block file, the receipt region and the draft region all re-read byte-identical at the new bytes.")

B("One house-vocabulary site reads at line 1024.",
  "The draft owner claims the swap, \"the seat checks\" to \"the",
  "pipeline\", and it lands after this train.")

B("The review copy reads stale at its v0.60 build, and the rebuild",
  "rides the builder queue.",
  "The six-class split, the bow pair and the B-20/B-21 set all re-anchor",
  "on their signed rows.")

B("**Next run** at the next draft push.")

# assert gates
fails = 0
for bi, block in enumerate(blocks):
    for line in block:
        w = wc(strip(line))
        if w > 20:
            print(f'LONG line block {bi}: {w}w :: {line[:80]}'); fails += 1
    frags = sentences(strip('\n'.join(block)))
    if len(frags) > 6:
        print(f'DENSE block {bi}: {len(frags)} fragments :: {block[0][:60]}'); fails += 1

if fails:
    raise SystemExit(f'{fails} gate failures — not written')
path = pathlib.Path('scratch/sw_sweep33_section.md')
path.write_text('\n\n'.join('\n'.join(b) for b in blocks) + '\n')
print('written OK,', len(blocks), 'blocks')
