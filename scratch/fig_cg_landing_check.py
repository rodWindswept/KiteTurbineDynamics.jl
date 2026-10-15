#!/usr/bin/env python3
"""fig corner-grid landing check: reads back the map cells and delta,
the SPEC D10, the kit records, the delivered set, the repro table, the
seat page and the receipt.

Run: /usr/bin/python3 scratch/fig_cg_landing_check.py    (repo root)
"""
import hashlib
import json
import sys
from pathlib import Path

MAP = Path("docs/reporting/figures/figure-map.md")
SPEC = Path("docs/reporting/figures/machine-renderer/SPEC.md")
KIT = Path("docs/reporting/figures/machine-corner-grid")
SEAT = Path("handovers/handover-2026-10-14-reporting-room-figures-images-diagrams.md")
RECEIPT = Path("docs/reporting/room-responses/"
               "figures-images-diagrams-2026-10-15-corner-grid-generator.md")
REPRO = Path("scratch/fig_cg_repro.md5")

n = 0
fails = []


def chk(name, good):
    global n
    n += 1
    if not good:
        fails.append(name)
    print(f"  {'OK ' if good else 'FAIL'}  {name}")


mt = MAP.read_text()
chk("map: row 23 reads R2", "`machine-corner-grid` | R2 |" in mt)
chk("map: row 23 source names the extract",
    "The extract `corner-grid-extract-2026-10-15-picks` (`92ca9f5`)" in mt)
chk("map: row 23 records the build landing",
    "The build lands (`a4b4057`)" in mt)
chk("map: delta v39 present", "- **v39 (2026-10-15):**" in mt)
chk("map: delta v38 still present", "- **v38 (2026-10-15):**" in mt)
chk("map: v39 reads the byte-identical trio",
    "plus twice into scratch reads byte-identical across all five" in mt)

st = SPEC.read_text()
chk("spec: D10 present", "**D10 (2026-10-15):**" in st)
chk("spec: D10 reads the family mode",
    "the corner grid runs the family mode with" in st)
chk("spec: D10 reads the -dg/-zg normalise", "-dg/-zg PDF normalise" in st)

rt = (KIT / "README.md").read_text()
chk("readme: the landing reads", "The generator lands (`a4b4057`)" in rt)
chk("readme: the delivered files section", "## Delivered files" in rt)

ct = (KIT / "captions.md").read_text()
chk("captions: plain tier", "## Plain caption" in ct)
chk("captions: technical tier", "## Technical caption (undergrad register, STE-clean form)" in ct)
chk("captions: provenance line", "## Provenance line" in ct)
chk("captions: script commit a4b4057", "script commit `a4b4057`" in ct)
chk("captions: objective forms", all(v in ct for v in ["60.646", "58.864", "33.704", "33.812"]))

gt = (KIT / "register-status.md").read_text()
chk("register: NR-044 cited", "NR-044" in gt)
chk("register: NR-051 cited", "NR-051" in gt)
chk("register: script commit", "`a4b4057`" in gt)
chk("register: the three-location walk", "three locations stay byte-identical" in gt)

for f in ["machine-corner-grid.png", "machine-corner-grid.svg",
          "machine-corner-grid.pdf", "manifest.json", "checks.log"]:
    chk(f"kit: {f} exists", (KIT / f).exists())
man = json.loads((KIT / "manifest.json").read_text())
chk("manifest: family mode, corner variant",
    man["mode"] == "family" and man["variant"] == "corner-grid")
chk("manifest: registers NR-044 + NR-051", man["registers"] == ["NR-044", "NR-051"])
chk("manifest: picks in the signed order",
    man["selection"]["picks"] == ["i1-g13-i1", "i1-g7-i7", "i2-g21-i4", "i3-g26-i8"])
chk("manifest: script commit a4b4057", man["script_commit"] == "a4b4057")
chk("manifest: four outputs pinned", len(man["outputs"]) == 4)
cl = (KIT / "checks.log").read_text()
chk("checks: ALL OK", "checks: ALL OK" in cl)
chk("checks: corner order OK", "corner order (NR-051): OK" in cl)
chk("checks: -dg normalise", "clean -dg ok" in cl)
ext = KIT / "extract-corner-grid.csv"
sha = hashlib.sha256(ext.read_bytes()).hexdigest()
chk("extract: byte-unchanged (03abd0c6…)",
    sha == "03abd0c660e0ad22db89f767a7b033c18db82f67dde69593c31cbb3a3919a4d5")

rp = REPRO.read_text()
chk("repro: all-equal result", "RESULT: all five outputs byte-identical across the three locations" in rp)
chk("repro: stamped a4b4057", "script commit a4b4057" in rp)

sp = SEAT.read_text()
chk("seat: item 1 reads the landing", "The generator lands (`a4b4057`)" in sp)
chk("seat: closed index gains the build",
    "The corner grid builds (2026-10-15): the generator lands at `a4b4057`" in sp)
chk("seat: next action reads the counter-reads",
    "**Next action:** the corner-grid counter-reads (row 23) on the delivered bytes." in sp)

chk("receipt exists", RECEIPT.exists())
if RECEIPT.exists():
    rec = RECEIPT.read_text()
    chk("receipt: carries the script commit", "a4b4057" in rec)
    chk("receipt: carries the repro line", "byte-identical" in rec)
    chk("receipt: carries the F-CITE handoff", "F-CITE" in rec)

print(f"\nchecks: {n}, fail: {len(fails)}")
for f in fails:
    print("FAILED:", f)
sys.exit(0 if not fails else 1)
