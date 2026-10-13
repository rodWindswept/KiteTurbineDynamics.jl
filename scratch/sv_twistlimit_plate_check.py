#!/usr/bin/env python3
"""scratch/sv_twistlimit_plate_check.py — science-validator, 2026-10-13.

The plate-vs-row read for the twist-limit close-out (the user ask of
2026-10-13: the 98.9 delta_crit double check). Reads the committed SVG
text (the drawn set), gates every drawn readout against its row, and
flags the mechanism tokens that still carry no register rows. Read-only.
"""
import html
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SVG = ROOT / "docs/reporting/figures/twist-limit/twist-limit.svg"
LEDGER = ROOT / "docs/reporting/figures/twist-limit/label-ledger.txt"
REG = ROOT / "docs/reporting/numbers-register.md"
EX = ROOT / "docs/reporting/figures/pair-extract/extract-winner-operating-point.csv"

fails = []


def check(name, ok_, detail=""):
    print(f"  {'OK ' if ok_ else 'FAIL'} {name}" + (f" — {detail}" if detail else ""))
    if not ok_:
        fails.append(name)


# the committed extract: the row's own source values
seg = {}
for line in EX.read_text().splitlines():
    if line.startswith("segment,"):
        f = line.split(",")
        seg[f[1]] = dict(r_a=float(f[3]), r_b=float(f[4]), l_t=float(f[5]),
                         dcrit=float(f[7]), dalpha=float(f[8]),
                         tau=float(f[10]), cap=float(f[11]))

svg = SVG.read_text()
texts = [html.unescape(re.sub(r"<[^>]+>", "", t)).strip()
         for t in re.findall(r"<text[^>]*>(.*?)</text>", svg, flags=re.S)]
texts = [t for t in texts if t]
print(f"drawn text strings: {len(texts)}")
joined = " | ".join(texts)

drawn = set()
for t in texts:
    for m in re.finditer(r"(?<![\w.])(\d+\.\d+|\d+)(?![\w-])", t):
        drawn.add(m.group(1))

print("== drawn readouts vs the rows (0.1 deg / 0.1 N.m drawn forms) ==")
for sid in ("S1", "S2", "S3", "S4", "S5"):
    s = seg[sid]
    for what, v in (("dcrit", s["dcrit"]), ("abs_dalpha", s["dalpha"]),
                    ("tau", s["tau"]), ("cap", s["cap"])):
        form = f"{v:.1f}"
        check(f"{sid} {what} drawn {form}", form in " ".join(texts) or form in drawn)
print("  drawn dcrit tokens:", sorted(t for t in drawn if t.startswith("9"))[:8])
print("  drawn token count:", len(drawn))

reg = REG.read_text()
print("== register anchors (NR-022, NR-023) ==")
for s in ["98.85908296054023", "92.64281134151318", "33.94561934829036",
          "33.811870056223555", "33.67952027817454", "33.54707806507812",
          "22.821871326820364"]:
    check(f"NR-022 carries {s[:16]}", s in reg)
for s in ["396.791634149159", "805.0097155967861", "1069.9324759682652"]:
    check(f"register carries {s[:16]}", s in reg)

print("== mechanism tokens (rows pending — flagged, not actioned) ==")
for tok, label in [("72.25", "realisability floor"), ("42.6", "crossing-limit example"),
                   ("22,425", "2026-08-13 overshoot"), ("62", "revolutions"),
                   ("1.05", "geometry factor")]:
    drawn_here = any(tok in t for t in texts)
    rowed = tok in reg
    print(f"  {tok:>7}  drawn={drawn_here}  rowed={rowed}  ({label})")
check("72.25 drawn and unrowed", any("72.25" in t for t in texts) and "72.25" not in reg)
check("42.6 drawn and unrowed", any("42.6" in t for t in texts) and "42.6" not in reg)
check("22,425 drawn and unrowed",
      any("22,425" in t for t in texts) and "22,425" not in reg and "22425" not in reg)

print("== ledger equality ==")
led = [l for l in LEDGER.read_text().splitlines() if l.strip()]
print(f"ledger strings: {len(led)}")
notin = [t for t in texts if t not in led]
check("every drawn string equals a ledger entry", not notin, str(notin[:6]))

print("== full numeric census ==")
SCALE = {"0", "20", "40", "60", "80", "100", "200", "400", "600", "800", "1000"}
STAMP = {"1724859", "49.99999483862295"}
FOOTER = {"022", "023", "073", "013"}   # row ids and the date tail
MECH = {"72.25", "42.6", "62", "1.05", "90"}
if "22,425" in joined:
    MECH |= {"22", "425"}
uncovered = []
for tok in sorted(drawn, key=lambda s: float(s)):
    if tok in SCALE or tok in STAMP or tok in FOOTER or tok in MECH:
        continue
    if re.fullmatch(r"\d+\.\d", tok) and any(tok == f"{v:.1f}" for s in seg.values()
                                             for v in (s["dcrit"], s["dalpha"], s["tau"], s["cap"])):
        continue
    if tok in ("13", "5", "1", "6", "3"):
        continue  # label tails: island-3, the date, S1-S5 / R1-R6
    uncovered.append(tok)
check("every drawn token is rowed, scale, stamp or flagged mechanism", not uncovered,
      str(uncovered))
for tok in uncovered:
    ctxs = [t for t in texts if re.search(r"(?<![\w.])" + re.escape(tok) + r"(?![\w-])", t)]
    print(f"  uncovered {tok}: {ctxs[:3]}")
check("delta_crit pair present", "98.9" in drawn and "92.6" in drawn)

if fails:
    print("\nFAILURES:", fails)
    sys.exit(1)
print("\nSV_TWISTLIMIT_CENSUS_OK")
