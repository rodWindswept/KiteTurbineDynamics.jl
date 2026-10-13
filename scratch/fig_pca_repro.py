#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""Repro check: the pca-landscape and pca-atlas kits at commit A.

Runs each generator a second time, at the same stamp, into a scratch
directory and compares sha256 for all five outputs against the kit
files.  Writes the log to scratch/fig_pca_repro.log.

Run: /usr/bin/python3 scratch/fig_pca_repro.py
"""
import hashlib
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
A = "3d36c7a"
FILES = ["{slug}.svg", "{slug}.pdf", "{slug}.png", "label-ledger.txt",
         "manifest.json"]

KITS = ["pca-landscape", "pca-atlas"]

def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()

def main() -> int:
    lines = []
    rc_all = 0
    for slug in KITS:
        kit = REPO / "docs/reporting/figures" / slug
        tmp = REPO / "scratch" / f"fig_pca_repro_{slug}"
        if tmp.exists():
            shutil.rmtree(tmp)
        tmp.mkdir(parents=True)
        r = subprocess.run(
            ["/usr/bin/python3", str(kit / f"{slug}.py"),
             "--script-commit", A, "--outdir", str(tmp)],
            capture_output=True, text=True, cwd=REPO)
        lines.append(f"== {slug}: rerun rc={r.returncode}")
        for f in FILES:
            name = f.format(slug=slug)
            a = sha(kit / name)
            b = sha(tmp / name)
            ok = a == b
            rc_all |= 0 if ok else 1
            lines.append(f"  {name:22s} {'IDENTICAL' if ok else 'DIFF'}  {a[:16]}")
    log = "\n".join(lines) + "\n"
    (REPO / "scratch/fig_pca_repro.log").write_text(log)
    print(log)
    return rc_all

if __name__ == "__main__":
    sys.exit(main())
