#!/usr/bin/env python3
"""Fail if the report appendix names a commit that did not draw the plate,
or a register-row set the plate's manifest does not carry.

Seat: author. Written 2026-10-20 after commit d0e410d re-cut five plates and
moved none of their five appendix script-commit pins. The column is fully
determined by the figure kit manifests, so this check derives it rather than
trusting the table.

Both manifest shapes are read: a ``script_commit`` field, and the pin carried
in the build ``command`` as ``--script-commit <hash>``. A capture gallery
records no script commit, because its plate composes frames that an earlier
pass drew, so a third shape is read: ``run_commit``, the pass whose tree holds
every frame at the hash the stamp records. The cited-rows column is derived
the same way, from a top-level ``registers`` list (comma or interpunct
separated) or ``inputs.register_rows``, and compared as a set, so a row order
difference is not a failure but a missing or extra row is. A cell that carries
prose beside its rows is compared on its register ids alone, because a
sentence in that cell cites no row.

Usage:
    python3 scripts/check_appendix_pins.py [--draft PATH] [-q]
    python3 scripts/check_appendix_pins.py [--draft PATH] --fix

Exit 0 = every row matches its manifest on both the pin and the rows, and at
least one row was found.
Exit 1 = a stale pin, a stale rows cell, an unmapped row, a missing manifest,
or no rows parsed.

"No rows parsed" is a failure on purpose. A table check that passes on an
empty match set reports the health of the parser, not of the table.

--fix rewrites the pin token and the rows cell of each stale row from its
manifest and prints the manifest path it read. It writes nothing unless every row in the table
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
    "The power trend": "machine-power-trend",
    "The instrument gallery": "instrument-gallery",
    "Scaling ladder": "scaling-ladder",
}

ROW_RE = re.compile(
    r"^\| ([^|]+?) \| ([^|]*) \| ([^|]*) \| `([0-9a-f]{7})` \|$", re.M)

SEAT_RE = re.compile(r"\[Figure seated:(?P<body>.*?)\]", re.S)
SEAT_SLUG_RE = re.compile(r"slug `(?P<slug>[a-z0-9_-]+)`")

EMPTY_ROWS = {"", "none", "-", "—", "–", "n/a"}


def manifest_path(kit):
    return os.path.join(FIG, kit, "manifest.json")


def manifest_commit(kit):
    with open(manifest_path(kit)) as fh:
        m = json.load(fh)
    commit = m.get("script_commit")
    if commit:
        return commit
    hit = re.search(r"--script-commit ([0-9a-f]{7})", m.get("command", ""))
    if hit:
        return hit.group(1)
    return m.get("run_commit")


NR_RE = re.compile(r"NR-\d+")


def register_ids(parts):
    """The register ids in a split cell; prose beside them cites no row."""
    return {p for p in parts if NR_RE.fullmatch(p)}


def _split_rows(value):
    """Split a rows value on commas or the kit's interpunct separator.

    A manifest may carry the rows as a list, as one string, or as a list whose
    single element is itself interpunct-separated, so every element is split.
    """
    if isinstance(value, (list, tuple)):
        parts = []
        for v in value:
            parts.extend(re.split(r"[,·]", str(v or "")))
    else:
        parts = re.split(r"[,·]", str(value or ""))
    return [p.strip().upper() for p in parts
            if p.strip() and p.strip().lower() not in EMPTY_ROWS]


def manifest_rows(kit):
    """The register rows a kit's caption and appendix row must cite.

    Both manifest shapes are read, as for the pin: a top-level ``registers``
    list (or a string using the interpunct), and ``inputs.register_rows``.
    """
    with open(manifest_path(kit)) as fh:
        m = json.load(fh)
    rows = m.get("registers")
    if not rows:
        rows = m.get("inputs", {}).get("register_rows", [])
    return _split_rows(rows)


def draft_rows(cell):
    return _split_rows(cell)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--draft", default=DEFAULT_DRAFT, help="draft markdown to check")
    ap.add_argument("-q", "--quiet", action="store_true", help="print only failures")
    ap.add_argument("--fix", action="store_true",
                    help="rewrite stale pins and rows cells from the manifests (maintenance only)")
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
    edits = []          # (start, end, name, kind, old, new, kit)
    failed = set()
    for m in matches:
        name = m.group(1).strip()
        rows_cell = m.group(3)
        pin = m.group(4)
        kit = KIT.get(name)
        if kit is None:
            print(f"UNMAPPED  {name}")
            bad += 1
            failed.add(name)
            continue
        try:
            mc = manifest_commit(kit)
            mr = manifest_rows(kit)
        except (OSError, ValueError) as err:
            print(f"MISSING   {name:26s} pin {pin}  manifest unreadable: {err}")
            bad += 1
            failed.add(name)
            continue
        if mc is None:
            print(f"MISSING   {name:26s} pin {pin}  manifest records no script commit")
            bad += 1
            failed.add(name)
            continue
        if mc != pin:
            bad += 1
            failed.add(name)
            if args.fix:
                edits.append((m.start(4), m.end(4), name, "pin", pin, mc, kit))
            else:
                print(f"STALE     {name:26s} pin {pin}  manifest {mc}")
        drawn = register_ids(draft_rows(rows_cell))
        if drawn != set(mr):
            missing = [r for r in mr if r not in drawn]
            extra = [r for r in drawn if r not in mr]
            detail = ""
            if missing:
                detail += f"  missing {', '.join(missing)}"
            if extra:
                detail += f"  extra {', '.join(extra)}"
            if args.fix:
                failed.add(name)
                edits.append((m.start(3), m.end(3), name, "rows",
                              rows_cell.strip() or "none", ", ".join(mr) or "none", kit))
            else:
                print(f"ROWS      {name:26s} draft {rows_cell.strip() or 'none'}"
                      f"  manifest {', '.join(mr) or 'none'}{detail}")
                bad += 1
                failed.add(name)
        elif not args.fix and not (mc != pin) and not args.quiet:
            print(f"PASS      {name:26s} pin {pin}  rows {len(mr)}  manifest {mc}")

    # The seat marker carries the same cited-row set as prose in the draft, and
    # it drifted independently of the table: check it against the manifest too.
    seat_bad = 0
    for m in SEAT_RE.finditer(text):
        body = m.group("body")
        hit = SEAT_SLUG_RE.search(body)
        if hit is None:
            print("SEAT      a seat marker carries no slug")
            seat_bad += 1
            continue
        slug = hit.group("slug")
        seat = {r.upper() for r in re.findall(r"NR-\d+", body)}
        try:
            mr = manifest_rows(slug)
        except (OSError, ValueError) as err:
            print(f"SEAT      {slug:26s} manifest unreadable: {err}")
            seat_bad += 1
            continue
        if seat != set(mr):
            missing = [r for r in mr if r not in seat]
            extra = [r for r in seat if r not in mr]
            detail = ""
            if missing:
                detail += f"  missing {', '.join(missing)}"
            if extra:
                detail += f"  extra {', '.join(extra)}"
            print(f"SEAT      {slug:26s} marker cites {len(seat)} row(s), "
                  f"manifest {len(mr)}{detail}")
            seat_bad += 1
        elif not args.quiet and not args.fix:
            print(f"SEAT OK   {slug:26s} rows {len(mr)}")

    if seat_bad and args.fix:
        print(f"\nNOTE: {seat_bad} seat marker(s) disagree with their manifests; "
              f"the marker is prose, so --fix does not rewrite it", file=sys.stderr)
    bad += seat_bad

    if args.fix:
        if failed - {e[2] for e in edits}:
            for _, _, name, kind, old, new, _kit in edits:
                print(f"WOULD FIX {name:26s} {kind} {old}  -> {new}")
            print(f"\nrefusing to write: {len(failed - {e[2] for e in edits})} row(s) "
                  f"did not resolve", file=sys.stderr)
            return 1
        if not edits:
            print(f"\nnothing to fix; all {len(matches)} rows already match their manifests")
            return 0
        for start, end, name, kind, old, new, kit in sorted(edits, key=lambda e: e[0],
                                                           reverse=True):
            text = text[:start] + new + text[end:]
        for _, _, name, kind, old, new, kit in sorted(edits, key=lambda e: (e[2], e[3])):
            print(f"FIXED     {name:26s} {kind} {old} -> {new}  from "
                  f"{os.path.relpath(manifest_path(kit), ROOT)}")
        with open(draft, "w", newline="") as fh:
            fh.write(text)
        print(f"\n{len(edits)} cell(s) rewritten in {draft}")
        return 0

    print(f"\n{len(matches) - bad}/{len(matches)} rows pass")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
