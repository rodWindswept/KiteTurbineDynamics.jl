#!/usr/bin/env python3
"""Build the sweep 26 receipt from the template (science-writer, 2026-10-14).

Usage: python3 sw_sweep26_receipt_build.py <evidence> <sweep> <handover>
"""
import pathlib
import sys

repo = pathlib.Path.home() / "Documents/GitHub/KiteTurbineDynamics.jl"
if len(sys.argv) != 4:
    sys.exit("usage: build.py <evidence> <sweep> <handover>")
ev, sw, ho = sys.argv[1:4]
tmpl = (repo / "scratch/sw_sweep26_receipt_template.md").read_text()
for k in ("%%EVIDENCE%%", "%%SWEEP%%", "%%HANDOVER%%"):
    assert tmpl.count(k) == 1, k
out = (tmpl.replace("%%EVIDENCE%%", ev)
           .replace("%%SWEEP%%", sw)
           .replace("%%HANDOVER%%", ho))
assert "%%" not in out, "placeholder survives"
dest = repo / "docs/reporting/room-responses/science-writer-2026-10-14-sweep-26.md"
dest.write_text(out)
print("receipt written:", dest.name)
