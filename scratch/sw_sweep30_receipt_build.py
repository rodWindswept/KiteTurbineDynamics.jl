#!/usr/bin/env python3
# scratch/sw_sweep30_receipt_build.py — science-writer, 2026-10-15.
# Builds the sweep 30 receipt from the template with the landed hashes.
import sys

tpl = "scratch/sw_sweep30_receipt_template.md"
out = "docs/reporting/room-responses/science-writer-2026-10-15-sweep-30.md"
subs = {"%%EVID%%": "731cb96", "%%SEC%%": "75c2ac7", "%%HAND%%": "ceef96a"}

t = open(tpl, encoding="utf-8").read()
for k, v in subs.items():
    t = t.replace(k, v)
assert "%%" not in t, "placeholder survives the build"
for v in subs.values():
    assert v in t, f"{v} missing from the built receipt"
open(out, "w", encoding="utf-8").write(t)
print("built", out)
sys.exit(0)
