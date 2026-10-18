#!/usr/bin/env python3
# Sweep 34 section builder — science-writer, 2026-10-18.
# Builds scratch/sw_sweep34_section.md with per-line word asserts (<=20,
# code-stripped, decimals as two tokens) and per-block fragment asserts (<=6),
# using the linter's own functions.
import importlib.util, pathlib
spec = importlib.util.spec_from_file_location('stelint', 'ste-lint.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
wc = m.wc; strip = m.strip_code; sentences = m.sentences

blocks = []
def B(*lines):
    blocks.append(list(lines))

B("## Sweep 34: v0.65, 2026-10-18")

B("**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at",
  "`a9dc348` (v0.65, the house-vocabulary swap), spanning the movers from",
  "`de18442` (the Sweep 33 span end).",
  "The file carries zero diff to the branch tip at sweep time.")

B("**Register** `docs/reporting/numbers-register.md` at `de18442`.",
  "No movement in the span, the numstat reads empty.")

B("**Results**")

B("- Span note: this pass closes the one draft mover since Sweep 33.",
  "  The span `de18442..7e60f37` carries 13 commits.",
  "  The sweep-33 train itself falls inside the span, seven commits.",
  "  The two validator receipts and the author swap chain ride with it.",
  "  No register, candidates or stale-phrases mover.")

B("- Span landings: the F-VALUE re-check receipt (`c80a443`), the",
  "  counter-read (`11b4cd6`), the sweep-33 train (`c27b677` to",
  "  `79e75df`) and the swap chain (`a9dc348`, `abc12f0`, `7e60f37`).")

B("- Tracker and ledger: the tracker gains its v7 entry and the ledger",
  "  row 29 swaps.",
  "  Both ride `a9dc348`.")

B("- STE gate, draft: words 9057 to 9056, total 20 to 20, per100w 0.22",
  "  to 0.22.",
  "  The removed word is the swap itself.")

B("- STE gate, tracker: words 4554 to 4579, total 24 to 24, per100w",
  "  0.53 to 0.52.")

B("- STE gate, ledger: words 1210 to 1209, total 5 to 5, per100w 0.41.")

B("- Offender delta: the draft set holds entry for entry, empty diff.",
  "  The tracker and the ledger read header-only deltas.")

B("- Token diff, draft: the tick only, 64 out and 65 in.")

B("- Token diff, tracker: one arrival, 65.")

B("- Token diff, ledger: none.")

B("- Identity check: every pair reads net as added minus removed.")

B("- Changed-line census: the draft reads two hunks, the version line",
  "  and line 1024.",
  "  The ledger reads one hunk, row 29.")

B("- Prose-form census: \"seat checks\" reads zero at the tip draft and",
  "  the tip ledger.",
  "  \"the pipeline\" reads twice in the draft and once in the ledger.",
  "  The base draft carried one pre-existing site, the expansion-rotor",
  "  sentence, so the counts reconcile.")

B("- Retired phrasing: \"adaptive\" reads zero and",
  "  \"DifferentialEquations\" reads zero.",
  "  The stale-phrases list carries no mover.")

B("- Value cross-check: no value form moves on any surface.")

B("- Freeze: the levers region re-reads byte-identical to the",
  "  re-frozen block, md5 `0d9001e4c19c78cc239cc22f8ac6dba7`.")

B("- Cited commits: twelve real refs resolve in the tip ancestry.",
  "  The scan also reads \"feedbac\", a word fragment, an artifact and",
  "  not a ref.")

B("- Review copy: the copy still reads at its v0.60 build, md5",
  "  `53847cd8`.",
  "  The rebuild holds at the builder, gated on v0.65.",
  "  The scaling-ladder re-stamp rides the swap chain at the figure",
  "  seat, not yet landed at sweep time.")

B("**Finding**")

B("No value discrepancy found.",
  "The swap verifies: one token at each site, the old form zero,",
  "and the declared sets exact.")

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
path = pathlib.Path('scratch/sw_sweep34_section.md')
path.write_text('\n\n'.join('\n'.join(b) for b in blocks) + '\n')
print('written OK,', len(blocks), 'blocks')
