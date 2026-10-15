#!/usr/bin/env python3
"""Rebuild check: the v0.54 review copy (author seat, 2026-10-15).

Read-only. Re-checks the delivered DOCX against the landing facts: the
build record, the live/stamped parity, the media count, the operating-point
and torsion phrase set and the held forms. Exit rc=0 only when every check
passes.
"""

import hashlib
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "scratch/report-pdf-build"
LIVE = OUT / "draft-live.docx"
ARCHIVE = OUT / "draft-d453530-20261015-202520.docx"
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
check("record: draft d453530", "Draft: `d453530`" in record)
check("record: register at 2142d43", "file at `2142d43`" in record)
check("record: 8 of 8 seats", "Seats resolved: 8 of 8" in record)
check(
    "record: 48 cited, every one signed (54 total), checker exit 0",
    "48 cited, every one signed (54 signed rows total)" in record
    and "checker exit 0" in record,
)
check("record: built 2026-10-15T20:25:20Z", "Built: 2026-10-15T20:25:20Z" in record)

md5_live = hashlib.md5(LIVE.read_bytes()).hexdigest()
md5_arch = hashlib.md5(ARCHIVE.read_bytes()).hexdigest()
check("md5 parity live == archived build", md5_live == md5_arch, md5_live)
check("md5 reads 72ef99bee03bc301433c3d533a1abc54", md5_live == "72ef99bee03bc301433c3d533a1abc54")

with zipfile.ZipFile(LIVE) as zf:
    doc = zf.read("word/document.xml").decode("utf-8")
    media = [n for n in zf.namelist() if n.startswith("word/media/")]
check("media entries == 8 (eight seats)", len(media) == 8, str(len(media)))

probes = [
    ("v0.54", 1),
    ("v0.53", 0),
    ("v0.52", 0),
    ("Reference wind speed", 1),
    ("Ring speed ratio", 1),
    ("Tip-speed ratio", 1),
    ("5.566", 3),
    ("6.8415", 3),
    ("45.9733", 2),
    ("39.4912", 2),
    ("1.225", 3),
    ("19.1304", 3),
    ("27.75", 2),
    ("72.25", 2),
    ("0.2944", 2),
    ("0.2258", 2),
    ("AeroDyn v5.0.0", 1),
    ("The swept area reads 45.9733 square metres raw and 39.4912 square", 1),
    ("The rotor Cp reads", 1),
    ("The Betz ceiling reads 19.1304 kW", 1),
    ("Torsion keeps its own criteria", 1),
    ("The realisability floor reads 72.25 degrees (NR-053)", 1),
    ("2.5 gate does not cover torsion (NR-052)", 1),
    ("The structural members and the lines", 1),
    ("The gate set reads per class", 1),
    ("hold a factor of safety of 2.5 or higher", 1),
    ("NR-052", 3),
    ("NR-053", 3),
    ("NR-031", 3),
    ("NR-033", 2),
    ("NR-034", 3),
    ("The fix has landed.", 1),
    ("It never allows breaks.", 1),
    ("508 feasible candidates", 1),
    ("mean power of 5.309", 1),
    ("25.698 kilograms", 4),
    ("topmost ring", 9),
    ("levers of Performance", 1),
    ("The rapid path awaits its rope-break gate fix", 0),
    ("The rapid path rejects all three winners", 0),
    ("stays open", 0),
    ("11.01 m/s at 9.41 m", 2),
]
for phrase, want in probes:
    got = doc.count(phrase)
    check(f"docx probe {phrase[:55]!r} == {want}", got == want, f"got {got}")

text = re.sub(r"<[^>]+>", "", doc)
for phrase, want in [
    ("Reference wind speed", 1),
    ("does not cover torsion", 1),
    ("Betz ceiling", 2),
    ("The swept area reads", 1),
]:
    got = text.count(phrase)
    check(f"docx text layer {phrase[:40]!r} == {want}", got == want, f"got {got}")

draft_text = DRAFT.read_text()
check("draft: pin reads v0.54", "Draft v0.54" in draft_text)
check("draft: v0.53 reads 0", "Draft v0.53" not in draft_text)
check("draft: line count 1044", len(draft_text.splitlines()) == 1044, str(len(draft_text.splitlines())))
check("draft: fix-landed reads once", draft_text.count("The fix has landed.") == 1)
check("draft: NR-013 ext2 reads 5", draft_text.count("NR-013 ext2") == 5)
check(
    "draft: placed-fix sentence reads 2",
    draft_text.count("The rapid path takes the rope-break gate placement fix (NR-013 ext2).") == 2,
)
check("draft: NR-049 sentence held", draft_text.count("It is not a search gene (NR-049).") == 1)
check(
    "draft: new rows read once each",
    draft_text.count("| Reference wind speed | 11.01 m/s at 9.41 m | NR-008, NR-032 |") == 1
    and draft_text.count("| Ring speed ratio | 5.566 | NR-031 |") == 1
    and draft_text.count("| Tip-speed ratio | 6.8415 | NR-032 |") == 1,
)
check(
    "draft: torsion block reads once",
    draft_text.count("Torsion keeps its own criteria.") == 1
    and draft_text.count("The realisability floor reads 72.25 degrees (NR-053).") == 1
    and draft_text.count("2.5 gate does not cover torsion (NR-052).") == 1,
)

tracker_text = TRACKER.read_text()
check("tracker: v0.54 entry present", "v0.54 pass by @author" in tracker_text)
check("tracker: v0.53 history held", "v0.53 pass by @author" in tracker_text)

print(f"\n{total - len(fails)}/{total} checks passed")
if fails:
    print("FAILS:", ", ".join(fails))
    sys.exit(1)
print("ALL PASS")
