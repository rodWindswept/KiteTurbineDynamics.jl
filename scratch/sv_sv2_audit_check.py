#!/usr/bin/env python3
"""SV2 audit — the AU2 claim-evidence matrix, checked claim by claim.

Independent check of the matrix supplied at `ec56301`
(docs/reporting/room-responses/author-2026-10-14-au2-claim-evidence-matrix.md).
Scope (science-validator plan, SV2): certify that every matrix entry maps
to a signed row; zero unbacked claims.

Sources read: the register, the AU2 receipt, the draft master, the three
telemetry files, the three convergence files, the PRD 0006 outward-load
spec, and src/trpt_optimization.jl. All reads come from committed bytes.
"""
import re, sys
from collections import Counter

R = "docs/reporting/numbers-register.md"
AU2 = "docs/reporting/room-responses/author-2026-10-14-au2-claim-evidence-matrix.md"
DRAFT = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
DATA = "scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2"
PRD = "docs/prd/0006-outward-load-spec.md"
SRC = "src/trpt_optimization.jl"

fails = []
npass = [0]

def check(label, ok, detail=""):
    if ok: npass[0] += 1; print(f"PASS {label}" + (f"  [{detail}]" if detail else ""))
    else: fails.append(label); print(f"FAIL {label}  [{detail}]")

def read(p):
    with open(p, encoding="utf-8") as f: return f.read()

reg = read(R); au2 = read(AU2); draft = read(DRAFT)

# ---- A. parse the matrix table -------------------------------------------
lines = au2.split("\n")
s = next(i for i, l in enumerate(lines) if l.startswith("| Claim |"))
rows = []
for l in lines[s + 2:]:
    if not l.startswith("|"): break
    cells = [c.strip() for c in l.strip("|").split("|")]
    rows.append(cells)
check("matrix carries 8 claim rows", len(rows) == 8, f"rows={len(rows)}")
block = "\n".join(lines[s:s + 2 + len(rows)])

# expected register IDs per row
want = [
    {"NR-001", "NR-002"}, {"NR-008"}, {"NR-018"}, {"NR-009", "NR-021"},
    {"NR-022", "NR-040"}, {"NR-003", "NR-004", "NR-005", "NR-006"},
    {"NR-012", "NR-013"}, set(),
]

def ids_in(cell):
    ids = set(re.findall(r"NR-\d{3}", cell))
    for a, b in re.findall(r"NR-(\d{3})\s+to\s+NR-(\d{3})", cell):
        ids |= {f"NR-{n:03d}" for n in range(int(a), int(b) + 1)}
    return ids

all_ids = []
for i, (rw, w) in enumerate(zip(rows, want), 1):
    ids = ids_in(rw[3])
    all_ids += sorted(ids)
    check(f"row {i} cites {sorted(w) if w else 'the PRD cite'}", ids == w, f"got {sorted(ids)}")
check("14 distinct cited rows", len(set(all_ids)) == 14, f"{len(set(all_ids))}")

# ---- B. every cited row is signed ----------------------------------------
for rid in sorted(set(all_ids)):
    m = [l for l in reg.split("\n") if l.startswith(f"| {rid} |")]
    check(f"{rid}: row present and signed", bool(m) and "signed (" in m[0],
          (m[0].split("|")[-2].strip() if m else "missing"))

# ---- C. value support per claim ------------------------------------------
regline = {rid: next(l for l in reg.split("\n") if l.startswith(f"| {rid} |"))
           for rid in set(all_ids)}
check("NR-001 carries 930", "930" in regline["NR-001"])
check("NR-002 carries the classified mix", all(t in regline["NR-002"] for t in
      ["508 ok", "301 reject", "110 clearance_reject", "11 reject_twist"]))
check("NR-008 carries 5.309", "5.309" in regline["NR-008"])
check("NR-018 carries 25.69846825623688", "25.69846825623688" in regline["NR-018"])
check("NR-009 carries 14.972 (internal)", "14.972" in regline["NR-009"])
check("display rule: every site reads 15.0 at 1 dp",
      "Every report display site of the minimum factor of safety (NR-009) reads" in reg
      and "`15.0` at 1 dp" in reg)
fos_vals = [float(v) for v in re.findall(r"FoS ([0-9]+(?:\.[0-9]+)?(?:e-?\d+)?)", regline["NR-021"])]
check("NR-021 ring FoS all above the boundary", bool(fos_vals) and min(fos_vals) > 1.0,
      f"min={min(fos_vals) if fos_vals else None}")
check("NR-022 carries has_limit true on all five", "has_limit true on all five" in regline["NR-022"])
check("NR-040 carries the S1 margin and the quote form",
      "2.0287970973051634" in regline["NR-040"] and "quote 2.03" in regline["NR-040"])
check("NR-005 carries 27.364", "27.364" in regline["NR-005"])
check("NR-006 carries 36.109", "36.109" in regline["NR-006"])
check("NR-003 carries 30.578", "30.578" in regline["NR-003"])
check("NR-004 carries 30.637", "30.637" in regline["NR-004"])
check("NR-012 carries the cold reproduction", "matches" in regline["NR-012"])
check("NR-013 carries the warm rejection", "rejects all three winners" in regline["NR-013"])

# ---- D. raw recomputes ----------------------------------------------------
stat = Counter()
total = 0
for i in (1, 2, 3):
    with open(f"{DATA}/island_{i}/telemetry.csv", encoding="utf-8") as f:
        body = [l for l in f if not l.lstrip().startswith("#")]
    header = body[0].rstrip("\n").split(",")
    si = header.index("status")
    for r in body[1:]:
        stat[r.rstrip("\n").split(",")[si]] += 1
    total += len(body) - 1
check("status recount equals the classified mix",
      dict(stat) == {"ok": 508, "reject": 301, "clearance_reject": 110, "reject_twist": 11},
      str(dict(stat)))
check("row total 930", total == 930, str(total))
last = {}
for i in (1, 2, 3):
    with open(f"{DATA}/island_{i}/convergence.csv", encoding="utf-8") as f:
        body = [l for l in f if not l.lstrip().startswith("#")]
    first = float(body[1].rstrip("\n").split(",")[2])
    last[i] = float(body[-1].rstrip("\n").split(",")[2])
check("seed reads 36.109 at 3 dp", f"{first:.3f}" == "36.109", f"{first:.3f}")
check("island bests read 30.578 / 30.637 / 27.364",
      (f"{last[1]:.3f}", f"{last[2]:.3f}", f"{last[3]:.3f}") == ("30.578", "30.637", "27.364"),
      f"{last[1]:.3f} {last[2]:.3f} {last[3]:.3f}")

# ---- E. forms in the matrix block ----------------------------------------
check("block prints 15.0, not 14.972", "15.0" in block and "14.972" not in block)
check("block prints kg-equivalent", "kg-equivalent" in block)
check("block prints the classified counts", "508 ok" in block and "301 reject" in block)
check("block prints the key values",
      all(t in block for t in ["5.309", "25.698", "2.03", "36.109", "27.364", "930"]))

# ---- F. locations resolve in the draft -----------------------------------
for h in ["### 3.1 The search at scale", "### 3.2 Convergence", "### 3.3 The winner",
          "### 3.4 The levers", "### 4.1 Evaluation fidelity", "### 4.3 Model boundaries"]:
    check(f"location {h.split()[1]} resolves", h in draft)

# ---- G. the PRD cite resolves --------------------------------------------
prd_lines = read(PRD).split("\n")
check("PRD 0006:147 reads the blade-root FoS formula",
      "FoS_blade_root" in prd_lines[146] and "σ_yield_cfrp" in prd_lines[146],
      prd_lines[146])
check("register Track E carries the PRD cite",
      "beam-on-supports blade model deferred (PRD 0006:147)" in reg)
src = read(SRC)
check("src defers the model (comment) and keeps Inf",
      "defer full beam-on-supports model" in src and "min_fos_blade_root = Inf" in src)

# ---- H. boundary statements have text support ----------------------------
check("lifter modulation supported (draft §3.3, §5; NR-026)",
      "assumes the stack can\nmodulate" in draft or "assumes the stack can modulate" in draft.replace("\n", " ")
      or "The report assumes the stack can" in draft)
check("draft §5 reads 'Lifter modulation remains an assumption'",
      "Lifter modulation remains an assumption" in draft)
row026 = next(l for l in reg.split("\n") if l.startswith("| NR-026 |"))
check("NR-026 carries the flat-regime assumption", "flat at all wind speeds" in row026)

# ---- summary --------------------------------------------------------------
print(f"RESULT: {npass[0]} checks pass, {len(fails)} fail")
if fails:
    print("FAILED:", "; ".join(fails))
sys.exit(1 if fails else 0)
