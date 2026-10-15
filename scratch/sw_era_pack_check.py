#!/usr/bin/env python3
"""sw_era_pack_check.py - the era pack at the science-writer seat.

Reads the v0.55 draft and the repo record, and does five jobs:

  1. Build the era-label inventory from the provenance stamps and the docs.
  2. Read the section 3.1 phrase against that inventory.
  3. Read the section 4.2 failure-ledger table for date order.
  4. Build the reordered table and prove the body cells hold.
  5. Read the section 2.3 supply sentence for value tokens.

Every check prints a PASS or FAIL line. Exit 1 on any FAIL.
"""
import hashlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DRAFT = ROOT / "docs/reporting/drafts/2026-10-08-report-first-draft.md"
SUPPLY = ROOT / "scratch/sw_era_pack_supply.md"
INVENTORY = ROOT / "scratch/sw_era_pack_era_inventory.txt"

fails = []


def check(name, ok, detail):
    tag = "PASS" if ok else "FAIL"
    if not ok:
        fails.append(name)
    print("[%s] %s: %s" % (tag, name, detail))


draft_bytes = DRAFT.read_bytes()
draft = draft_bytes.decode("utf-8")
lines = draft.split("\n")
print("draft %s" % DRAFT.relative_to(ROOT))
print("draft md5 %s  lines %d" % (hashlib.md5(draft_bytes).hexdigest(), len(lines)))
print("")

# --- 1. era-label inventory -------------------------------------------------
stamp_re = re.compile(r"Physics era:\*\*\s*`?([A-Za-z0-9._-]+)`?")
labels = {}
for p in sorted((ROOT / "scripts/results").rglob("PROVENANCE.md")):
    m = stamp_re.search(p.read_text(errors="replace"))
    if m:
        labels.setdefault(m.group(1).rstrip("."), []).append(str(p.relative_to(ROOT)))

doc_re = re.compile(r"post-[0-9a-f]{7}_[A-Za-z0-9._-]+")
doc_labels = {}
for base in [ROOT / "docs", ROOT]:
    for p in sorted(base.rglob("*.md")):
        if ".git" in p.parts:
            continue
        for m in doc_re.finditer(p.read_text(errors="replace")):
            doc_labels.setdefault(m.group(0), set()).add(str(p.relative_to(ROOT)))

inv = []
inv.append("era-label inventory (sw era pack, 2026-10-15)")
inv.append("")
inv.append("A. provenance stamps under scripts/results/ (%d distinct)" % len(labels))
for lab in sorted(labels):
    inv.append("   %-45s %d stamp(s), e.g. %s" % (lab, len(labels[lab]), labels[lab][0]))
inv.append("")
inv.append("B. era labels named in the docs tree (%d distinct)" % len(doc_labels))
for lab in sorted(doc_labels, key=lambda k: (-len(doc_labels[k]), k)):
    inv.append("   %-55s %d file(s)" % (lab, len(doc_labels[lab])))
inv.append("")
pv_stamp = [l for l in labels if "physics-validation" in l]
pv_docs = [l for l in doc_labels if "physics-validation" in l]
inv.append("C. labels matching 'physics-validation': stamps %d, docs %d"
           % (len(pv_stamp), len(pv_docs)))
INVENTORY.write_text("\n".join(inv) + "\n")
print("\n".join(inv))
print("")
check("era inventory: no physics-validation era label", not pv_stamp and not pv_docs,
      "stamps %d, docs %d" % (len(pv_stamp), len(pv_docs)))

# the ledger that carries the name is a record, not an era
ledger = ROOT / "docs/validation/physics-validation-ledger.md"
check("physics-validation names a ledger", ledger.exists(),
      str(ledger.relative_to(ROOT)))

# --- 2. the section 3.1 phrase ---------------------------------------------
hits = [(i + 1, l) for i, l in enumerate(lines) if "physics-validation" in l]
check("draft cites the phrase once", len(hits) == 1,
      "%d hit(s): %s" % (len(hits), [h[0] for h in hits]))

s31_old = ("This campaign is the first screen after the physics-validation era.\n"
           "Larger and wider campaigns sit ahead.")
check("section 3.1 target reads as supplied", s31_old in draft,
      "lines %d-%d" % (hits[0][0], hits[0][0] + 1) if hits else "no hit")

s31_new = ("This campaign is the first search campaign of the wind-authority era.\n"
           "Larger and wider campaigns sit ahead.")
check("section 3.1 supply carries no digit", not re.search(r"\d", s31_new), "clean")
check("section 3.1 supply carries the era label name", "wind-authority era" in s31_new,
      "era named")

# the era table in the draft names the era too
era_row = [l for l in lines if l.startswith("| The wind-authority era")]
check("draft era table names the wind-authority era", len(era_row) == 1,
      era_row[0][:60] if era_row else "no row")

# --- 3. the section 4.2 table ----------------------------------------------
ts, te = None, None
for i, l in enumerate(lines):
    if l.startswith("| Date / event | Class |"):
        ts = i
    if ts is not None and i > ts and not l.startswith("|"):
        te = i
        break
rows = lines[ts:te]
check("ledger table found with six rows", len(rows) == 8, "%d line(s)" % len(rows))

dates = [r.split("|")[1].strip().split()[0] for r in rows[2:]]
check("ledger dates read six entries", len(dates) == 6, str(dates))
check("ledger table reads out of date order today", dates != sorted(dates),
      "current order %s" % dates)

order = sorted(range(len(dates)), key=lambda k: (dates[k], k))
reordered = [rows[0], rows[1]] + [rows[2 + k] for k in order]
new_dates = [r.split("|")[1].strip().split()[0] for r in reordered[2:]]
check("reordered table reads date order", new_dates == sorted(new_dates), str(new_dates))

old_cells = [c for r in rows[2:] for c in r.split("|")[2:-1]]
new_cells = [c for r in reordered[2:] for c in r.split("|")[2:-1]]
check("every body cell holds byte for byte",
      sorted(old_cells) == sorted(new_cells),
      "%d cells compared" % len(old_cells))
check("only the row order moves", rows[0] == reordered[0] and rows[1] == reordered[1],
      "header and rule hold")

s32_old = "\n".join(rows)
s32_new = "\n".join(reordered)
# every 2026-08-22 pair keeps its relative order
pair_old = [r for r in rows[2:] if "2026-08-22" in r]
pair_new = [r for r in reordered[2:] if "2026-08-22" in r]
check("the two 2026-08-22 rows keep their relative order", pair_old == pair_new,
      "same-day tie held")

# --- 4. the section 2.3 supply ---------------------------------------------
s23_new = ("An earlier round of this study swept the generator gain k on earlier machines.\n"
           "At the top of that sweep the TRPT shaft entered a destructive resonance.\n"
           "That round shares no number with this campaign, because the machine and the model differ.")
check("section 2.3 supply carries no value token", not re.search(r"\d", s23_new), "clean")

anchors = [
    ROOT / "docs/NOTES_MPPT_TWIST.md",
    ROOT / "docs/plans/2026-09-25-trpt-tulloch-criterion-correction.md",
]
for a in anchors:
    txt = a.read_text(errors="replace")
    check("ground reads: %s" % a.name,
          ("destructive resonance" in txt) or ("k_mult" in txt),
          "resonance line present" if "destructive resonance" in txt else "k_mult present")

s23_anchor = "That load forces about 9 kW from the seed (NR-047)."
check("section 2.3 anchor reads in the draft", draft.count(s23_anchor) == 1,
      "load block close")
check("no section 2.3 heading reads in the draft",
      not re.search(r"^### 2\.3", draft, re.M),
      "%d heading(s)" % len(re.findall(r"^### 2\.3", draft, re.M)))

# --- 5. the supply file -----------------------------------------------------
SUPPLY.write_text("""# Era pack supply (science-writer, 2026-10-15)

Read at draft v0.55 (`2e930a8`), file md5 `%s`, %d lines.
Block A and block B replace the named text byte for byte. Block C inserts
after its anchor line. No other byte moves.

## Block A - section 3.1, the era phrase (replace two lines)

```
%s
```

## Block B - section 4.2, the ledger table rows (replace six rows)

```
%s
```

## Block C - section 2.3, the back-pointer (insert after this anchor line)

Anchor:

```
%s
```

Insert:

```
%s
```
""" % (hashlib.md5(draft_bytes).hexdigest(), len(lines), s31_new, s32_new, s23_anchor, s23_new))
print("")
print("supply written to %s" % SUPPLY.relative_to(ROOT))

print("")
print("checks: %d fail" % len(fails))
if fails:
    print("failed: %s" % ", ".join(fails))
sys.exit(1 if fails else 0)
