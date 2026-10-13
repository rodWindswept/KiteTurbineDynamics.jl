#!/usr/bin/env python3
"""SV F1 v4 census: the drawn plate text against the signed rows.

Read tip 0415d18. Runs from the repo root.
  - Extract the drawn text from system-anatomy.pdf (mutool text layer).
  - Every decimal readout maps to a signed row; no other number prints.
  - The drawn source line reads the row list NR-011 · NR-017 · NR-043.
  - The five md5s, the manifest hashes, the register note, and the draft
    appendix pins.
"""
import hashlib
import json
import re
import subprocess
from collections import Counter

ok = True


def check(name, cond, detail=""):
    global ok
    print(f"[{name}] {'PASS' if cond else 'MISMATCH'} {detail}".rstrip())
    ok = ok and bool(cond)


KIT = "docs/reporting/figures/system-anatomy/"

raw = subprocess.run(["mutool", "draw", "-F", "txt", KIT + "system-anatomy.pdf"],
                     capture_output=True, text=True, check=True).stdout
norm = re.sub(r"\s+", " ", raw.replace("_", " "))

# 1. drawn strings
drawn_frags = [
    "blade span", "1.499 m", "blade span 1.499 m",
    "R6, the hub ring", "4.580 m", "R1, the ground ring", "0.804 m",
    "three blades, bank 7.088°", "5 m",
    "segments S1 to S5", "three tension lines each",
    "data commit dd3cc6a · rows NR-011 · NR-017 · NR-043",
    "drawn to the 5 m scale bar",
]
for frag in drawn_frags:
    check(f"drawn: {frag}", frag in norm)

# 2. numeric census over the drawn text
toks = Counter(re.findall(r"\d+\.\d+|\d+", raw))
print("numeric tokens:", dict(sorted(toks.items())))
dec = sorted(t for t in toks if "." in t)
print("decimal readouts:", dec)
check("decimal readouts are the rowed set",
      dec == ["0.804", "1.499", "4.580", "7.088"], str(dec))
ints = sorted(t for t in toks if "." not in t)
print("integer tokens:", ints)
check("integer tokens are labels and the scale",
      set(ints) <= {"1", "3", "5", "6", "011", "017", "043"}, str(ints))

# 3. the five md5s
md5s = {
    "system-anatomy.tex": "5bf748abc6fd385860f72ce0713cfb1c",
    "prototype.html": "620481ca05882376cdea2c8026a22e6f",
    "label-ledger.txt": "9f5e89acc24393d6e6481ce4780ee6e4",
    "system-anatomy.pdf": "45a99a610b68c496209120ea6e6cd261",
    "system-anatomy.png": "aae4915c2f32a2f0c6798e68d2d29e03",
}
note = open(KIT + "register-status.md", encoding="utf-8").read()
for f, want in md5s.items():
    got = hashlib.md5(open(KIT + f, "rb").read()).hexdigest()
    check(f"md5 {f}", got == want, got)
    check(f"note lists md5 {f}", want in note)

# 4. register note claims
note_frags = [
    "| NR-043 | The winner blade span 1.499 m, drawn inner edge to tip (v4) | Signed (science-validator, `88277f6`) |",
    "The span prints at three decimals (`1.499 m`), the drawn radii precision,",
    "It is not a ring radius, and not the tip offset alone.",
    "The plate draws no other row.",
    "Script commit `9cecee3`. No other",
    "**Delta** v2 (2026-10-13): the v4 re-cut lands.",
]
for frag in note_frags:
    check(f"note: {frag[:44]}", frag in note)

# 5. manifest
man = json.load(open(KIT + "manifest.json", encoding="utf-8"))
check("manifest rows", man["inputs"]["register_rows"] == ["NR-011", "NR-017", "NR-043"])
check("manifest script commit", man["script_commit"] == "9cecee3")
for f, want in man["outputs"].items():
    got = hashlib.sha256(open(KIT + f, "rb").read()).hexdigest()
    check(f"manifest sha256 {f}", got == want, got[:16])

# 6. ledger + tex
led = [l for l in open(KIT + "label-ledger.txt", encoding="utf-8").read().splitlines()
       if l.strip()]
check("ledger 32 strings", len(led) == 32, str(len(led)))
check("ledger carries blade span", "blade span" in led)
check("ledger carries 1.499 m", "1.499 m" in led)
tex = open(KIT + "system-anatomy.tex", encoding="utf-8").read()
check("tex dim arrow", "ktd dim arrow" in tex)
check("tex row list", all(r in tex for r in ["NR-011", "NR-017", "NR-043"]))

# 7. the draft appendix block
draft = open("docs/reporting/drafts/2026-10-08-report-first-draft.md",
             encoding="utf-8").read()
check("appendix exhibit row",
      "| System anatomy plate | `scratch/fig1_decode_winner.jl` · `best_vector.csv` | "
      "NR-011, NR-017, NR-043 | `9cecee3` |" in draft)
for label, f in [("png", "system-anatomy.png"), ("pdf", "system-anatomy.pdf"),
                 ("ledger", "label-ledger.txt"), ("checks", "checks.log")]:
    check(f"appendix hash {label}", f"`{label}` `{man['outputs'][f]}`" in draft)

print("RESULT:", "PASS" if ok else "FAIL")
raise SystemExit(0 if ok else 1)
