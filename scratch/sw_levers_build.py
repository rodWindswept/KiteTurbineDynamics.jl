#!/usr/bin/env python3
"""Build the levers reading fold-sim and the token watch (science-writer, 2026-10-14).

Sim: apply the reading block to the committed v0.31 draft copy on the canonical
fold (section 3.4 bracket retired, block inserted after the two seat markers).
Tokens: the same regex the sweep scripts use, net and raw.
Read-only on the repo; writes scratch files only.
"""
import pathlib
import re
from collections import Counter

PAT = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")
repo = pathlib.Path.home() / "Documents/GitHub/KiteTurbineDynamics.jl"
scratch = repo / "scratch"

base = (scratch / "sw_sweep20_draft_v031.md").read_text()
block = (scratch / "sw_levers_reading_block.md").read_text().strip("\n")

old_heading = "### 3.4 The levers [PENDING. Landscape Phases 1 to 2 supply this section.]"
new_heading = "### 3.4 The levers"
assert base.count(old_heading) == 1, "heading not unique"
sim = base.replace(old_heading, new_heading)

row7 = "[Figure seated: figure-map row 7 (twist limit plate, slug `twist-limit`). Values cite NR-022 and NR-023.]"
assert sim.count(row7) == 1, "row7 marker not unique"
sim = sim.replace(row7, row7 + "\n\n" + block)

(scratch / "sw_levers_fold_sim.md").write_text(sim)
print("sim written:", (scratch / "sw_levers_fold_sim.md").stat().st_size, "bytes")

a, b = Counter(PAT.findall(base)), Counter(PAT.findall(sim))
arr = {k: b[k] - a.get(k, 0) for k in b if b[k] > a.get(k, 0)}
rem = {k: a[k] - b.get(k, 0) for k in a if a[k] > b.get(k, 0)}
print("net arrivals:", dict(sorted(arr.items())))
print("net removals:", dict(sorted(rem.items())))
print("block multiset:", dict(sorted(Counter(PAT.findall(block)).items())))
print("raw added occurrences (block):", sum(Counter(PAT.findall(block)).values()))
removed_raw = Counter(PAT.findall(old_heading)) - Counter(PAT.findall(new_heading))
print("raw removed occurrences (retired bracket):", sum(removed_raw.values()), dict(removed_raw))
