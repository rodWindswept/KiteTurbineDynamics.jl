#!/usr/bin/env python3
"""Rebuild check: the v0.51 review copy, the corner-machines fold (figures seat, 2026-10-15).

Read-only. Re-checks the delivered DOCX against the landing facts: the
build record, the live/archive parity, the media set (eight embeds, all
delivered bytes), the fold phrases and the held forms. Exit rc=0 only
when every check passes.
"""

import hashlib
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "scratch/report-pdf-build"
LIVE = OUT / "draft-live.docx"
ARCHIVE = OUT / "draft-1061878-20261015-155027.docx"
CG = ROOT / "docs/reporting/figures/machine-corner-grid"

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
check("record: draft 1061878", "Draft: `1061878`" in record)
check("record: register at cb862df", "file at `cb862df`" in record)
check("record: 8 of 8 seats", "Seats resolved: 8 of 8" in record)
check(
    "record: the seat list carries machine-corner-grid",
    "`machine-corner-grid`" in record,
)
check(
    "record: 43 cited, every one signed (51 total), checker exit 0",
    "43 cited, every one signed (51 signed rows total)" in record
    and "checker exit 0" in record,
)

md5_live = hashlib.md5(LIVE.read_bytes()).hexdigest()
md5_arch = hashlib.md5(ARCHIVE.read_bytes()).hexdigest()
check("md5 parity live == archived build", md5_live == md5_arch, md5_live)
check("md5 reads 74aa4c02cdb80ecf310982fee361b15b", md5_live == "74aa4c02cdb80ecf310982fee361b15b")

with zipfile.ZipFile(LIVE) as zf:
    doc = zf.read("word/document.xml").decode("utf-8")
    media = {n: zf.read(n) for n in zf.namelist() if n.startswith("word/media/")}

check("media entries == 8", len(media) == 8, str(len(media)))
media_shas = {hashlib.sha256(b).hexdigest() for b in media.values()}
KIT_PNG = {
    "system-anatomy": "696be723993c708b038e0d1e10b96e83ba357a65cb2442580b1de371dedf8c66",
    "machine-winner-hero": "fae022131b198ac7f523d83521c4723b619ae3c70f7edb83acb3f222835d82e6",
    "ring-utilisation": "bfc744008aafe755679b7f45e543147654a654b002f5c4a70d0ea871bab94ef3",
    "twist-limit": "14f6b8b286d1f8e53a85e4a9072c936267eff530dbc44c0f385e8e05dce68069",
    "pca-landscape": "4b1bd3453a6aa20d9b9b0af75eb989212b16df8986c752766edd625ae13d9892",
    "pca-atlas": "1e46b70ae65f5557d23bb1a78ab7a75fdc2550a712ac9b2652d31562c67096e8",
    "machine-corner-grid": "517a77bf032bec1c0cde4eea7db93fdbc47470c65c9d76e6c4e58249436a2568",
    "machine-evolution-strip": "8e9d1d40684b984059601f31d5fb2daed8f835f6f8184a716280f8cd779e1cb6",
}
for slug, sha in KIT_PNG.items():
    disk = hashlib.sha256((ROOT / f"docs/reporting/figures/{slug}/{slug}.png").read_bytes()).hexdigest()
    check(f"kit png on disk == pinned {slug}", disk == sha)
check("every kit png embeds (delivered bytes)", media_shas == set(KIT_PNG.values()))

probes = [
    ("v0.51", 1),
    ("v0.50", 0),
    ("v0.49", 0),
    ("Figure (roster row 23)", 1),
    ("The four corner designs show how widely the machine changes across the search field", 1),
    ("Four panels show the nearest feasible design to each corner", 1),
    ("60.646", 1),
    ("58.864", 1),
    ("33.704", 1),
    ("33.812", 1),
    ("corner-grid-extract-2026-10-15-picks", 1),
    ("All eight read dataset commit", 1),
    ("All seven read dataset commit", 0),
    ("The corner-grid picks (v13 5 kW screen): four machines, one per PC1-PC2 window corner", 1),
    ("data dd3cc6a \u00b7 script a4b4057 \u00b7 rows NR-044, NR-051", 1),
    ("517a77bf032bec1c0cde4eea7db93fdbc47470c65c9d76e6c4e58249436a2568", 1),
    ("Three lifting bridles", 1),
    ("Three bridles", 0),
    ("down the lifting bridles", 1),
    ("Machine winner", 2),
    ("hero image", 0),
]
for needle, exp in probes:
    n = doc.count(needle)
    check(f"probe x{n} == x{exp}: {needle[:64]}", n == exp)

print(f"\n{total} checks, {len(fails)} fail")
sys.exit(1 if fails else 0)
