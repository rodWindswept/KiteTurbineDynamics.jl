#!/usr/bin/env python3
"""Check: the levers caption seating headers (figures seat).

Asserts, for both levers caption files:
  1. the seated head strings read; the draft-head strings are gone;
  2. the build parser reads the same plain and technical sections as before
     the pass (byte-identical), against the pre-edit copies in scratch/;
  3. the v3 hash blocks recompute from the committed bytes (the five pinned
     files per kit, md5);
  4. no 'pending' byte in either file.

Run from the repo root:
  /usr/bin/python3 scratch/fig_sh_check.py
"""
import hashlib
import importlib.util
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OK = 0
FAIL = 0


def ok(msg):
    global OK
    OK += 1
    print(f"  ok   {msg}")


def bad(msg):
    global FAIL
    FAIL += 1
    print(f"  FAIL {msg}")


def md5b(b):
    return hashlib.md5(b).hexdigest()


KITS = {
    "pca-landscape": {
        "before": "scratch/fig_sh_before_landscape.md",
        "reads": "the levers landscape",
        "cite": "NR-045",
    },
    "pca-atlas": {
        "before": "scratch/fig_sh_before_atlas.md",
        "reads": "the parameter atlas",
        "cite": None,
    },
}

spec = importlib.util.spec_from_file_location("bdp", ROOT / "scripts/build_draft_pdf.py")
bdp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bdp)

print("[1] the seated head reads; the draft head is gone")
for slug, k in KITS.items():
    t = (ROOT / f"docs/reporting/figures/{slug}/captions.md").read_text()
    for s in (
        f"# Captions: {k['reads']}",
        "**Status** GENERATE. **Date** 2026-10-13.",
        "**Cite fix and re-cut** 2026-10-14.",
        "The split: the plain and technical captions carry the scientific text",
        "**Delta** v4 (2026-10-14): the seating header refines",
    ):
        (ok if s in t else bad)(f"{slug}: present {s[:62]!r}")
    for s in (
        "Captions draft:",
        "**Status** DRAFT",
        "Review input for the author",
        "Ledger strings only",
    ):
        (bad if s in t else ok)(f"{slug}: retired {s[:62]!r}")
    if k["cite"]:
        (ok if k["cite"] in t else bad)(f"{slug}: {k['cite']} reads in the file")

print("[2] the build parse is byte-identical")
for slug, k in KITS.items():
    p = ROOT / f"docs/reporting/figures/{slug}/captions.md"
    b = ROOT / k["before"]
    plain0, tech0 = bdp.parse_caption_sections(b)
    plain1, tech1 = bdp.parse_caption_sections(p)
    for label, a, c in (("plain", plain0, plain1), ("tech", tech0, tech1)):
        if a == c:
            ok(f"{slug}: {label} caption byte-identical (md5 {md5b(c.encode())})")
        else:
            bad(f"{slug}: {label} caption moved")

print("[3] the v3 hash blocks recompute")
for slug in KITS:
    d = ROOT / "docs/reporting/figures" / slug
    blk = (d / "register-status.md").read_text()
    want = dict(re.findall(r"^\s+(\S+)\s+([0-9a-f]{32})$", blk, re.M))
    exp = {"label-ledger.txt", f"{slug}.pdf", f"{slug}.png", f"{slug}.svg", "manifest.json"}
    if set(want) == exp:
        ok(f"{slug}: the v3 block lists the five files")
    else:
        bad(f"{slug}: block set {sorted(want)} != expected")
    for name in sorted(want):
        got = md5b((d / name).read_bytes())
        (ok if got == want[name] else bad)(f"{slug}: v3 md5 {name}")

print("[4] no 'pending' byte in either caption file")
for slug in KITS:
    p = ROOT / f"docs/reporting/figures/{slug}/captions.md"
    (bad if "pending" in p.read_text() else ok)(f"{slug}: no pending byte")

print(f"\nchecks: {OK + FAIL}  ok: {OK}  fail: {FAIL}")
sys.exit(1 if FAIL else 0)
