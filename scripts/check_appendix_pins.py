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
    python3 scripts/check_appendix_pins.py [--draft PATH] --fix

Exit 0 = every row matches its manifest, and at least one row was found.
Exit 1 = a stale or unmapped row, a missing manifest, or no rows parsed.

"No rows parsed" is a failure on purpose. A table check that passes on an
empty match set reports the health of the parser, not of the table.

--fix rewrites the pin token of each stale row from its manifest and prints
the manifest path it read. It writes nothing unless every row in the table
resolved, because a partial fix leaves a draft where an auditor cannot tell
which rows were checked. It is a maintenance verb, never a build step: the
gate only ever checks. A fix makes the column agree with the manifests; it
does not verify the manifests against the plate bytes. That is the job of the
output hashes each manifest records.
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


def manifest_path(kit):
    return os.path.join(FIG, kit, "manifest.json")


def manifest_commit(kit):
    with open(manifest_path(kit)) as fh:
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
    ap.add_argument("--fix", action="store_true",
                    help="rewrite stale pins from the manifests (maintenance only)")
    args = ap.parse_args()

    draft = os.path.abspath(args.draft)
    if not os.path.exists(draft):
        print(f"check_appendix_pins: no draft at {draft}", file=sys.stderr)
        return 1

    with open(draft, newline="") as fh:
        text = fh.read()

    matches = list(ROW_RE.finditer(text))
    if not matches:
        print("check_appendix_pins: no appendix rows parsed — refusing to pass", file=sys.stderr)
        return 1

    bad = 0
    edits = []
    for m in matches:
        name = m.group(1).strip()
        pin = m.group(2)
        kit = KIT.get(name)
        if kit is None:
            print(f"UNMAPPED  {name}")
            bad += 1
            continue
        try:
            mc = manifest_commit(kit)
        except (OSError, ValueError) as err:
            print(f"MISSING   {name:26s} pin {pin}  manifest unreadable: {err}")
            bad += 1
            continue
        if mc is None:
            print(f"MISSING   {name:26s} pin {pin}  manifest records no script commit")
            bad += 1
            continue
        if mc != pin:
            bad += 1
            if args.fix:
                edits.append((m.start(2), m.end(2), name, pin, mc, kit))
            else:
                print(f"STALE     {name:26s} pin {pin}  manifest {mc}")
        elif not args.quiet and not args.fix:
            print(f"PASS      {name:26s} pin {pin}  manifest {mc}")

    if args.fix:
        if bad and len(edits) != bad:
            for _, _, name, pin, mc, _kit in edits:
                print(f"WOULD FIX {name:26s} pin {pin}  manifest {mc}")
            print(f"\nrefusing to write: {bad - len(edits)} row(s) did not resolve",
                  file=sys.stderr)
            return 1
        if not edits:
            print(f"\nnothing to fix; all {len(matches)} rows already match their manifests")
            return 0
        for start, end, name, pin, mc, kit in sorted(edits, key=lambda e: e[0], reverse=True):
            text = text[:start] + mc + text[end:]
        for _, _, name, pin, mc, kit in sorted(edits, key=lambda e: e[2]):
            print(f"FIXED     {name:26s} pin {pin} -> {mc}  from "
                  f"{os.path.relpath(manifest_path(kit), ROOT)}")
        with open(draft, "w", newline="") as fh:
            fh.write(text)
        print(f"\n{len(edits)} pin(s) rewritten in {draft}")
        return 0

    print(f"\n{len(matches) - bad}/{len(matches)} rows pass")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
