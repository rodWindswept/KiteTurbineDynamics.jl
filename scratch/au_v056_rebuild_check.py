#!/usr/bin/env python3
"""Rebuild check: the v0.56 review copy (author seat, 2026-10-15).

Read-only. Re-checks the delivered DOCX against the landing facts: the
build record, the live/stamped parity, the media count, the era-pack
phrase set and the held forms. Exit rc=0 only when every check passes.
"""

import hashlib
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "scratch/report-pdf-build"
LIVE = OUT / "draft-live.docx"
ARCHIVE = OUT / "draft-c9f0560-20261015-215702.docx"
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
check("record: draft c9f0560", "Draft: `c9f0560`" in record)
check("record: register at 1b09190", "file at `1b09190`" in record)
check("record: 8 of 8 seats", "Seats resolved: 8 of 8" in record)
check(
    "record: 52 cited, every one signed (58 total), checker exit 0",
    "52 cited, every one signed (58 signed rows total)" in record
    and "checker exit 0" in record,
)
check("record: built 2026-10-15T21:57:02Z", "Built: 2026-10-15T21:57:02Z" in record)

md5_live = hashlib.md5(LIVE.read_bytes()).hexdigest()
md5_arch = hashlib.md5(ARCHIVE.read_bytes()).hexdigest()
check("md5 parity live == archived build", md5_live == md5_arch, md5_live)
check("md5 reads 5ecee42e6dcf1f16c6eaec3e2a2bd87a", md5_live == "5ecee42e6dcf1f16c6eaec3e2a2bd87a")

with zipfile.ZipFile(LIVE) as zf:
    doc = zf.read("word/document.xml").decode("utf-8")
    media = [n for n in zf.namelist() if n.startswith("word/media/")]
check("media entries == 8 (eight seats)", len(media) == 8, str(len(media)))

probes = [
    ("v0.56", 1),
    ("v0.55", 0),
    ("v0.54", 0),
    ("physics-validation", 0),
    ("first search campaign of the wind-authority era", 1),
    ("This campaign is the first search campaign", 1),
    ("Larger and wider campaigns sit ahead.", 1),
    ("2026-08-13 k-alignment", 1),
    ("2026-08-14 inverted-taper", 1),
    ("2026-08-22 blade-mass-law", 1),
    ("2026-08-22 FoS=Inf", 1),
    ("2026-08-24 stale-gain", 1),
    ("2026-08-26 rotor-to-ring", 1),
    ("An earlier round of this study swept the generator gain", 1),
    ("destructive resonance", 1),
    ("That round shares no number with this campaign", 1),
    ("That load forces about 9 kW from the seed (NR-047).", 1),
    ("The sweep rows read as follows (NR-047).", 1),
    ("NR-047", 5),
    ("36.109", 11),
    ("25.698", 11),
    ("508 feasible candidates", 1),
    ("96 ran below the 5 kW power floor.", 2),
    ("The reported trace runs steady wind", 1),
    ("NR-055", 3),
    ("NR-056", 2),
    ("NR-058", 2),
]
for phrase, want in probes:
    got = doc.count(phrase)
    check(f"docx probe {phrase[:55]!r} == {want}", got == want, f"got {got}")

text = re.sub(r"<[^>]+>", "", doc)
check(
    "docx text layer: era sentence reads once",
    text.count("This campaign is the first search campaign of the wind-authority era.") == 1,
)
keys = ["2026-08-13 k-alignment", "2026-08-14 inverted-taper", "2026-08-22 blade-mass-law",
        "2026-08-22 FoS=Inf", "2026-08-24 stale-gain", "2026-08-26 rotor-to-ring"]
pos = [text.index(k) for k in keys]
check("docx text layer: ledger rows read in date order", pos == sorted(pos), str(pos))

draft_text = DRAFT.read_text()
check("draft: pin reads v0.56", "Draft v0.56" in draft_text)
check("draft: v0.55 reads 0", "Draft v0.55" not in draft_text)
check("draft: line count 1063", len(draft_text.splitlines()) == 1063, str(len(draft_text.splitlines())))
check("draft: physics-validation reads 0", draft_text.count("physics-validation") == 0)
check("draft: era phrase reads 3", draft_text.count("wind-authority era") == 3, str(draft_text.count("wind-authority era")))
check("draft: era sentence reads once", draft_text.count("This campaign is the first search campaign of the wind-authority era.") == 1)
check("draft: back-pointer reads once", draft_text.count("At the top of that sweep the TRPT shaft entered a destructive resonance.") == 1)
check("draft: NR-047 reads 4", draft_text.count("NR-047") == 4, str(draft_text.count("NR-047")))
check("draft: NR- count 250", draft_text.count("NR-") == 250, str(draft_text.count("NR-")))
check("draft: NR-013 ext2 reads 5", draft_text.count("NR-013 ext2") == 5)
check(
    "draft: ledger rows once, date order",
    all(draft_text.count(k) == 1 for k in keys)
    and draft_text.index("2026-08-13 k-alignment") < draft_text.index("2026-08-14 inverted-taper")
    < draft_text.index("2026-08-22 blade-mass-law") < draft_text.index("2026-08-22 FoS=Inf")
    < draft_text.index("2026-08-24 stale-gain") < draft_text.index("2026-08-26 rotor-to-ring"),
)
check("draft: 36.109 reads 6", draft_text.count("36.109") == 6, str(draft_text.count("36.109")))
check("draft: 25.698 reads 8", draft_text.count("25.698") == 8, str(draft_text.count("25.698")))

tracker_text = TRACKER.read_text()
check("tracker: v0.56 entry present", "v0.56 pass by @author" in tracker_text)
check("tracker: v0.55 history held", "v0.55 pass by @author" in tracker_text)

print(f"\n{total - len(fails)}/{total} checks passed")
if fails:
    print("FAILS:", ", ".join(fails))
    sys.exit(1)
print("ALL PASS")
