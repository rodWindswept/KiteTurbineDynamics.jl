#!/usr/bin/env python3
"""Recompute every appendix output-hash cell against the delivered kit files.

Usage: python3 pins-check.py <repo-root> <draft-file>

Read-only. <draft-file> is any revision of the draft markdown (a `git show`
extract, the sim, or the live file). Parses the 'Output hashes (SHA-256)'
block of the figure-provenance appendix: per-exhibit `Title:` headings, then
`- `label` `hash`` rows, and recomputes each cell from the kit files. Run it
for the sweep's pins check: a stale pin passes every row check and only shows
on the bytes.

Label map: png/svg/pdf -> <slug>.<ext> in the kit dir; ledger -> the kit's
*ledger* file (label-ledger.txt); checks -> checks.log. The exhibit-title to
kit-dir map sits in EX; a heading outside EX reads loud, so a newly seated
exhibit takes its EX row before the run is trusted.

Exit 0 when every cell matches and no heading is unknown; 1 otherwise.
"""
import hashlib
import pathlib
import re
import sys

EX = {  # exhibit title -> (kit dir under docs/reporting/figures, slug stem)
    "Ring utilisation plate": ("ring-utilisation", "ring-utilisation"),
    "Twist limit plate": ("twist-limit", "twist-limit"),
    "Machine evolution strip": ("machine-evolution-strip", "machine-evolution-strip"),
    "System anatomy plate": ("system-anatomy", "system-anatomy"),
    "Levers landscape": ("pca-landscape", "pca-landscape"),
    "Parameter atlas": ("pca-atlas", "pca-atlas"),
    "Machine winner hero": ("machine-winner-hero", "machine-winner-hero"),
    # the 2026-10-15 winner-form rename: the appendix heading reads "Machine winner"
    "Machine winner": ("machine-winner-hero", "machine-winner-hero"),
    # the 2026-10-15 corner-machines fold: the eighth exhibit, four cells (png, svg, pdf, checks)
    "The corner machines": ("machine-corner-grid", "machine-corner-grid"),
}


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    repo = pathlib.Path(sys.argv[1])
    draft = pathlib.Path(sys.argv[2]).read_text()
    marker = "**Output hashes (SHA-256).**"
    if marker not in draft:
        sys.exit("pins-check: no output-hashes block in the draft file")
    block = draft.split(marker, 1)[1]
    stop = re.search(r"\n## ", block)
    if stop:
        block = block[: stop.start()]
    chunks = re.split(r"\n(?=\S[^\n]*:\n)", block)
    total = ok = 0
    unknown = []
    for ch in chunks:
        m = re.match(r"(\S[^\n]*):\n", ch)
        if not m:
            continue
        title = m.group(1).strip().rstrip(":")
        if title not in EX:
            unknown.append(title)
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
                print(f"  UNKNOWN label {title} [{lab}]")
                continue
            if not f.exists():
                print(f"  MISSING {title} [{lab}]: {f}")
                continue
            got = hashlib.sha256(f.read_bytes()).hexdigest()
            match = got == hx
            ok += match
            print(f"  {title} [{lab}]: {'MATCH' if match else 'MISMATCH'} "
                  f"{got[:8]} vs cell {hx[:8]}")
    for title in unknown:
        print(f"  UNKNOWN exhibit heading: {title!r} — add its EX row")
    print(f"pins recomputed: {total}, match: {ok}, mismatch: {total - ok}")
    sys.exit(0 if total and ok == total and not unknown else 1)


if __name__ == "__main__":
    main()
