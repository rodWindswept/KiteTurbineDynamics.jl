#!/usr/bin/env python3
"""Build the levers reading receipt from the template (science-writer, 2026-10-14)."""
import hashlib
import pathlib

repo = pathlib.Path.home() / "Documents/GitHub/KiteTurbineDynamics.jl"
block = (repo / "scratch/sw_levers_reading_block.md").read_text()
sim = (repo / "scratch/sw_levers_fold_sim.md").read_text()
tmpl = (repo / "scratch/sw_levers_receipt_template.md").read_text()
assert tmpl.count("%%BLOCK%%") == 1, "block placeholder"
tmpl = tmpl.replace("%%BLOCK%%", block.rstrip("\n"))
bm = hashlib.md5(block.encode()).hexdigest()
sm = hashlib.md5(sim.encode()).hexdigest()
assert tmpl.count("%%BLOCKMD5%%") == 1 and tmpl.count("%%SIMMD5%%") == 1, "md5 placeholders"
tmpl = tmpl.replace("%%BLOCKMD5%%", bm).replace("%%SIMMD5%%", sm)
out = repo / "docs/reporting/room-responses/science-writer-2026-10-14-levers-reading.md"
out.write_text(tmpl)
print("receipt written:", out.name, "| block md5", bm, "| sim md5", sm)
