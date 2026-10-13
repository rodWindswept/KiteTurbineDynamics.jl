#!/usr/bin/env python3
"""SV display-ruling check: the FoS report sites and the section 3.3 lift chain.

Read tip 0415d18. Runs from the repo root.
  - Draft census: one token sits beyond 3 dp, the 6 dp chain operand.
  - FoS sites: five row-form sites fold to 15.0; the abstract holds; the
    capture hub read (15.033) stays.
  - Chain arithmetic: the rounded operands and the full value both read
    304.6 at 1 dp; the 2 dp forms disagree.
  - Register anchors and the two new note blocks.
"""
import math
import re

ok = True


def check(name, cond, detail=""):
    global ok
    print(f"[{name}] {'PASS' if cond else 'MISMATCH'} {detail}".rstrip())
    ok = ok and bool(cond)


DRAFT = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
REG = "docs/reporting/numbers-register.md"
TRACK = "docs/reporting/draft-tracker.md"

draft = open(DRAFT, encoding="utf-8").read()
reg = open(REG, encoding="utf-8").read()
track = open(TRACK, encoding="utf-8").read()
lines = draft.split("\n")

# 1. beyond-3dp census
beyond = [(i + 1, m.group(0)) for i, l in enumerate(lines)
          for m in re.finditer(r"\d+\.\d{4,}", l)]
print("beyond-3dp census:", beyond)
check("one token beyond 3 dp", len(beyond) == 1, str(beyond))
check("it is the chain operand", bool(beyond) and beyond[0][1] == "20.698468"
      and "vertical load" in lines[beyond[0][0] - 1])

# 2. FoS sites (content-based, at the read tip)
frags = [
    "Its minimum factor of safety is 14.972 (NR-009)",
    "factor of safety reads\n14.972 (NR-009)",
    "| Minimum factor of safety | 14.972 | NR-009 |",
    "pass, 14.972 minimum",
    "factor of safety 14.972 (NR-008, NR-009)",
]
for i, frag in enumerate(frags, 1):
    check(f"FoS row-form site {i}", frag in draft)
check("abstract holds 15.0", "The minimum factor of safety is 15.0 (NR-009)." in draft)
check("capture hub read stays",
      "capture hub\nring reads 15.033 at the final step (NR-021)" in draft)
check("14.972 count", draft.count("14.972") == 5, str(draft.count("14.972")))

# 3. arithmetic
m = 20.69846825623688
g = 9.81
full = 1.5 * m * g
d3 = 1.5 * 20.698 * g
check("full load", abs(full - 304.5779603905257) < 1e-9, repr(full))
check("displayed-operand load", abs(d3 - 304.57107) < 1e-9, repr(d3))
check("both read 304.6 at 1 dp",
      round(full, 1) == 304.6 and round(d3, 1) == 304.6,
      f"{round(full, 1)} / {round(d3, 1)}")
check("2 dp forms disagree", round(full, 2) != round(d3, 2),
      f"{round(full, 2)} vs {round(d3, 2)}")
check("mass 3 dp", round(m, 3) == 20.698)
fos = 14.971791422208508
check("FoS 1 dp 15.0", round(fos, 1) == 15.0)
check("FoS stored 3 dp 14.972", round(fos, 3) == 14.972)
check("hub read 3 dp 15.033", round(15.032534020684876, 3) == 15.033)
check("tension 1 dp 324.1",
      round(304.5779603905257 / math.sin(math.radians(70)), 1) == 324.1)

# 4. register + tracker anchors
check("NR-009 row", "| NR-009 | Winner FoS (island 3) | 14.972" in reg)
check("NR-018 stored", "25.69846825623688" in reg)
check("NR-037 mass stored", "20.69846825623688" in reg)
check("NR-037 F_vert stored", "304.5779603905257" in reg)
check("tracker call", "the factor of safety prints at 1 dp in the report" in track)

# 5. the two new note blocks
check("update block title",
      "Display-form note update: the minimum FoS at 1 dp, the report sites" in reg)
check("update supersession",
      "replaces the last sentence of the FoS note above" in reg)
check("chain block title",
      "Display-form note: the section 3.3 lift chain (NR-037 on NR-018 and NR-026)" in reg)
check("chain reading rule", "1.5 × 20.698 × 9.81 = 304.6 newtons" in reg)

print("RESULT:", "PASS" if ok else "FAIL")
raise SystemExit(0 if ok else 1)
