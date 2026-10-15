#!/usr/bin/env python3
"""Rebuild check: the v0.52 review copy (author seat, 2026-10-15).

Read-only. Re-checks the delivered DOCX against the landing facts: the
build record, the live/stamped parity, the media count, the refresher
block phrase set and the held forms. Exit rc=0 only when every check
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
ARCHIVE = OUT / "draft-b6cd166-20261015-163115.docx"
DRAFT = ROOT / "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER = ROOT / "docs/reporting/draft-tracker.md"
ASSEMBLED = OUT / "draft-assembled-docx.md"

BLOCK = (
    "At the top of the shaft the rotor turns in the wind.\n"
    "The whole shaft turns with the rotor.\n"
    "The shaft passes the torque from ring to ring.\n"
    "The lowest ring turns the generator at the ground station.\n"
    "\n"
    "The shaft works only under tension.\n"
    "Tension gives the shaft its capacity to transmit torque.\n"
    "With low tension the shaft bends and twists.\n"
    "A slack shaft cannot carry the load.\n"
    "\n"
    "Under the generator load the machine settles onto one operating point.\n"
    "In the settled state the shaft runs twisted along its length."
)

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
check("record: draft b6cd166", "Draft: `b6cd166`" in record)
check("record: register at cb862df", "file at `cb862df`" in record)
check("record: 8 of 8 seats", "Seats resolved: 8 of 8" in record)
check(
    "record: 43 cited, every one signed (51 total), checker exit 0",
    "43 cited, every one signed (51 signed rows total)" in record
    and "checker exit 0" in record,
)
check("record: built 2026-10-15T16:31:15Z", "Built: 2026-10-15T16:31:15Z" in record)

md5_live = hashlib.md5(LIVE.read_bytes()).hexdigest()
md5_arch = hashlib.md5(ARCHIVE.read_bytes()).hexdigest()
check("md5 parity live == archived build", md5_live == md5_arch, md5_live)
check("md5 reads 3c386dc289f70d6d26f65c7df06fb993", md5_live == "3c386dc289f70d6d26f65c7df06fb993")

with zipfile.ZipFile(LIVE) as zf:
    doc = zf.read("word/document.xml").decode("utf-8")
    media = [n for n in zf.namelist() if n.startswith("word/media/")]
check("media entries == 8 (eight seats)", len(media) == 8, str(len(media)))

probes = [
    ("v0.52", 1),
    ("v0.51", 0),
    ("v0.50", 0),
    ("At the top of the shaft the rotor turns in the wind.", 1),
    ("The whole shaft turns with the rotor.", 1),
    ("The shaft passes the torque from ring to ring.", 1),
    ("The lowest ring turns the generator at the ground station.", 1),
    ("The shaft works only under tension.", 1),
    ("Tension gives the shaft its capacity to transmit torque.", 1),
    ("With low tension the shaft bends and twists.", 1),
    ("A slack shaft cannot carry the load.", 1),
    ("Under the generator load the machine settles onto one operating point.", 1),
    ("In the settled state the shaft runs twisted along its length.", 1),
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
check("draft: pin reads v0.52", "Draft v0.52" in draft_text)
check("draft: v0.51 reads 0", "Draft v0.51" not in draft_text)
check("draft: block present once", draft_text.count(BLOCK) == 1)
check("draft: block digit-free", re.search(r"\d", BLOCK) is None)
check("draft: NR-049 sentence held", draft_text.count("It is not a search gene (NR-049).") == 1)
check(
    "draft: system-anatomy marker held once",
    draft_text.count("[Figure seated: figure-map row 2 (system anatomy plate, slug `system-anatomy`). Values cite NR-011, NR-017 and NR-043.]") == 1,
)

tracker_text = TRACKER.read_text()
check("tracker: v0.52 entry present", "v0.52 pass by @author (2026-10-15)." in tracker_text)
check("tracker: v0.51 entry held", "v0.51 pass by @fig-img-diagrams (2026-10-15)." in tracker_text)

asm = ASSEMBLED.read_text()
check("assembled: 'v0.52' reads 1", asm.count("v0.52") == 1, str(asm.count("v0.52")))
check("assembled: 'v0.51' reads 0", asm.count("v0.51") == 0)
check(
    "assembled: block first sentence reads 1",
    asm.count("At the top of the shaft the rotor turns in the wind.") == 1,
)
check(
    "assembled: block closing sentence reads 1",
    asm.count("In the settled state the shaft runs twisted along its length.") == 1,
)
check(
    "assembled: 8 figure roster blocks",
    asm.count("Figure (roster row") == 8,
    str(asm.count("Figure (roster row")),
)
check("assembled: 'unresolved' reads 0", asm.count("unresolved") == 0)

print(f"\n{total} checks, {len(fails)} fail")
sys.exit(1 if fails else 0)
