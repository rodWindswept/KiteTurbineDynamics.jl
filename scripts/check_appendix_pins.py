#!/usr/bin/env python3
"""Fail if the report appendix names a commit that did not draw the plate.

Seat: author. Written 2026-10-20 after commit d0e410d re-cut five plates and
moved none of their five appendix script-commit pins. The column is fully
determined by the figure kit manifests, so this check derives it rather than
trusting the table.

Both manifest shapes are read: a ``script_commit`` field, and the pin carried
in the build ``command`` as ``--script-commit <hash>``.

Usage:
    python3 scripts/check_appendix_pins.py [--draft PATH] [-q]

Exit 0 = every row matches its manifest, and at least one row was found.
Exit 1 = a stale or unmapped row, a missing manifest, or no rows parsed.

"No rows parsed" is a failure on purpose. A table check that passes on an
empty match set reports the health of the parser, not of the table.
"""
import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_DRAFT = os.path.join(ROOT, "docs/reporting/drafts/2026-10-08-report-first-draft.md")
FIG = os.path.join(ROOT, "docs/reporting/figures")

KIT = {
    "Ring utilisation plate": "ring-utilisation",
    "Twist limit plate": "twist-limit",
    "Machine evolution strip": "machine-evolution-strip",
    "System anatomy plate": "system-anatomy",
    "Levers landscape": "pca-landscape",
    "Parameter atlas": "pca-atlas",
    "Machine winner": "machine-winner-hero",
    "The corner machines": "machine-corner-grid",
    "Scaling ladder": "scaling-ladder",
}

ROW_RE = re.compile(r"^\| ([^|]+?) \| .*? \| .*? \| `([0-9a-f]{7})` \|$", re.M)


def manifest_commit(kit):
    path = os.path.join(FIG, kit, "manifest.json")
    with open(path) as fh:
        m = json.load(fh)
    commit = m.get("script_commit")
    if commit:
        return commit
    hit = re.search(r"--script-commit ([0-9a-f]{7})", m.get("command", ""))
    return hit.group(1) if hit else None


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--draft", default=DEFAULT_DRAFT, help="draft markdown to check")
    ap.add_argument("-q", "--quiet", action="store_true", help="print only failures")
    args = ap.parse_args()

    if not os.path.exists(args.draft):
        print(f"check_appendix_pins: no draft at {args.draft}", file=sys.stderr)
        return 1

    with open(args.draft) as fh:
        text = fh.read()

    rows = ROW_RE.findall(text)
    if not rows:
        print("check_appendix_pins: no appendix rows parsed — refusing to pass", file=sys.stderr)
        return 1

    bad = 0
    for name, pin in rows:
        kit = KIT.get(name.strip())
        if kit is None:
            print(f"UNMAPPED  {name.strip()}")
            bad += 1
            continue
        try:
            mc = manifest_commit(kit)
        except (OSError, ValueError) as err:
            print(f"MISSING   {name.strip():26s} pin {pin}  manifest unreadable: {err}")
            bad += 1
            continue
        if mc != pin:
            print(f"STALE     {name.strip():26s} pin {pin}  manifest {mc}")
            bad += 1
        elif not args.quiet:
            print(f"PASS      {name.strip():26s} pin {pin}  manifest {mc}")

    print(f"\n{len(rows) - bad}/{len(rows)} rows pass")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
