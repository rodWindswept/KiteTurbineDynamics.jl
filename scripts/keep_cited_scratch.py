#!/usr/bin/env python3
"""Extract every scratch/ path a signed or landed record cites.

The room rule: nothing cited by a signed row is deleted. This script
scans the register, the draft and the receipts for scratch/ citations
and writes the keep list. Run it before any scratch cleanup.

Usage: python3 scripts/keep_cited_scratch.py
Output: scratch/keep-list.txt plus a one-line count on stdout.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = [
    ROOT / "docs/reporting/numbers-register.md",
    ROOT / "docs/reporting/drafts",
    ROOT / "docs/reporting/room-responses",
    ROOT / "docs/reporting/feedback",
    ROOT / "handovers",
]

PATTERN = re.compile(r"scratch/[A-Za-z0-9_./\-]+")

def collect():
    paths = set()
    for src in SOURCES:
        files = [src] if src.is_file() else list(src.rglob("*.md"))
        for f in files:
            try:
                text = f.read_text(errors="replace")
            except OSError:
                continue
            for m in PATTERN.finditer(text):
                paths.add(m.group(0).rstrip("."))
    return sorted(paths)

def main():
    paths = collect()
    out = ROOT / "scratch" / "keep-list.txt"
    out.write_text("\n".join(paths) + "\n")
    print(f"keep-list: {len(paths)} scratch paths cited, written to {out.relative_to(ROOT)}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
