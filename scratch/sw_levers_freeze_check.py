#!/usr/bin/env python3
"""Freeze check: the levers reading block — receipt copy vs sim region (2026-10-14).

Asserts: the block in the receipt (between the markers) is byte-identical to
scratch/sw_levers_reading_block.md, and the sim carries the block exactly once.
Read-only.
"""
import pathlib
import sys

repo = pathlib.Path.home() / "Documents/GitHub/KiteTurbineDynamics.jl"
block = (repo / "scratch/sw_levers_reading_block.md").read_text().strip("\n")
receipt = (repo / "docs/reporting/room-responses/science-writer-2026-10-14-levers-reading.md").read_text()
B, E = "<!-- LEVERS-READING-START -->", "<!-- LEVERS-READING-END -->"
assert receipt.count(B) == 1 and receipt.count(E) == 1, "marker count"
seg = receipt.split(B, 1)[1].split(E, 1)[0].strip("\n")
sim = (repo / "scratch/sw_levers_fold_sim.md").read_text()
print("block bytes:", len(block))
print("receipt region == block:", seg == block)
print("sim contains block once:", sim.count(block) == 1)
sys.exit(0 if (seg == block and sim.count(block) == 1) else 1)
