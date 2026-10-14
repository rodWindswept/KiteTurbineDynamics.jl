#!/usr/bin/env python3
"""fig-sa v5 run driver — one full chain run (generator + pdflatex + pdftoppm).

Usage: python3 scratch/fig_sa_v5_driver.py <run-label>   (from the repo root)
Prints the run log block (redirect to scratch/fig_sa_v5_run<label>.log).
Writes scratch/fig_sa_v5_run<label>.md5 (md5) — sha256 printed for the manifest.
"""
import hashlib
import os
import re
import subprocess
import sys
from pathlib import Path

run = sys.argv[1] if len(sys.argv) > 1 else "1"
ROOT = Path("docs/reporting/figures/system-anatomy")
OUTS = ["system-anatomy.tex", "prototype.html", "label-ledger.txt",
        "system-anatomy.pdf", "system-anatomy.png"]

os.chdir(ROOT)

gen = subprocess.run(["/usr/bin/python3", "system-anatomy.py"],
                     capture_output=True, text=True)
print(f"fig-sa v5 (cone ring) — run {run}")
print("state: system-anatomy.py @ the committed script (v5)")
print()
print("== generator ==")
print(gen.stdout.strip())
print(f"generator exit={gen.returncode}")
if gen.stderr.strip():
    print("generator stderr:", gen.stderr.strip())

env = dict(os.environ, SOURCE_DATE_EPOCH="0", FORCE_SOURCE_DATE="1")
tex = subprocess.run(["pdflatex", "-interaction=nonstopmode", "system-anatomy.tex"],
                     capture_output=True, text=True, env=env)
log = Path("system-anatomy.log").read_text(errors="replace")
err_lines = len(re.findall(r"^!", log, flags=re.M))
overfull = log.count("Overfull")
print()
print("== pdflatex (reproducible: SOURCE_DATE_EPOCH=0 FORCE_SOURCE_DATE=1) ==")
print(f"pdflatex exit={tex.returncode}")
print(f"latex error lines: {err_lines}")
print(f"overfull boxes: {overfull}")

ppm = subprocess.run(["pdftoppm", "-png", "-r", "300", "-singlefile",
                      "system-anatomy.pdf", "system-anatomy"],
                     capture_output=True, text=True)
print()
print("== render ==")
print("pdftoppm exit ok" if ppm.returncode == 0 else f"pdftoppm FAIL rc={ppm.returncode}")

md5_lines, sha_lines = [], []
for f in OUTS:
    b = Path(f).read_bytes()
    md5_lines.append(f"{hashlib.md5(b).hexdigest()}  {f}")
    sha_lines.append(f"{hashlib.sha256(b).hexdigest()}  {f}")

md5file = Path(f"/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/scratch/fig_sa_v5_run{run}.md5")
md5file.write_text("\n".join(md5_lines) + "\n")

print()
print(f"run {run} md5:")
print("\n".join(md5_lines))
print()
print("sha256 (for the manifest):")
print("\n".join(sha_lines))
