#!/usr/bin/env python3
"""Rebuild check: the v0.57 review copy (author seat, 2026-10-16).

Read-only. Re-checks the delivered DOCX against the landing facts: the
build record, the live/stamped parity, the media count, the bow-block
phrase set, the pins and the held forms. Exit rc=0 only when every
check passes.
"""

import hashlib
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "scratch/report-pdf-build"
LIVE = OUT / "draft-live.docx"
ARCHIVE = OUT / "draft-c825a01-20261016-132638.docx"
DRAFT = ROOT / "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER = ROOT / "docs/reporting/draft-tracker.md"

fails = []
total = 0


def check(name, ok, detail=""):
    global total
    total += 1
    line = f"{'PASS' if ok else 'FAIL'} {name}"
    if detail:
        line += f"  [{detail}]"
    print(line)
    if not ok:
        fails.append(name)


record = (OUT / "build-record-docx.txt").read_text()
check("record: draft c825a01", "Draft: `c825a01`" in record)
check("record: register at 7aaf2ea", "file at `7aaf2ea`" in record)
check("record: 8 of 8 seats", "Seats resolved: 8 of 8" in record)
check(
    "record: 53 cited, every one signed (59 total), checker exit 0",
    "53 cited, every one signed (59 signed rows total)" in record
    and "checker exit 0" in record,
)
check("record: built 2026-10-16T13:26:38Z", "Built: 2026-10-16T13:26:38Z" in record)

md5_live = hashlib.md5(LIVE.read_bytes()).hexdigest()
md5_arch = hashlib.md5(ARCHIVE.read_bytes()).hexdigest()
check("md5 parity live == archived build", md5_live == md5_arch, md5_live)
check("md5 reads 3b92d088cf2bab1fca739c2bd5082ab5", md5_live == "3b92d088cf2bab1fca739c2bd5082ab5")

with zipfile.ZipFile(LIVE) as zf:
    doc = zf.read("word/document.xml").decode("utf-8")
    media = [n for n in zf.namelist() if n.startswith("word/media/")]
check("media entries == 8 (eight seats)", len(media) == 8, str(len(media)))

text = re.sub(r"<[^>]+>", "", doc)

block_lines = [
    "The shaft axis bows off its design line, sagging straight down under gravity.",
    "At the midpoint ring the bow reads 0.002 m at settle, and",
    "0.105 to 0.310 m through the measurement window (NR-059).",
    "The maximum sits at the hub and reads 0.209 to 0.613 m through the window (NR-059).",
    "An extension run past the window ends at 0.422 m at the midpoint",
    "and 0.833 m at the hub (NR-059).",
    "Every state at the midpoint ring reads below the 1.5 m line (NR-059).",
    "The settle hands off a straight stack while the run bows it.",
    "The two do not agree on the bowed shape.",
    "The disagreement reads as an instrument finding, not a design question (NR-059).",
]
for line in block_lines:
    check(f"docx text layer: block line reads once {line[:44]!r}", text.count(line) == 1,
          f"got {text.count(line)}")

probes = [
    ("Draft v0.57", 1),
    ("Draft v0.56", 0),
    ("Date 2026-10-16", 1),
    ("Date 2026-10-15", 0),
    ("NR-059", 6),
    ("NR-016", 3),
    ("10.170", 3),
    ("13.38", 4),
    ("instrument finding", 1),
    ("stack does not translate", 0),
    ("physical-validation", 0),
]
for phrase, want in probes:
    got = text.count(phrase)
    check(f"docx text layer {phrase[:48]!r} == {want}", got == want, f"got {got}")

pos_settle = text.index("The machine accelerates through the relax run.")
pos_block = text.index("The shaft axis bows off its design line")
pos_speed = text.index("Its window-mean speed reads 13.38 rad/s")
check("docx text layer: block sits after the settle paragraph and ahead of the speed line",
      pos_settle < pos_block < pos_speed, f"{pos_settle} < {pos_block} < {pos_speed}")
keys = ["0.002 m at settle", "0.209 to 0.613 m", "0.422 m at the midpoint",
        "below the 1.5 m line", "hands off a straight stack"]
pos = [text.index(k) for k in keys]
check("docx text layer: block reads in order", pos == sorted(pos), str(pos))

draft_text = DRAFT.read_text()
check("draft: pin reads v0.57", "Draft v0.57" in draft_text)
check("draft: v0.56 reads 0", "Draft v0.56" not in draft_text)
check("draft: line count 1076", len(draft_text.splitlines()) == 1076,
      str(len(draft_text.splitlines())))
check("draft: block lines read once", all(draft_text.count(l) == 1 for l in block_lines))
check("draft: NR-059 reads 5", draft_text.count("NR-059") == 5, str(draft_text.count("NR-059")))
check("draft: NR- count 255", draft_text.count("NR-") == 255, str(draft_text.count("NR-")))
check("draft: bow reads 4", draft_text.count("bow") == 4, str(draft_text.count("bow")))
check("draft: 1.5 m line reads once", draft_text.count("the 1.5 m line") == 1)
check("draft: settle anchor reads once",
      draft_text.count("The machine accelerates through the relax run.") == 1)

tracker_text = TRACKER.read_text()
check("tracker: v0.57 entry present", "v0.57 pass by @author" in tracker_text)
check("tracker: v0.56 history held", "v0.56 pass by @author" in tracker_text)
check("tracker: entry rows read once",
      tracker_text.count("This pass folds the winner bow read.") == 1
      and tracker_text.count("The bow block lands at section 3.3, after the settle-state read (NR-059).") == 1)

print(f"\n{total - len(fails)}/{total} checks passed")
if fails:
    print("FAILS:", ", ".join(fails))
    sys.exit(1)
print("ALL PASS")
