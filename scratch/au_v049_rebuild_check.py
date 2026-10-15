#!/usr/bin/env python3
"""Rebuild check: the v0.49 review copy (author seat, 2026-10-15).

Read-only. Re-checks the delivered DOCX against the landing facts: the
build record, the live/stamped parity, the media count, the re-key
phrase set and the retired-form disposition. Exit rc=0 only when every
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
ARCHIVE = OUT / "draft-8169e36-20261015-144342.docx"
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
check("record: draft 8169e36", "Draft: `8169e36`" in record)
check("record: register at cb862df", "file at `cb862df`" in record)
check("record: 7 of 7 seats", "Seats resolved: 7 of 7" in record)
check(
    "record: 42 cited, every one signed (51 total), checker exit 0",
    "42 cited, every one signed (51 signed rows total)" in record
    and "checker exit 0" in record,
)

md5_live = hashlib.md5(LIVE.read_bytes()).hexdigest()
md5_arch = hashlib.md5(ARCHIVE.read_bytes()).hexdigest()
check("md5 parity live == archived build", md5_live == md5_arch, md5_live)
check("md5 reads 24f98df65d7274233bfea9cc9e736937", md5_live == "24f98df65d7274233bfea9cc9e736937")

with zipfile.ZipFile(LIVE) as zf:
    doc = zf.read("word/document.xml").decode("utf-8")
    media = [n for n in zf.namelist() if n.startswith("word/media/")]
check("media entries == 7", len(media) == 7, str(len(media)))

probes = [
    ("v0.49", 1),
    ("v0.48", 0),
    ("v0.47", 0),
    ("Three lifting bridles", 1),
    ("Three bridles", 0),
    ("down the lifting bridles", 1),
    ("down the bridles", 0),
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
    check(f"docx probe {phrase!r} == {want}", got == want, f"got {got}")

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
dhero = [m.start() for m in re.finditer(r"(?i)hero", draft_text)]
check(
    "draft: raw 'hero' == 1, in the slug",
    len(dhero) == 1 and draft_text[dhero[0] - 15:dhero[0]] == "machine-winner-",
    str(len(dhero)),
)
check("draft: 'down the bridles' reads 0", draft_text.count("down the bridles") == 0)
check("draft: 'lifting bridles' reads 1", draft_text.count("lifting bridles") == 1)

asm = ASSEMBLED.read_text()
check("assembled: 'Machine winner hero' reads 0", asm.count("Machine winner hero") == 0)
check("assembled: 'Machine winner' reads 2", asm.count("Machine winner") == 2)
check("assembled: 'Three lifting bridles' reads 1", asm.count("Three lifting bridles") == 1)
check("assembled: 'Three bridles' reads 0", asm.count("Three bridles") == 0)
asm_hero = [m.start() for m in re.finditer(r"(?i)hero", asm)]
check(
    "assembled: 'hero' == 5, every hit sits in the slug",
    len(asm_hero) == 5 and all(asm[max(0, i - 15):i] == "machine-winner-" for i in asm_hero),
    str(len(asm_hero)),
)

asm_lines = asm.splitlines()
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

print(f"\n{total} checks, {len(fails)} fail")
sys.exit(1 if fails else 0)
