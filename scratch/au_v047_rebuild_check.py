#!/usr/bin/env python3
"""Rebuild check: the v0.47 review copy (author seat, 2026-10-15).

Read-only. Re-checks the delivered DOCX against the landing facts: the
build record, the live/stamped parity, the media count, the phrase set
and the retired-word disposition. Exit rc=0 only when every check passes.
"""

import hashlib
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "scratch/report-pdf-build"
LIVE = OUT / "draft-live.docx"
ARCHIVE = OUT / "draft-d0ed902-20261015-124752.docx"
DRAFT = ROOT / "docs/reporting/drafts/2026-10-08-report-first-draft.md"
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
check("record: draft d0ed902", "Draft: `d0ed902`" in record)
check("record: register at cb862df", "`cb862df`" in record)
check("record: 7 of 7 seats", "Seats resolved: 7 of 7" in record)
check(
    "record: 51 signed rows, checker exit 0",
    "every one signed (51 signed rows total)" in record and "checker exit 0" in record,
)

md5_live = hashlib.md5(LIVE.read_bytes()).hexdigest()
md5_arch = hashlib.md5(ARCHIVE.read_bytes()).hexdigest()
check("md5 parity live == archived build", md5_live == md5_arch, md5_live)

with zipfile.ZipFile(LIVE) as zf:
    doc = zf.read("word/document.xml").decode("utf-8")
    media = [n for n in zf.namelist() if n.startswith("word/media/")]
check("media entries == 7", len(media) == 7, str(len(media)))

probes = [
    ("v0.47", 1),
    ("topmost ring", 9),
    ("topmost rotor ring", 2),
    ("topmost ring radius", 3),
    ("508 feasible candidates", 1),
    ("mean power of 5.309", 1),
    ("25.698 kilograms", 4),
    ("levers of Performance", 1),
]
for phrase, want in probes:
    got = doc.count(phrase)
    check(f"docx probe {phrase!r} == {want}", got == want, f"got {got}")

draft_text = DRAFT.read_text()
check("draft: raw 'hub' reads 0", len(re.findall(r"hub", draft_text, re.I)) == 0)

asm_lines = ASSEMBLED.read_text().splitlines()
appendix_start = next(
    i for i, ln in enumerate(asm_lines) if ln.startswith("## Data register")
)
hub_lines = [i for i, ln in enumerate(asm_lines) if re.search(r"\bhub\b", ln, re.I)]
hub_hits = sum(len(re.findall(r"\bhub\b", ln, re.I)) for ln in asm_lines)
check("assembled: word 'hub' occurrences == 5", hub_hits == 5, str(hub_hits))
check(
    "assembled: every 'hub' occurrence sits in an appendix register row",
    all(i > appendix_start and asm_lines[i].startswith("| NR-") for i in hub_lines),
)
seg_lines = [ln for ln in asm_lines if "hub segment" in ln]
check(
    "assembled: 'hub segment' held only in the NR-048 row",
    len(seg_lines) == 1 and "NR-048" in seg_lines[0],
)

text = re.sub(r"<[^>]+>", "", doc)
word_hits = re.findall(r"\bhub\b", text, re.I)
check("docx text layer: word 'hub' == 5", len(word_hits) == 5, str(len(word_hits)))

print(f"\n{total} checks, {len(fails)} fail")
sys.exit(1 if fails else 0)
