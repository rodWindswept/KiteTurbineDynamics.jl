#!/usr/bin/env python3
"""scratch/sv_f3_census_check.py — science-validator, 2026-10-13.

Re-derive the "no unrowed numeral remains" claim for the eval-timeline plate
after NR-042. Reads the committed SVG text (the drawn set) and gates every
numeric token against an explicit coverage map. Read-only.

Coverage map (drawn readout -> signed row):
  10.17, 13.38        -> NR-016, NR-029
  5.309, 5.314, 5     -> NR-008; NR-027 / NR-039 (the kW floor)
  1.448, 2.841, 5.798 -> NR-013 ext
  1.5                 -> NR-042 (the ">= 1.5 m" gate string; the strain-axis
                         tick at 1.5 is scale)
  10 (t > 10 s)       -> NR-015 (relax length; the time-axis tick is scale)
Scale / non-readout allowlist:
  0, 0.5, 1.0, 1.5(tick), 2, 3, 4, 6, 9, 11, 13, 15, 20, 30, 40, 50 (ticks)
  12 ("first 12 ms" inset extent), 100 ("100 Hz" rate caption)
  NR-suffix tokens in the footer row list: 008 012 013 016 027 029 039
"""
import re
import sys
import html
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SVG = ROOT / "docs/reporting/figures/eval-timeline/eval-timeline.svg"
LEDGER = ROOT / "docs/reporting/figures/eval-timeline/label-ledger.txt"
NOTE = ROOT / "docs/reporting/figures/eval-timeline/register-status.md"

fails = []


def check(name, ok, detail=""):
    print(f"  {'OK ' if ok else 'FAIL'} {name}{' — ' + detail if detail else ''}")
    if not ok:
        fails.append(name)


svg = SVG.read_text()
texts = [html.unescape(re.sub(r"<[^>]+>", "", t)).strip()
         for t in re.findall(r"<text[^>]*>(.*?)</text>", svg, flags=re.S)]

TOK = re.compile(r"(?<![\w.])(\d+(?:\.\d+)?)(?![\w-])")
ctx = {}
for t in texts:
    for m in TOK.finditer(t):
        ctx.setdefault(m.group(1), []).append(t)

COVERED = {"10.17", "13.38", "5.309", "5.314", "5",
           "1.448", "2.841", "5.798", "1.5", "10"}
SCALE = {"0", "0.5", "1.0", "2", "3", "4", "6", "9", "11", "13", "15",
         "20", "30", "40", "50", "12", "100"}
FOOTER = {"008", "012", "013", "016", "027", "029", "039"}

print("== drawn numeric tokens and coverage ==")
uncovered = []
for tok in sorted(ctx, key=lambda s: float(s)):
    where = ctx[tok]
    tag = ("covered" if tok in COVERED else
           "scale/provenance" if tok in SCALE or tok in FOOTER else "UNCOVERED")
    if tag == "UNCOVERED":
        uncovered.append(tok)
    print(f"  {tok:>6}  x{len(where):<2} {tag:<17} | {' ;; '.join(where)[:120]}")
check("every drawn token is covered or scale/provenance", not uncovered,
      f"uncovered: {uncovered}")

print("== context assertions ==")
check("1.5 in the gate string", any("1.5 m" in t for t in ctx.get("1.5", [])))
check("10 in the t > 10 s placement", any("t > 10 s" in t for t in ctx.get("10", [])))
check("5 in the kW floor label", any("5 kW floor" in t for t in ctx.get("5", [])))
check("2.841 in the warm-break line", any("2.841 ms" in t for t in ctx.get("2.841", [])))
check("1.448 and 5.798 in the ruling line",
      all(any(s in t for t in ctx.get("1.448", [])) for s in ["1.448"]) and
      any("5.798 ms" in t for t in ctx.get("5.798", [])))

print("== footer row list (boundary) ==")
footer = [t for t in texts if t.startswith("rows NR-008")]
check("footer drawn", bool(footer))
if footer:
    print("  footer:", footer[0])
    check("footer carries NR-039", "NR-039" in footer[0])
    check("footer does not yet carry NR-042 (expected)", "NR-042" not in footer[0])

print("== ledger and note ==")
led = LEDGER.read_text().splitlines()
check("ledger line 52 is the gate string", led[51] == "≥ 1.5 m, read once", repr(led[51]))
note = NOTE.read_text()
check("note cites NR-042", "NR-042" in note)
check("note keeps the closure sentence", "No unrowed numeral remains on the plate" in note)

if fails:
    print("\nFAILURES:", fails)
    sys.exit(1)
print("\nSV_F3_CENSUS_OK")
