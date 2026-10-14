#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""The rows 6 and 7 F-VALUE closure: the check pass (figures seat).

Asserts the closure records in the four edited files, an absence walk
on the stale cell form, and prints the declared digit-token diff for
the push.

Run: /usr/bin/python3 scratch/fig_r67_check.py
Writes: scratch/fig_r67_check.log
"""
import re
import subprocess
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
FILES = [
    "docs/reporting/figures/figure-map.md",
    "docs/reporting/figures/ring-utilisation/SPEC.md",
    "docs/reporting/figures/twist-limit/SPEC.md",
    "handovers/handover-2026-10-14-reporting-room-figures-images-diagrams.md",
]

fails, lines = [], []


def check(name, ok):
    lines.append("check: %s: %s" % (name, "OK" if ok else "FAIL"))
    if not ok:
        fails.append(name)


texts = {f: (REPO / f).read_text() for f in FILES}
m = texts[FILES[0]]
r = texts[FILES[1]]
w = texts[FILES[2]]
h = texts[FILES[3]]

# 1. The map cells.
check("map closure in row 6 cell",
      "corrected interaction form). The re-census at `c30b2ca` closes F-VALUE on the fix commit (`ef36c6c`) with zero defects. Next: the visual pass by Rod |" in m)
check("map closure in row 7 cell",
      "the binding-limit title). The re-census at `c30b2ca` closes F-VALUE on the fix commit (`ef36c6c`) with zero defects. Next: the visual pass by Rod |" in m)
check("stale cell form gone", "Next: F-VALUE at the sign-off commit |" not in m)
check("map delta v31", "**v31 (2026-10-14):**" in m)

# 2. The kit rounds lines.
CLOS = "The re-census at `c30b2ca` closes F-VALUE on the fix\n  commit (`ef36c6c`) with zero defects."
check("ring rounds closure", CLOS in r)
check("twist rounds closure", CLOS in w)
check("ring counter-read history", "The counter-read at `a3f4ae3` held the drawn values and routed the" in r)
check("twist counter-read history", "The counter-read at `a3f4ae3` held the drawn values and routed the" in w)
check("ring delta v6", "- v6 (2026-10-14): the F-VALUE closure." in r)
check("twist delta v5", "- v5 (2026-10-14): the F-VALUE closure." in w)

# 3. The handover refresh.
check("handover closed entry", "The Harris-3.5 thread closes on rows 6 and 7: the re-census (`c30b2ca`)" in h)
check("handover open item 1 renumbered", "1. **The item-5 lever-statistics extract.**" in h)
check("handover open item 2 renumbered", "2. **The ring lead flag.**" in h)
check("old open item numbering gone", "3. **The ring lead flag.**" not in h)
check("handover next action refreshed", "item-5 lever-statistics extract." in h and "Fold the map closure" not in h)

# 4. The digit-token diff, declared.
def digit_tokens(s):
    out = []
    for line in s.splitlines():
        for raw in line.split():
            tok = raw.strip("`|*:;,.()[]{}<>#…·—–")
            if tok and any(ch.isdigit() for ch in tok):
                out.append(tok)
    return Counter(out)


def git_blob(rel):
    p = subprocess.run(["git", "-C", str(REPO), "show", "HEAD:%s" % rel],
                       capture_output=True)
    assert p.returncode == 0, "git show failed for %s" % rel
    return p.stdout.decode()


for rel in FILES:
    old = digit_tokens(git_blob(rel))
    new = digit_tokens(texts[rel])
    added = {k: v for k, v in (new - old).items() if v}
    removed = {k: v for k, v in (old - new).items() if v}
    lines.append("== token diff %s: +%d, -%d" % (rel, sum(added.values()), sum(removed.values())))
    for tok, n in sorted(added.items()):
        lines.append("   +%dx %s" % (n, tok))
    for tok, n in sorted(removed.items()):
        lines.append("   -%dx %s" % (n, tok))

lines.append("== summary: " + ("%d FAIL: %s" % (len(fails), fails) if fails else "all OK"))
log = "\n".join(lines) + "\n"
(REPO / "scratch/fig_r67_check.log").write_text(log)
print(log)
raise SystemExit(1 if fails else 0)
