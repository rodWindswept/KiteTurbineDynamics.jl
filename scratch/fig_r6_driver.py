#!/usr/bin/env python3
"""fig-r6 run driver — one full chain run for one kit.

Usage: /usr/bin/python3 scratch/fig_r6_driver.py <kit> <label> <script-commit> [outdir]
  kit    sa | ru | tl | et | hero
  label  run tag for the log/md5 file names (pre | 1 | 2 | 3 ...)
  outdir optional scratch outdir (ru/tl/et only; default: in place)

Writes scratch/fig_r6_<kit>_<label>.log (full stdout/stderr) and
scratch/fig_r6_<kit>_<label>.md5 (md5 + sha256 tables, filename-first).
"""
import hashlib
import os
import re
import subprocess
import sys
from pathlib import Path

kit, label, sc = sys.argv[1], sys.argv[2], sys.argv[3]
outdir = sys.argv[4] if len(sys.argv) > 4 else None

ROOT = Path(".")

KITS = {
    "sa": {
        "dir": "docs/reporting/figures/system-anatomy",
        "outputs": ["system-anatomy.tex", "prototype.html", "label-ledger.txt",
                    "system-anatomy.pdf", "system-anatomy.png"],
    },
    "ru": {
        "dir": "docs/reporting/figures/ring-utilisation",
        "outputs": ["ring-utilisation.svg", "ring-utilisation.pdf", "ring-utilisation.png",
                    "label-ledger.txt", "manifest.json"],
    },
    "tl": {
        "dir": "docs/reporting/figures/twist-limit",
        "outputs": ["twist-limit.svg", "twist-limit.pdf", "twist-limit.png",
                    "label-ledger.txt", "manifest.json"],
    },
    "et": {
        "dir": "docs/reporting/figures/eval-timeline",
        "outputs": ["eval-timeline.svg", "eval-timeline.pdf", "eval-timeline.png",
                    "label-ledger.txt", "manifest.json"],
    },
    "hero": {
        "dir": "docs/reporting/figures/machine-winner-hero",
        "outputs": ["machine-winner-hero.png", "machine-winner-hero.svg",
                    "machine-winner-hero.pdf", "checks.log", "manifest.json"],
    },
}

spec = KITS[kit]
kdir = Path(spec["dir"])
work = Path(outdir) if outdir else kdir
log_path = ROOT / "scratch" / f"fig_r6_{kit}_{label}.log"
lines = []
lines.append(f"fig-r6 driver — kit {kit} · label {label} · script-commit {sc}")
lines.append(f"outdir: {work}")

rc_all = 0
if kit == "sa":
    gen = subprocess.run(["/usr/bin/python3", "system-anatomy.py"], cwd=kdir,
                         capture_output=True, text=True)
    lines.append("== generator ==")
    lines.append(gen.stdout.strip())
    lines.append(f"generator exit={gen.returncode}")
    if gen.stderr.strip():
        lines.append("generator stderr: " + gen.stderr.strip())
    rc_all |= gen.returncode
    env = dict(os.environ, SOURCE_DATE_EPOCH="0", FORCE_SOURCE_DATE="1")
    tex = subprocess.run(["pdflatex", "-interaction=nonstopmode", "system-anatomy.tex"],
                         cwd=kdir, capture_output=True, text=True, env=env)
    log = (kdir / "system-anatomy.log").read_text(errors="replace")
    err_lines = len(re.findall(r"^!", log, flags=re.M))
    overfull = log.count("Overfull")
    lines.append("== pdflatex ==")
    lines.append(f"pdflatex exit={tex.returncode}")
    lines.append(f"latex error lines: {err_lines}")
    lines.append(f"overfull boxes: {overfull}")
    rc_all |= tex.returncode
    ppm = subprocess.run(["pdftoppm", "-png", "-r", "300", "-singlefile",
                          "system-anatomy.pdf", "system-anatomy"], cwd=kdir,
                         capture_output=True, text=True)
    lines.append(f"pdftoppm exit={ppm.returncode}")
    rc_all |= ppm.returncode
elif kit in ("ru", "tl", "et"):
    slug = {"ru": "ring-utilisation", "tl": "twist-limit", "et": "eval-timeline"}[kit]
    cmd = ["/usr/bin/python3", f"docs/reporting/figures/{slug}/{slug}.py",
           "--script-commit", sc]
    if outdir:
        cmd += ["--outdir", outdir]
    run = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    lines.append("== generator ==")
    lines.append(run.stdout.strip())
    lines.append(f"generator exit={run.returncode}")
    if run.stderr.strip():
        lines.append("generator stderr: " + run.stderr.strip())
    rc_all |= run.returncode
elif kit == "hero":
    cmd = ["scripts/ktd-julia",
           "docs/reporting/figures/machine-winner-hero/machine-winner-hero.jl",
           "--script-commit", sc]
    run = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    lines.append("== generator ==")
    lines.append(run.stdout.strip())
    lines.append(f"generator exit={run.returncode}")
    if run.stderr.strip():
        lines.append("generator stderr: " + run.stderr.strip())
    rc_all |= run.returncode

md5s, shas = [], []
for f in spec["outputs"]:
    b = (work / f).read_bytes()
    md5s.append(f"{hashlib.md5(b).hexdigest()}  {f}")
    shas.append(f"{hashlib.sha256(b).hexdigest()}  {f}")

lines.append("")
lines.append(f"run {label} md5:")
lines.extend(md5s)
lines.append("")
lines.append("sha256 (for the pins):")
lines.extend(shas)
log_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
(ROOT / "scratch" / f"fig_r6_{kit}_{label}.md5").write_text(
    "\n".join(md5s) + "\n", encoding="utf-8")

print(f"kit {kit} label {label}: exit={rc_all}")
print("\n".join(md5s))
if rc_all != 0:
    sys.exit(1)
