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
    python3 scripts/check_plate_footers.py --max-rows 0 --max-era 0 --max-hashes 0

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


def count(found, key):
    """Occurrences when the handle gives them, else distinct."""
    if isinstance(found, dict) and "n_rows" in found and key == "rows":
        return found["n_rows"]
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


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--slugs", metavar="LIST", help="comma-separated kit slugs")
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
            f"{'rows':>5s} {'dist':>5s} {'sees':>5s} {'era':>4s} {'hash':>5s}")
    lines = [head]
    over = 0
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
        bad = ((args.max_rows is not None and counts["rows"] > args.max_rows)
               or (args.max_era is not None and counts["era"] > args.max_era)
               or (args.max_hashes is not None and counts["hashes"] > args.max_hashes))
        over += 1 if bad else 0
        lines.append(f"{slug:26s} {handle:6s} "
                     f"{('svg' if svgs else 'png'):6s} "
                     f"{counts['rows']:5d} {distinct:5d} {seen:5d} "
                     f"{counts['era']:4d} {counts['hashes']:5d}"
                     + ("   OVER" if bad else ""))

    if not args.quiet:
        for line in lines:
            print(line)
        print("\nplate = what the drawn page prints; sees = what the reader copy's "
              "text layer exposes")
    if over:
        print(f"check_plate_footers: {over} kit(s) outside the limit", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
