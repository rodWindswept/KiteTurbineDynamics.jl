#!/usr/bin/env python3
"""Census the internal apparatus each figure plate prints in its footer band.

Seat: figures. Written 2026-11-17, after the gate read 30 register-row ids in
the reader copy's text layer while the pages showed 55. A scan can only see
what its handle reaches: five seated plates print their band as vector text,
three draw it as glyph outlines, and one embeds it as pixels. No single layer
sees all of them.

This script counts the band on two handles and prints both, so the gap is
visible instead of assumed:

- ``plate`` reads each kit's PDF sibling with pdftotext. Every kit that draws
  text keeps text in its PDF, whatever its SVG font mode, so this is the
  census of what a reader sees.
- ``layer`` reads the ``<text>`` nodes of the SVG the PDF route embeds. That
  is the census of what a scan of the reader copy can see.

A kit with neither handle is raster. A raster kit that declares its stamps in
its manifest reports those as ``declared``, because a pixel band cannot be
counted and silence would read as zero.

Usage:
    python3 scripts/check_plate_footers.py [--slugs a,b] [--quiet]
    python3 scripts/check_plate_footers.py --appendix [DRAFT]
    python3 scripts/check_plate_footers.py --max-rows 0 --max-era 0 --max-hashes 0

Counts carry their measure in the column head: ``rows(occ)`` is occurrences,
``rows(dist)`` is distinct per plate, and ``layer(occ)`` is occurrences the
reader copy's text layer exposes. A sum of ``dist`` across plates is not a
union; the totals line prints the union separately, because the two agree only
while no appendix cell lists an id twice.

``--appendix`` compares each plate's distinct set with the register ids its
appendix cell prints, as sets, so a repeated id or a swapped id shows as a
mismatch instead of hiding inside matching totals.

Read the exit code directly, not through a pipe: ``cmd | tail`` reports the
status of ``tail``. Quote the direct invocation, or set ``pipefail``.

Exit 0 = every plate is inside the limits (default: no limit, census only).
Exit 1 = a plate exceeds a limit, or a raster plate carries no declared count.
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIG = os.path.join(ROOT, "docs/reporting/figures")
DEFAULT_DRAFT = os.path.join(
    ROOT, "docs/reporting/drafts/2026-10-08-report-first-draft.md")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_appendix_pins as cap  # noqa: E402  shared exhibit-to-kit map

ROW = re.compile(r"NR-\d+")
ERA = re.compile(r"post-[0-9a-f]{7}[A-Za-z_-]*")
HEX = re.compile(r"(?<![0-9A-Za-z_])[0-9a-f]{7,40}(?![0-9A-Za-z_])")


def hash_tokens(text):
    """Commit-like tokens: hex runs that carry at least one digit."""
    return {m.group(0) for m in HEX.finditer(text) if any(c.isdigit() for c in m.group(0))}


def census(text):
    return {"rows": set(ROW.findall(text)),
            "era": set(ERA.findall(text)),
            "hashes": hash_tokens(text),
            "n_rows": len(ROW.findall(text))}


def count(found, key: str) -> int:
    """Occurrences when the handle gives them, else distinct."""
    if not isinstance(found, dict):
        return 0
    if key == "rows" and "n_rows" in found:
        return int(found["n_rows"])
    return len(found.get(key) or ())


def pdf_text(paths):
    out = []
    for p in paths:
        res = subprocess.run(["pdftotext", "-layout", p, "-"],
                             capture_output=True, text=True)
        if res.returncode == 0:
            out.append(res.stdout)
    return "\n".join(out)


def svg_text(path):
    """The text nodes an SVG carries; empty when the font mode is paths."""
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            data = fh.read()
    except OSError:
        return ""
    nodes = re.findall(r">([^<>]{1,400})<", data)
    return "\n".join(n for n in nodes if n.strip())


def declared(man):
    """Stamp counts a raster kit records in its manifest, or None.

    A pixel band cannot be counted, so a raster kit states what its plate
    prints in a ``footer`` block. A gallery whose plate composes frames and
    prints no text states zeros, which is a claim a reader can check against
    the generator; an absent block is not read as zero.
    """
    block = man.get("footer")
    if isinstance(block, dict):
        return {"rows": block.get("rows") or [],
                "era": block.get("era") or [],
                "hashes": block.get("hashes") or [],
                "n_rows": int(block.get("row_count", 0))}
    panels = man.get("panels")
    if not isinstance(panels, list):
        return None
    rows, era, hashes = set(), set(), set()
    for p in panels:
        if not isinstance(p, dict):
            continue
        blob = " ".join(str(v) for v in p.values() if isinstance(v, str))
        rows |= set(ROW.findall(blob))
        era |= set(ERA.findall(blob))
        hashes |= hash_tokens(blob)
    return {"rows": rows, "era": era, "hashes": hashes}


def appendix_sets(path):
    """Exhibit label -> the register ids its appendix cell prints, or None."""
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
    except OSError:
        return None
    out = {}
    for m in cap.ROW_RE.finditer(text):
        out[m.group(1).strip()] = set(ROW.findall(m.group(3)))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--slugs", metavar="LIST", help="comma-separated kit slugs")
    ap.add_argument("--appendix", nargs="?", const=DEFAULT_DRAFT, metavar="DRAFT",
                    help="compare each plate's distinct row set with its appendix "
                         f"cell (default {os.path.relpath(DEFAULT_DRAFT, ROOT)})")
    ap.add_argument("--max-rows", type=int, default=None)
    ap.add_argument("--max-era", type=int, default=None)
    ap.add_argument("--max-hashes", type=int, default=None)
    ap.add_argument("-q", "--quiet", action="store_true")
    args = ap.parse_args()

    kits = sorted(glob.glob(os.path.join(FIG, "*", "manifest.json")))
    if args.slugs:
        want = {s.strip() for s in args.slugs.split(",") if s.strip()}
        kits = [k for k in kits if os.path.basename(os.path.dirname(k)) in want]
        missing = want - {os.path.basename(os.path.dirname(k)) for k in kits}
        if missing:
            print(f"check_plate_footers: no manifest for {', '.join(sorted(missing))}",
                  file=sys.stderr)
            return 1
    if not kits:
        print("check_plate_footers: no kit found", file=sys.stderr)
        return 1

    head = (f"{'kit':26s} {'plate':6s} {'layer':6s} "
            f"{'rows(occ)':>9s} {'rows(dist)':>10s} {'layer(occ)':>10s} "
            f"{'era':>4s} {'hash':>5s}")
    lines = [head]
    over = 0
    tot = {"rows_occ": 0, "rows_dist": 0, "layer_occ": 0, "era": 0, "hash": 0}
    plate_sets = {}
    for path in kits:
        kit = os.path.dirname(path)
        slug = os.path.basename(kit)
        with open(path, encoding="utf-8") as fh:
            man = json.load(fh)

        pdfs = sorted(glob.glob(os.path.join(kit, "*.pdf")))
        svgs = sorted(glob.glob(os.path.join(kit, "*.svg")))
        plate = census(pdf_text(pdfs)) if pdfs else None
        layer = census("\n".join(svg_text(s) for s in svgs)) if svgs else None

        handle = "pdf" if pdfs else ("svg" if svgs else "raster")
        if plate is None and layer is None:
            plate = declared(man)
            handle = "raster" if plate is not None else "none"
        shown = plate if plate is not None else layer
        seen = count(layer, "rows") if layer is not None else 0
        if shown is None:
            lines.append(f"{slug:26s} {'none':6s} {'-':6s} "
                         f"{'?':>5s} {'?':>5s} {'?':>5s} {'?':>4s} {'?':>5s}")
            over += 1
            continue

        counts = {k: count(shown, k) for k in ("rows", "era", "hashes")}
        distinct = len(shown["rows"])
        plate_sets[slug] = set(shown["rows"])
        tot["rows_occ"] += counts["rows"]
        tot["rows_dist"] += distinct
        tot["layer_occ"] += seen
        tot["era"] += counts["era"]
        tot["hash"] += counts["hashes"]
        bad = ((args.max_rows is not None and counts["rows"] > args.max_rows)
               or (args.max_era is not None and counts["era"] > args.max_era)
               or (args.max_hashes is not None and counts["hashes"] > args.max_hashes))
        over += 1 if bad else 0
        lines.append(f"{slug:26s} {handle:6s} "
                     f"{('svg' if svgs else 'png'):6s} "
                     f"{counts['rows']:9d} {distinct:10d} {seen:10d} "
                     f"{counts['era']:4d} {counts['hashes']:5d}"
                     + ("   OVER" if bad else ""))

    if not args.quiet:
        for line in lines:
            print(line)
        print(f"\ntotals: {tot['rows_occ']} row-id occurrences on the plates, "
              f"{tot['layer_occ']} searchable in the layer, "
              f"{tot['rows_dist']} distinct ids summed per plate, "
              f"{len(set().union(*plate_sets.values())) if plate_sets else 0} "
              f"distinct ids in union, "
              f"{tot['era']} era tags, {tot['hash']} commit-like tokens")
        print("occ = occurrences; dist = distinct per plate, so a sum of dist "
              "is not a union across plates")

    mismatch = 0
    if args.appendix:
        cells = appendix_sets(args.appendix)
        if cells is None:
            print(f"check_plate_footers: cannot read {args.appendix}", file=sys.stderr)
            return 1
        print("\nexhibit vs appendix cell, compared as sets:")
        compared = 0
        for label, slug in cap.KIT.items():
            if label not in cells or slug not in plate_sets:
                continue
            cell, plate = cells[label], plate_sets[slug]
            if not cell:
                print(f"  none  {slug:26s} cell prints no rows; plate prints "
                      f"{len(plate)} distinct")
                compared += 1
                continue
            ok = cell == plate
            mismatch += 0 if ok else 1
            compared += 1
            print(f"  {'OK  ' if ok else 'DIFF'}  {slug:26s} appendix {len(cell):2d}, "
                  f"plate {len(plate):2d}"
                  + ("" if ok else f"; only appendix {sorted(cell - plate)}, "
                                   f"only plate {sorted(plate - cell)}"))
        print(f"  {compared} exhibit(s) compared, {mismatch} set mismatch(es)")
        if compared == 0:
            print("check_plate_footers: the appendix comparison matched no exhibit, "
                  "so it proved nothing - refusing to pass", file=sys.stderr)
            return 1

    if over or mismatch:
        print(f"check_plate_footers: {over} kit(s) outside the limit, "
              f"{mismatch} appendix mismatch(es)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
