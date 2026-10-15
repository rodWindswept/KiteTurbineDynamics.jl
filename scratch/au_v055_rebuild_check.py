#!/usr/bin/env python3
"""Rebuild check: the v0.55 review copy (author seat, 2026-10-15).

Read-only. Re-checks the delivered DOCX against the landing facts: the
build record, the live/stamped parity, the media count, the reject-split
and environment phrase set and the held forms. Exit rc=0 only when every
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
ARCHIVE = OUT / "draft-2e930a8-20261015-212715.docx"
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
check("record: draft 2e930a8", "Draft: `2e930a8`" in record)
check("record: register at a51e9d9", "file at `a51e9d9`" in record)
check("record: 8 of 8 seats", "Seats resolved: 8 of 8" in record)
check(
    "record: 52 cited, every one signed (58 total), checker exit 0",
    "52 cited, every one signed (58 signed rows total)" in record
    and "checker exit 0" in record,
)
check("record: built 2026-10-15T21:27:15Z", "Built: 2026-10-15T21:27:15Z" in record)

md5_live = hashlib.md5(LIVE.read_bytes()).hexdigest()
md5_arch = hashlib.md5(ARCHIVE.read_bytes()).hexdigest()
check("md5 parity live == archived build", md5_live == md5_arch, md5_live)
check("md5 reads 4c4384146bbba1d56938814e60741d18", md5_live == "4c4384146bbba1d56938814e60741d18")

with zipfile.ZipFile(LIVE) as zf:
    doc = zf.read("word/document.xml").decode("utf-8")
    media = [n for n in zf.namelist() if n.startswith("word/media/")]
check("media entries == 8 (eight seats)", len(media) == 8, str(len(media)))

probes = [
    ("v0.55", 1),
    ("v0.54", 0),
    ("v0.52", 0),
    ("The reject class splits three ways", 1),
    ("The 301 rejects split three ways", 1),
    ("96 ran below the 5 kW power floor.", 2),
    ("Four ran at or above 5 kW with a factor of safety below 2.5.", 2),
    ("The cause is not logged for the remaining 201.", 2),
    ("Hellmann", 2),
    ("Shaft elevation", 1),
    ("hub at 9.4000", 1),
    ("The reported trace runs steady wind", 1),
    ("steady-wind response, not a stability property", 2),
    ("NR-055", 3),
    ("NR-056", 2),
    ("NR-057", 2),
    ("NR-058", 2),
    ("1/7", 2),
    ("10.0 m/s at 4.8 m", 2),
    ("30 deg", 2),
    ("9.4000", 2),
    ("Reference wind speed", 1),
    ("Ring speed ratio", 1),
    ("Tip-speed ratio", 1),
    ("The search found 508 feasible candidates in the searched space (NR-002).", 1),
    ("The best performing one had a mean power of 5.309 kW.", 1),
    ("The fix has landed.", 1),
    ("It never allows breaks.", 1),
    ("does not cover torsion", 1),
    ("The swept area reads", 1),
    ("Torsion keeps its own criteria", 1),
    ("The realisability floor reads 72.25 degrees (NR-053)", 1),
    ("2.5 gate does not cover torsion (NR-052)", 1),
    ("The rapid path awaits its rope-break gate fix", 0),
    ("The rapid path rejects all three winners", 0),
    ("stays open", 0),
    ("11.01 m/s at 9.41 m", 2),
    ("mean power of 5.309", 1),
    ("25.698 kilograms", 4),
    ("22 degrees", 3),
    ("NR-049", 3),
    ("NR-050", 2),
]
for phrase, want in probes:
    got = doc.count(phrase)
    check(f"docx probe {phrase[:55]!r} == {want}", got == want, f"got {got}")

text = re.sub(r"<[^>]+>", "", doc)
for phrase, want in [
    ("The reject class splits three ways (NR-055).", 1),
    ("The 301 rejects split three ways (NR-055).", 1),
    ("The reported trace runs steady wind", 1),
    ("Hellmann power law, exponent 1/7", 2),
    # counts run on the stripped layer: one least-margin carrier spans a
    # tag boundary, so raw reads 5 and the stripped text reads 6
    ("least segment torque margin is 2.03", 6),
]:
    got = text.count(phrase)
    check(f"docx text layer {phrase[:40]!r} == {want}", got == want, f"got {got}")

draft_text = DRAFT.read_text()
check("draft: pin reads v0.55", "Draft v0.55" in draft_text)
check("draft: v0.54 reads 0", "Draft v0.54" not in draft_text)
check("draft: line count 1059", len(draft_text.splitlines()) == 1059, str(len(draft_text.splitlines())))
check("draft: NR- count 250", draft_text.count("NR-") == 250, str(draft_text.count("NR-")))
check("draft: NR-013 ext2 reads 5", draft_text.count("NR-013 ext2") == 5)
check("draft: fix-landed reads once", draft_text.count("The fix has landed.") == 1)
check(
    "draft: placed-fix sentence reads 2",
    draft_text.count("The rapid path takes the rope-break gate placement fix (NR-013 ext2).") == 2,
)
check(
    "draft: split opens read once each",
    draft_text.count("The reject class splits three ways (NR-055).") == 1
    and draft_text.count("The 301 rejects split three ways (NR-055).") == 1,
)
check(
    "draft: subgroup lines read twice each",
    draft_text.count("96 ran below the 5 kW power floor.") == 2
    and draft_text.count("Four ran at or above 5 kW with a factor of safety below 2.5.") == 2
    and draft_text.count("The cause is not logged for the remaining 201.") == 2,
)
check(
    "draft: new rows read once each",
    draft_text.count("| Shear law | Hellmann power law, exponent 1/7, from the measured Daisy pair 10.0 m/s at 4.8 m | NR-056 |") == 1
    and draft_text.count("| Shaft elevation | 30 deg, hub at 9.4000 m | NR-057 |") == 1,
)
check(
    "draft: swing note reads once",
    draft_text.count("The reported trace runs steady wind, so the swing reads as a steady-wind response, not a stability property (NR-058).") == 1,
)
check(
    "draft: cites read 2/1/1/1",
    draft_text.count("NR-055") == 2 and draft_text.count("NR-056") == 1
    and draft_text.count("NR-057") == 1 and draft_text.count("NR-058") == 1,
)

tracker_text = TRACKER.read_text()
check("tracker: v0.55 entry present", "v0.55 pass by @author" in tracker_text)
check("tracker: v0.54 history held", "v0.54 pass by @author" in tracker_text)

print(f"\n{total - len(fails)}/{total} checks passed")
if fails:
    print("FAILS:", ", ".join(fails))
    sys.exit(1)
print("ALL PASS")
