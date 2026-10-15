#!/usr/bin/env python3
"""fig_et_pl_driver: the placement re-cut F-REPRO walk.

Runs the eval-timeline generator in place and twice into scratch outdirs,
all at one --script-commit stamp (the commit-A hex passed in). Writes the
per-run logs and the filename-first md5 table (five outputs x three
locations, 15 hashes) to scratch/. Asserts every output byte-identical
across the three locations.
"""
import hashlib
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
A = sys.argv[1] if len(sys.argv) > 1 else ""
assert A and A != "precheck", "pass the commit-A hash"

GEN = ROOT / "docs" / "reporting" / "figures" / "eval-timeline" / "eval-timeline.py"
KIT = ROOT / "docs" / "reporting" / "figures" / "eval-timeline"
D1 = KIT
D2 = ROOT / "scratch" / "fig_et_pl_repro1"
D3 = ROOT / "scratch" / "fig_et_pl_repro2"
OUTS = ["eval-timeline.svg", "eval-timeline.pdf", "eval-timeline.png",
        "label-ledger.txt", "manifest.json"]

for d in (D2, D3):
    d.mkdir(parents=True, exist_ok=True)

runs = [
    ("in_place", D1, ROOT / "scratch" / "fig_et_pl_run1.log"),
    ("repro1", D2, ROOT / "scratch" / "fig_et_pl_run2.log"),
    ("repro2", D3, ROOT / "scratch" / "fig_et_pl_run3.log"),
]
for name, outdir, log in runs:
    cmd = ["/usr/bin/python3", str(GEN), "--outdir", str(outdir),
           "--script-commit", A]
    with log.open("w") as fh:
        r = subprocess.run(cmd, stdout=fh, stderr=subprocess.STDOUT)
    assert r.returncode == 0, f"{name}: rc={r.returncode}"
    print(f"{name}: rc=0  (log {log.name})")

rows = []
for f in OUTS:
    h1 = hashlib.md5((D1 / f).read_bytes()).hexdigest()
    h2 = hashlib.md5((D2 / f).read_bytes()).hexdigest()
    h3 = hashlib.md5((D3 / f).read_bytes()).hexdigest()
    ok = h1 == h2 == h3
    rows.append((f, h1))
    print(f"{f}: {h1} {'MATCH' if ok else 'DRIFT ' + h2 + ' / ' + h3}")
    assert ok, f"drift on {f}"

table = ROOT / "scratch" / "fig_et_pl_repro.md5"
table.write_text("".join(f"{h}  {f}\n" for f, h in rows), encoding="utf-8")
print(f"repro table: {table.relative_to(ROOT)}  (15 hashes, all equal)")
