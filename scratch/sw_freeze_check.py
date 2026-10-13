#!/usr/bin/env python3
"""Freeze check: the two verified tables in the receipt must be byte-equal to the frozen sim strings."""
import pathlib

r = pathlib.Path('docs/reporting/room-responses/science-writer-2026-10-13-sweep-16-era-map.md').read_text()
era = pathlib.Path('scratch/sw_sw3b_era_table.md').read_text().rstrip("\n")
led = pathlib.Path('scratch/sw_ws3a_ledger_table.md').read_text().rstrip("\n")
n1, n2 = r.count(era), r.count(led)
assert n1 == 1 and n2 == 1, (n1, n2)
print("freeze check OK: both tables byte-equal, one occurrence each")
