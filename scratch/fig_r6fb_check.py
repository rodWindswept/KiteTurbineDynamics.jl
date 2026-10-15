#!/usr/bin/env python3
"""fig r6 fold-back check: reads back the map fold-back, delta v38, the
two kit form notes, the held comment sites, and the seat page.

Run: /usr/bin/python3 scratch/fig_r6fb_check.py    (repo root)
"""
import sys
from pathlib import Path

MAP = Path("docs/reporting/figures/figure-map.md")
ET = Path("docs/reporting/figures/eval-timeline/register-status.md")
HERO = Path("docs/reporting/figures/machine-winner-hero/register-status.md")
SEAT = Path("handovers/handover-2026-10-14-reporting-room-figures-images-diagrams.md")
ET_PY = Path("docs/reporting/figures/eval-timeline/eval-timeline.py")
HERO_JL = Path("docs/reporting/figures/machine-winner-hero/machine-winner-hero.jl")
RECEIPT = Path("docs/reporting/room-responses/"
               "figures-images-diagrams-2026-10-15-round6-counterread-foldback-and-corner-open.md")
EXTRACT = Path("docs/reporting/figures/machine-corner-grid/extract-corner-grid.csv")

n = 0
fails = []


def chk(name, good):
    global n
    n += 1
    if not good:
        fails.append(name)
    print(f"  {'OK ' if good else 'FAIL'}  {name}")


mt = MAP.read_text()

# 1. the five re-cut rows take the closure
chk("map: the closure phrase reads 5 times", mt.count("closes clean (`3038656`, 136 checks)") == 5)
chk("map: no row still reads the aero counter-read next-gate",
    mt.count("Next: the aero counter-read") == 0)
chk("map: row 23 records the extract mint",
    "the extract mints (four genomes byte-exact, NR-051-gated; `extract-corner-grid.csv`)" in mt)
chk("map: delta v38 present", "- **v38 (2026-10-15):**" in mt)
chk("map: delta v37 still present", "- **v37 (2026-10-14):**" in mt)
chk("map: v38 holds the five-row closure sentence",
    "The five re-cut rows (2, 4, 6, 7 and 10) take the" in mt)
chk("map: v38 records the form-note hold", "form notes hold" in mt)
chk("map: v38 records the corner open", "The corner grid opens (row 23)" in mt)

# 2. the kit form notes
et = ET.read_text()
chk("et note: form note present", "**Form note** (2026-10-15): one script comment at the head holds" in et)
chk("et note: no-drawn-text line", "the old ring name until the next re-render sweep. No drawn text is\naffected." in et)
hero = HERO.read_text()
chk("hero note: form note present", "**Form note** (2026-10-15): four script comments hold the old ring" in hero)
chk("hero note: no-drawn-text line", "the old ring\nname until the next re-render sweep. No drawn text is affected." in hero)

# 3. the held sites still read (the hold, not a sweep)
etpy = ET_PY.read_text()
chk("et hold site reads", "ground ring and hub ring (cold extract)" in etpy)
hjl = HERO_JL.read_text()
chk("hero hold site 1 reads", "the hub leads the ground ring" in hjl)
chk("hero hold site 2 reads", "about the hub centre" in hjl)
chk("hero hold site 3 reads", "hub ring R6" in hjl)
chk("hero hold site 4 reads", "the hub, so it takes its own centred y window" in hjl)
chk("the five hold sites count exactly", sum([
    "ground ring and hub ring (cold extract)" in etpy,
    "the hub leads the ground ring" in hjl,
    "about the hub centre" in hjl,
    "hub ring R6" in hjl,
    "the hub, so it takes its own centred y window" in hjl]) == 5)

# 4. the seat page
sp = SEAT.read_text()
chk("seat: header refresh line", "the round-6 counter-read fold-back and the corner-grid opening (2026-10-15)" in sp)
chk("seat: corner item reads the pinned extract",
    "The extract pins at `docs/reporting/figures/machine-corner-grid/extract-corner-grid.csv`" in sp)
chk("seat: visual pass item", "The five re-cut rows (2, 4, 6, 7 and 10) and the k-basis plate (row 5)" in sp)
chk("seat: closure in the closed index",
    "The round-6 counter-read closes clean at the aero desk (2026-10-15): 136 checks, 0 fail, `9b414f3..0739ee7`" in sp)
chk("seat: corner open in the closed index", "The corner grid opens (2026-10-15): the extract mints" in sp)
chk("seat: next action line", "**Next action:** the corner-grid generator build (row 23) on the pinned extract." in sp)

# 5. the receipt and the extract exist
chk("receipt exists", RECEIPT.exists())
chk("extract exists", EXTRACT.exists())
if RECEIPT.exists():
    rt = RECEIPT.read_text()
    chk("receipt carries the closure commit", "3038656" in rt)
    chk("receipt carries the extract name", "extract-corner-grid.csv" in rt)
if EXTRACT.exists():
    xt = EXTRACT.read_text()
    chk("extract carries four data rows",
        len([ln for ln in xt.splitlines() if ln and not ln.startswith("#")]) == 5)

print(f"\nchecks: {n}, fail: {len(fails)}")
for f in fails:
    print("FAILED:", f)
sys.exit(0 if not fails else 1)
