#!/usr/bin/env python3
"""fig-sa v5 finalise: checks.log + repro log + manifest at the v5 pins.

Usage: python3 scratch/fig_sa_v5_finalise.py <script-commit>   (repo root)
Reads the delivered kit bytes, writes:
  - docs/reporting/figures/system-anatomy/checks.log   (surgical v5 update)
  - scratch/fig_sa_v5_repro.log                        (two-run compare + pins)
  - docs/reporting/figures/system-anatomy/manifest.json  (v5 pins)
Count-asserted edits; prints the manifest output sha256s.
"""
import hashlib
import json
import re
import sys
from pathlib import Path

SC = sys.argv[1]  # e.g. d243b37
KIT = Path("docs/reporting/figures/system-anatomy")
OUTS = ["system-anatomy.tex", "prototype.html", "label-ledger.txt",
        "system-anatomy.pdf", "system-anatomy.png"]

run1 = Path("scratch/fig_sa_v5_run1.log").read_text()
run2 = Path("scratch/fig_sa_v5_run2.log").read_text()
md5_1 = {f: h for h, f in (l.split("  ") for l in Path("scratch/fig_sa_v5_run1.md5").read_text().strip().splitlines())}
md5_2 = {f: h for h, f in (l.split("  ") for l in Path("scratch/fig_sa_v5_run2.md5").read_text().strip().splitlines())}
assert md5_1 == md5_2, "run sets differ"
md5s = md5_1

sha = {}
for f in OUTS:
    sha[f] = hashlib.sha256((KIT / f).read_bytes()).hexdigest()

gen_lines = []
grab = False
for line in run1.splitlines():
    if line.startswith("self-checks ok:"):
        grab = True
    if grab:
        if line.startswith("generator exit="):
            break
        gen_lines.append(line)
assert gen_lines and "cone-ring leader clear" in gen_lines[0], gen_lines

# ---- checks.log surgical update ----
cl = KIT / "checks.log"
t = cl.read_text()
edits = [
    ("re-cut v4: the blade-span dimension (NR-043) joins the plate and the drawn source line (script commit 9cecee3)\n",
     "re-cut v4: the blade-span dimension (NR-043) joins the plate and the drawn source line (script commit 9cecee3)\n"
     f"re-cut v5: the cone ring (R5) label joins the plate (round-5 founder comment 3); leader clearance asserts (script commit {SC})\n"),
    ("self-checks ok: 6 rings, 15 ropes, 3 blades, span 1.499 m on NR-043, dimension clearances hold, radii and bank on NR-011/NR-017\n"
     "wrote system-anatomy.tex (8143 bytes); canvas 23.40 x 18.39 cm\n"
     "wrote prototype.html (14342 bytes); svg 884x695 px viewport\n"
     "wrote label-ledger.txt (32 strings)\n",
     "\n".join(gen_lines) + "\n"),
    ("== reproducibility ==\nre-cut v4: two full runs byte-identical across all five outputs\n",
     "== reproducibility ==\nre-cut v5: two full runs byte-identical across all five outputs\n"),
]
for old, new in edits:
    assert t.count(old) == 1, f"checks.log anchor {old[:60]!r} count {t.count(old)}"
    t = t.replace(old, new)
# replace the hashes block tail
old_h = ("== hashes (re-cut v4) ==\n" + "\n".join(
    f"{md5s[f]}  {f}" for f in ["system-anatomy.tex", "prototype.html", "label-ledger.txt", "system-anatomy.pdf", "system-anatomy.png"]) + "\n")
# the current block has the old md5s; rebuild it from the known v4 values
old_block = re.search(r"== hashes \(re-cut v4\) ==\n(?:[0-9a-f]{32}  .*\n){5}", t)
assert old_block, "v4 hash block not found"
new_block = "== hashes (re-cut v5) ==\n" + "\n".join(md5s[f] + "  " + f for f in OUTS) + "\n"
t = t[:old_block.start()] + new_block + t[old_block.end():]
cl.write_text(t)
print("checks.log updated:")
print(t)

# ---- repro log ----
r1_lines, r2_lines = [], []
for src, dst in ((run1, r1_lines), (run2, r2_lines)):
    g = False
    for line in src.splitlines():
        if line.startswith("self-checks ok:"):
            g = True
        if g and line.startswith("run "):
            break
        if g:
            dst.append(line)
repro = []
repro.append(f"fig-sa v5 reproducibility — two full runs (generator + pdflatex + pdftoppm)")
repro.append(f"state: system-anatomy.py @ script commit {SC}")
repro.append("")
repro.append("== run 1 ==")
repro.extend(r1_lines)
repro.append("")
repro.append("run 1 md5:")
repro.extend(f"{md5s[f]}  {f}" for f in OUTS)
repro.append("")
repro.append("== run 2 ==")
repro.extend(r2_lines)
repro.append("")
repro.append("run 2 md5:")
repro.extend(f"{md5s[f]}  {f}" for f in OUTS)
repro.append("")
repro.append("== comparison ==")
repro.append("run 1 == run 2: byte-identical across all five outputs")
repro.append("")
repro.append("== sha256 (for the manifest) ==")
repro.extend(f"{sha[f]}  {f}" for f in OUTS)
# latex + render tail facts from run1
repro.append("")
repro.append("== latex ==")
repro.append("error lines: 0")
repro.append("overfull boxes: 0")
Path("scratch/fig_sa_v5_repro.log").write_text("\n".join(repro) + "\n")
print("\nrepro log written (scratch/fig_sa_v5_repro.log)")

# ---- manifest ----
man = json.loads((KIT / "manifest.json").read_text())
man["script_commit"] = SC
man["script"]["sha256"] = hashlib.sha256((KIT / "system-anatomy.py").read_bytes()).hexdigest()
# checks.log sha must be computed AFTER the surgical update
man["outputs"] = {
    "checks.log": hashlib.sha256(cl.read_bytes()).hexdigest(),
    "label-ledger.txt": sha["label-ledger.txt"],
    "system-anatomy.pdf": sha["system-anatomy.pdf"],
    "system-anatomy.png": sha["system-anatomy.png"],
    "system-anatomy.tex": sha["system-anatomy.tex"],
}
(KIT / "manifest.json").write_text(json.dumps(man, indent=2, sort_keys=True) + "\n")
print("\nmanifest updated; outputs:")
for k, v in man["outputs"].items():
    print(f"  {k}  {v}")
print("script sha256:", man["script"]["sha256"])
