#!/usr/bin/env python3
"""fig-sa v4 check: the re-cut records and outputs against the manifest.

Runs from the repo root against the committed kit bytes:
  - label-ledger: 32 strings; carries "blade span" and "1.499 m"
  - tex: carries the dimension style draw and the NR-043 source line
  - manifest: register_rows carry NR-043; every output hash recomputes
"""
import hashlib
import json
import sys

KIT = "docs/reporting/figures/system-anatomy/"
ok = True


def check(name, cond, detail=""):
    global ok
    print(f"[{name}] {'PASS' if cond else 'MISMATCH'} {detail}".rstrip())
    ok = ok and cond


led = [l for l in open(KIT + "label-ledger.txt", encoding="utf-8")
       .read().splitlines() if l.strip()]
check("ledger count 32", len(led) == 32, f"got {len(led)}")
check("ledger carries blade span", "blade span" in led)
check("ledger carries 1.499 m", "1.499 m" in led)

tex = open(KIT + "system-anatomy.tex", encoding="utf-8").read()
check("tex dimension draw", "ktd dim arrow" in tex)
check("tex NR-043 in stamp", "NR-043" in tex)
check("tex NR-011 stamp", "rows NR-011" in tex)

man = json.load(open(KIT + "manifest.json", encoding="utf-8"))
check("manifest register rows",
      man["inputs"]["register_rows"] == ["NR-011", "NR-017", "NR-043"],
      str(man["inputs"]["register_rows"]))
for fname, want in man["outputs"].items():
    got = hashlib.sha256(open(KIT + fname, "rb").read()).hexdigest()
    check(f"manifest {fname}", got == want, got[:16])

print("RESULT:", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
