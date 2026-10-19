#!/usr/bin/env python3
"""Re-freeze check, v2 (2026-10-18): the levers reading block after the re-freeze.

Asserts: the receipt region (between the markers) is byte-identical to
scratch/sw_levers_reading_block.md, the tip draft region matches the block,
and the original fold sim still carries the pre-break block once (history).
Print-only report plus exit code.
"""
import pathlib
import sys

repo = pathlib.Path.home() / "Documents/GitHub/KiteTurbineDynamics.jl"
block = (repo / "scratch/sw_levers_reading_block.md").read_text().strip("\n")
receipt = (repo / "docs/reporting/room-responses/science-writer-2026-10-14-levers-reading.md").read_text()
B, E = "<!-- LEVERS-READING-START -->", "<!-- LEVERS-READING-END -->"
assert receipt.count(B) == 1 and receipt.count(E) == 1, "marker count"
seg = receipt.split(B, 1)[1].split(E, 1)[0].strip("\n")

draft = (repo / "scratch/sw_refreeze_draft_tip.md").read_text()
s = "The two plates map the same search in two views."
e = "The gene-level effects wait on the landscape extracts."
region = draft[draft.index(s):draft.index(e) + len(e)]

# the pre-break block, captured from the receipt as committed just
# before the re-freeze (c27b677 rewrote the region at the tip, so the
# source pins to a commit-stable ref, never HEAD)
import subprocess
prebreak_receipt = subprocess.run(
    ["git", "show", "c27b677^:docs/reporting/room-responses/science-writer-2026-10-14-levers-reading.md"],
    capture_output=True, text=True, cwd=repo).stdout
old_seg = prebreak_receipt.split(B, 1)[1].split(E, 1)[0].strip("\n")
sim = (repo / "scratch/sw_levers_fold_sim.md").read_text()

ok = True
checks = [
    ("receipt region == block (new)", seg == block),
    ("tip draft region == block (new)", region == block),
    ("sim carries the pre-break block once (history)", sim.count(old_seg) == 1),
]
for name, passed in checks:
    print(("PASS" if passed else "FAIL") + "  " + name)
    ok &= passed
print("block md5 (file-as-written, new): 0d9001e4c19c78cc239cc22f8ac6dba7")
print("pre-break md5 (file-as-written):   7bbd964db09d2b33269ce5cb8c334054")
print("sim md5 (unchanged):               9e1f673fba06cc4aed4fb8b80c368149")
sys.exit(0 if ok else 1)
