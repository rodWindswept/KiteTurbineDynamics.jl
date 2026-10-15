#!/usr/bin/env python3
"""Readback: every carried blob byte-verified against origin."""
import hashlib
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
REF = "origin/bank-derate-cos2p65"
FILES = [
    "docs/reporting/glossary-candidates.md",
    "docs/reporting/room-responses/science-writer-2026-10-15-backpointer-term-row.md",
    "scratch/sw_bptr_base.md",
    "scratch/sw_bptr_new.md",
    "scratch/sw_bptr_supply.md",
    "scratch/sw_bptr_fold.py",
    "scratch/sw_bptr_fold.log",
    "scratch/sw_bptr_check.py",
    "scratch/sw_bptr_check.log",
    "scratch/sw_bptr_ste_probe.py",
    "scratch/sw_bptr_off_base.txt",
    "scratch/sw_bptr_off_new.txt",
]

out = []
rc = 0


def emit(line):
    print(line)
    out.append(line)


subprocess.run(["git", "fetch", "-q", "origin"], cwd=ROOT, check=True)
head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
ref = subprocess.run(["git", "rev-parse", REF], cwd=ROOT, capture_output=True, text=True).stdout.strip()
emit(f"readback: the back-pointer term row (science-writer seat)")
emit(f"HEAD    {head}")
emit(f"{REF}  {ref}")
emit(f"local == origin: {head == ref}")
emit("")

for f in FILES:
    work = hashlib.sha256((ROOT / f).read_bytes()).hexdigest()
    blob = subprocess.run(["git", "show", f"{REF}:{f}"], cwd=ROOT, capture_output=True).stdout
    home = hashlib.sha256(blob).hexdigest()
    ok = work == home
    rc = rc or (0 if ok else 1)
    emit(f"{'equal' if ok else 'DIFFER'}  {f}  {work[:16]}")

emit("")
emit(f"files carried: {len(FILES)}; equal: {sum(1 for f in FILES if hashlib.sha256((ROOT / f).read_bytes()).hexdigest() == hashlib.sha256(subprocess.run(['git','show',f'{REF}:{f}'], cwd=ROOT, capture_output=True).stdout).hexdigest())}")
emit("all carried blobs byte-verified at origin" if rc == 0 else "MISMATCH FOUND")

(ROOT / "scratch/sw_bptr_readback.log").write_text("\n".join(out) + "\n")
sys.exit(rc)
