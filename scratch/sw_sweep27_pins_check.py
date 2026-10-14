#!/usr/bin/env python3
"""Sweep 27 pins check: every appendix output-hash cell against the delivered
files (2026-10-14, read-only).

Parses the 'Output hashes (SHA-256)' block of the v0.41 draft extract and
recomputes each label's file. Labels: png, svg, pdf, ledger, checks.
"""
import hashlib
import pathlib
import re

repo = pathlib.Path(".")
draft = (repo / "scratch/sw_sweep27_draft_v041.md").read_text()

# exhibit title -> (kit dir, slug stem)
EX = {
    "Ring utilisation plate": ("ring-utilisation", "ring-utilisation"),
    "Twist limit plate": ("twist-limit", "twist-limit"),
    "Machine evolution strip": ("machine-evolution-strip", "machine-evolution-strip"),
    "System anatomy plate": ("system-anatomy", "system-anatomy"),
    "Levers landscape": ("pca-landscape", "pca-landscape"),
    "Parameter atlas": ("pca-atlas", "pca-atlas"),
    "Machine winner hero": ("machine-winner-hero", "machine-winner-hero"),
}

block = draft.split("**Output hashes (SHA-256).**", 1)[1]
block = block.split("## Document control", 1)[0]
# split into per-exhibit chunks: 'Title:' headings
chunks = re.split(r"\n(?=\S[^\n]*:\n)", block)
results = []
total = 0
ok = 0
for ch in chunks:
    m = re.match(r"(\S[^\n]*):\n", ch)
    if not m:
        continue
    title = m.group(1).strip().rstrip(":")
    if title not in EX:
        print("  (skip heading)", title)
        continue
    kitdir, stem = EX[title]
    d = repo / "docs/reporting/figures" / kitdir
    for lab, hx in re.findall(r"^- `(\w+)` `([0-9a-f]{64})`$", ch, re.M):
        total += 1
        if lab in ("png", "svg", "pdf"):
            f = d / f"{stem}.{lab}"
        elif lab == "ledger":
            cands = sorted(d.glob("*ledger*"))
            f = cands[0] if cands else d / "label-ledger.txt"
        elif lab == "checks":
            f = d / "checks.log"
        else:
            f = d / "unknown"
        if not f.exists():
            print(f"  MISSING {title} {lab}: {f}")
            continue
        got = hashlib.sha256(f.read_bytes()).hexdigest()
        match = got == hx
        ok += match
        results.append((title, lab, str(f), match, got[:8], hx[:8]))
for title, lab, f, match, g8, h8 in results:
    print(f"  {title} [{lab}]: {'MATCH' if match else 'MISMATCH'} {g8} vs cell {h8}")
print(f"pins recomputed: {total}, match: {ok}, mismatch: {total - ok}")
