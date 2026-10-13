#!/usr/bin/env python3
"""fig-sa caption forms check: the kit captions vs the founder-return capture.

Two word diffs, four assertions:
  base->file   plain: adds exactly {lifting, autogyro}; no removals
  base->file   tech:  adds exactly {triangular}; no removals
  file->return plain, tech: identical (no adds, no removals)
The base is the pre-fold blob at 88277f6. The bracketed marker
"[include blade span]" is stripped from the return side before comparing.
"""
import difflib
import hashlib
import re
import subprocess
import sys

BASE = "88277f6"
CAPTURE = "scratch/au_draft_docx_annotated_capture_2026-10-13.md"
CAPTIONS = "docs/reporting/figures/system-anatomy/captions.md"

print("fig-sa caption forms check")
print("base blob:", BASE)
print("capture sha256:",
      hashlib.sha256(open(CAPTURE, "rb").read()).hexdigest())
print("captions sha256:",
      hashlib.sha256(open(CAPTIONS, "rb").read()).hexdigest())

capture = open(CAPTURE).read().splitlines()
plain_hits = [l.strip() for l in capture
              if "lifting autogyro kite stack in the sky" in l]
tech_hits = [l.strip() for l in capture
             if "Six triangular rings run from the ground ring" in l]
print("return hits: plain", len(plain_hits), "tech", len(tech_hits))
if not plain_hits or not tech_hits:
    print("FAIL: returned caption line not found in the capture")
    sys.exit(1)
plain_ret = plain_hits[0]
tech_raw = tech_hits[0]
marker = "[include blade span]" in tech_raw
tech_ret = re.sub(r"\[include blade span\]\s*", "", tech_raw).strip()
print("blade-span marker on the return:", marker)
if not marker:
    print("FAIL: the return marker is absent")
    sys.exit(1)

cur = open(CAPTIONS).read()
blob = subprocess.run(
    ["git", "show", f"{BASE}:docs/reporting/figures/system-anatomy/captions.md"],
    capture_output=True, text=True)
if blob.returncode != 0:
    print("FAIL: cannot read the base blob:", blob.stderr.strip())
    sys.exit(1)
base = blob.stdout


def section(pattern, text):
    m = re.search(pattern, text, re.S)
    if not m:
        print("FAIL: pattern not found:", pattern)
        sys.exit(1)
    return " ".join(m.group(1).split())


plain_cur = section(r"## Plain caption\n\n(.*?)\n\n## Technical", cur)
tech_cur = section(r"## Technical caption.*?\n\n(.*?)\n\n## Provenance", cur)
plain_base = section(r"## Plain caption\n\n(.*?)\n\n## Technical", base)
tech_base = section(r"## Technical caption.*?\n\n(.*?)\n\n## Provenance", base)

ok = True


def check(name, a, b, want_adds):
    global ok
    adds, removes = [], []
    for line in difflib.unified_diff(a.split(), b.split(), lineterm="", n=0):
        if line.startswith("+") and not line.startswith("+++"):
            adds += line[1:].split()
        elif line.startswith("-") and not line.startswith("---"):
            removes += line[1:].split()
    adds.sort()
    removes.sort()
    good = adds == sorted(want_adds) and not removes
    print(f"[{name}] adds={adds} removes={removes} ->",
          "PASS" if good else "MISMATCH")
    ok = ok and good


check("base->file plain", plain_base, plain_cur, ["lifting", "autogyro"])
check("base->file tech", tech_base, tech_cur, ["triangular"])
check("file->return plain", plain_cur, plain_ret, [])
check("file->return tech", tech_cur, tech_ret, [])

print("RESULT:", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
