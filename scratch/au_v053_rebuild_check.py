#!/usr/bin/env python3
"""Rebuild check: the v0.53 review copy (author seat, 2026-10-15).

Read-only. Re-checks the delivered DOCX against the landing facts: the
build record, the live/stamped parity, the media count, the fixed-defect
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
ARCHIVE = OUT / "draft-89ed222-20261015-181801.docx"
DRAFT = ROOT / "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER = ROOT / "docs/reporting/draft-tracker.md"
ASSEMBLED = OUT / "draft-assembled-docx.md"

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
check("record: draft 89ed222", "Draft: `89ed222`" in record)
check("record: register at fab730a", "file at `fab730a`" in record)
check("record: 8 of 8 seats", "Seats resolved: 8 of 8" in record)
check(
    "record: 43 cited, every one signed (51 total), checker exit 0",
    "43 cited, every one signed (51 signed rows total)" in record
    and "checker exit 0" in record,
)
check("record: built 2026-10-15T18:18:01Z", "Built: 2026-10-15T18:18:01Z" in record)

md5_live = hashlib.md5(LIVE.read_bytes()).hexdigest()
md5_arch = hashlib.md5(ARCHIVE.read_bytes()).hexdigest()
check("md5 parity live == archived build", md5_live == md5_arch, md5_live)
check("md5 reads e1eaef4358f7bff7e8da8b8b73a5cf3b", md5_live == "e1eaef4358f7bff7e8da8b8b73a5cf3b")

with zipfile.ZipFile(LIVE) as zf:
    doc = zf.read("word/document.xml").decode("utf-8")
    media = [n for n in zf.namelist() if n.startswith("word/media/")]
check("media entries == 8 (eight seats)", len(media) == 8, str(len(media)))

probes = [
    ("v0.53", 1),
    ("v0.52", 0),
    ("v0.51", 0),
    ("v0.50", 0),
    ("The rapid path takes the rope-break gate placement fix (NR-013 ext2).", 2),
    ("Use the rapid path for screening under its fixed rope-break gate (NR-013 ext2).", 1),
    ("The placement fix has landed.", 1),
    ("The rapid path once rejected all three winners at the rope-break gate", 2),
    ("The fix has landed.", 1),
    ("rope-break check at the relax boundary (NR-013 ext2). Detection runs", 1),
    ("on the measurement window only.", 1),
    ("The rapid path awaits its rope-break gate fix", 0),
    ("stays open", 0),
    ("Fix the rapid-path rope-break gate", 0),
    ("The rapid path rejects all three winners", 0),
    ("NR-013 ext2", 5),
    ("(NR-013 ext2)", 4),
    ("It never allows breaks.", 1),
    ("Every healthy winner reads reject on the default path.", 1),
    ("Three lifting bridles", 1),
    ("Three bridles", 0),
    ("down the lifting bridles", 1),
    ("Machine winner hero", 0),
    ("Machine winner", 2),
    ("topmost ring", 9),
    ("topmost rotor ring", 2),
    ("topmost ring radius", 3),
    ("levers of Performance", 1),
    ("508 feasible candidates", 1),
    ("mean power of 5.309", 1),
    ("25.698 kilograms", 4),
]
for phrase, want in probes:
    got = doc.count(phrase)
    check(f"docx probe {phrase[:55]!r} == {want}", got == want, f"got {got}")

text = re.sub(r"<[^>]+>", "", doc)
check(
    "docx text layer: 'machine-winner-hero' == 3",
    text.count("machine-winner-hero") == 3,
    str(text.count("machine-winner-hero")),
)
hero_hits = [m.start() for m in re.finditer(r"(?i)hero", text)]
check(
    "docx text layer: 'hero' == 3, every hit sits in the slug",
    len(hero_hits) == 3
    and all(text[max(0, i - 15):i] == "machine-winner-" for i in hero_hits),
    str(len(hero_hits)),
)
word_hits = re.findall(r"\bhub\b", text, re.I)
check("docx text layer: word 'hub' == 5 (register-appendix holds)", len(word_hits) == 5, str(len(word_hits)))

draft_text = DRAFT.read_text()
check("draft: pin reads v0.53", "Draft v0.53" in draft_text)
check("draft: v0.52 reads 0", "Draft v0.52" not in draft_text)
check("draft: line count 1021", len(draft_text.splitlines()) == 1021, str(len(draft_text.splitlines())))
check("draft: fix-landed reads once", draft_text.count("The fix has landed.") == 1)
check(
    "draft: placed-fix sentence reads 2",
    draft_text.count("The rapid path takes the rope-break gate placement fix (NR-013 ext2).") == 2,
)
check("draft: awaits sentence reads 0", "The rapid path awaits its rope-break gate fix (NR-013)." not in draft_text)
check("draft: stays-open reads 0", "stays open" not in draft_text)
check("draft: NR-013 ext2 reads 5", draft_text.count("NR-013 ext2") == 5)
check("draft: NR-049 sentence held", draft_text.count("It is not a search gene (NR-049).") == 1)
check(
    "draft: system-anatomy marker held once",
    draft_text.count("[Figure seated: figure-map row 2 (system anatomy plate, slug `system-anatomy`). Values cite NR-011, NR-017 and NR-043.]") == 1,
)

tracker_text = TRACKER.read_text()
check("tracker: v0.53 entry present", "v0.53 pass by @author (2026-10-15)." in tracker_text)
check("tracker: v0.52 entry held", "v0.52 pass by @author (2026-10-15)." in tracker_text)

asm = ASSEMBLED.read_text()
check("assembled: 'v0.53' reads 1", asm.count("v0.53") == 1, str(asm.count("v0.53")))
check("assembled: 'v0.52' reads 0", asm.count("v0.52") == 0)
check(
    "assembled: placed-fix sentence reads 2",
    asm.count("The rapid path takes the rope-break gate placement fix (NR-013 ext2).") == 2,
)
check(
    "assembled: fix-landed sentence reads 1",
    asm.count("The fix has landed.") == 1,
)
check("assembled: 'awaits' reads 0", asm.count("awaits") == 0)
check("assembled: 'stays open' reads 0", asm.count("stays open") == 0)
check(
    "assembled: 8 figure roster blocks",
    asm.count("Figure (roster row") == 8,
    str(asm.count("Figure (roster row")),
)
check("assembled: 'unresolved' reads 0", asm.count("unresolved") == 0)

print(f"\n{total} checks, {len(fails)} fail")
sys.exit(1 if fails else 0)
