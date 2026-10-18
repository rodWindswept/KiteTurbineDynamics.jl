#!/usr/bin/env python3
"""Six-class fold consistency sim (science-writer seat).

Base: the working-tree draft master (carries the author's uncommitted
display pass).  Candidate: base plus the A-34 fold text handed to the
author seat.  This script writes nothing to the draft master.
"""
import re, subprocess, sys
from collections import Counter

REPO = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl"
DRAFT = f"{REPO}/docs/reporting/drafts/2026-10-08-report-first-draft.md"

base = open(DRAFT, encoding="utf-8").read()
head = subprocess.check_output(
    ["git", "show", f"HEAD:{DRAFT[len(REPO)+1:]}"], cwd=REPO, text=True
)

log = []
def ok(msg): log.append(f"OK   {msg}")
def fail(msg): log.append(f"FAIL {msg}"); print("\n".join(log)); sys.exit(1)

# 1. The six-class blocks are byte-identical between HEAD and the
# working tree (the display pass must not touch them).
s31_marker = "A re-run probe now names those 201"
s5_marker = "probe (receipt 2026-10-17) names them."

def block_of(text, marker, nlines=8):
    i = text.index(marker)
    return "\n".join(text[i:].splitlines()[:nlines])

b31_work = block_of(base, s31_marker)
b31_head = block_of(head, s31_marker)
b5_work = block_of(base, s5_marker, 7)
b5_head = block_of(head, s5_marker, 7)
if b31_work == b31_head: ok("section 3.1 block byte-identical HEAD == working tree")
else: fail("section 3.1 block differs between HEAD and working tree")
if b5_work == b5_head: ok("section 5 block byte-identical HEAD == working tree")
else: fail("section 5 block differs between HEAD and working tree")

# 2. Exact sites: each old form must read exactly once.
edits = [
    # (old, new, label)
    ("A re-run probe now names those 201 (hermes receipt 2026-10-17).",
     "A re-run probe now names those 201 (NR-061).",
     "s3.1 citation"),
    ("36 refuse on rotor spacing. 29 break a line. Three\n"
     "cross the Betz ceiling. Three diverge at the hub tip speed. Only the last",
     "36 refuse on rotor spacing. 30 break a line. Three\n"
     "cross the Betz ceiling. Two diverge at the hub tip speed. Only the last",
     "s3.1 digits"),
    ("probe (receipt 2026-10-17) names them.",
     "probe (NR-061) names them.",
     "s5 citation"),
    ("36 refuse on rotor spacing.\n29 break a line. Three cross the Betz ceiling. Three diverge at the hub\ntip speed.",
     "36 refuse on rotor spacing.\n30 break a line. Three cross the Betz ceiling. Two diverge at the hub\ntip speed.",
     "s5 digits"),
]
candidate = base
for old, new, label in edits:
    n = candidate.count(old)
    if n != 1:
        fail(f"{label}: old form reads {n} sites (need 1)")
    candidate = candidate.replace(old, new)
    ok(f"{label}: one site, replaced")

# 3. The freeze sentence survives byte-identical (it wraps across two lines).
def norm(s):
    return re.sub(r"\s+", " ", s)
freeze = "Only the last class is a numerical divergence. The others are geometry or design refusals that the telemetry left blank."
if norm(candidate).count(freeze) == 1 and norm(base).count(freeze) == 1:
    ok("the 'only the last class' sentence holds (wrapped form)")
else:
    fail("the freeze sentence moved")

# 4. Arithmetic and order against the signed row.
signed = {"betz_cp_floor": 93, "settle_fail": 37, "spacing": 36,
          "rope_break": 30, "betz_ceiling": 3, "hub_tip": 2}
if sum(signed.values()) == 201: ok("signed row sums to 201")
else: fail("signed row does not sum to 201")

s31_new = block_of(candidate, s31_marker)
s5_new = block_of(candidate, "93 rotors fall below the power", 5)
# the six class counts, in order (93/37/36/30 print as digits, 3 and 2 as words)
s31_seq = ["93 rotors", "37 settle", "36 refuse", "30 break a line",
           "Three cross the Betz ceiling", "Two diverge at the hub tip speed"]
s5_seq = ["93 rotors", "37 settle", "36 refuse", "30 break a line",
          "Three cross the Betz ceiling", "Two diverge at the hub tip speed"]
def seq_ok(block, seq):
    flat = norm(block)
    idx = -1
    for item in seq:
        j = flat.find(item, idx + 1)
        if j == -1:
            return False, item
        idx = j
    return True, None
good, missing = seq_ok(s31_new, s31_seq)
if good: ok("s3.1 carries 93/37/36/30/3/2 in order")
else: fail(f"s3.1 sequence missing {missing!r}: {s31_new}")
good, missing = seq_ok(s5_new, s5_seq)
if good: ok("s5 carries 93/37/36/30/3/2 in order")
else: fail(f"s5 sequence missing {missing!r}: {s5_new}")
# no stray 29 remains in either block
if "29 break a line" not in candidate: ok("the 29 form reads zero sites")
else: fail("the 29 form survives")
if candidate.count("Three diverge at the hub") == 0: ok("'Three diverge' reads zero sites")
else: fail("'Three diverge' survives")

# 5. The close is untouched: no six-class form inside the close.
close_i = candidate.index("**Where this goes.**")
close = candidate[close_i:]
for token in ["29 break a line", "30 break a line", "break a line", "hub tip",
              "93 rotors", "37 settle", "36 refuse", "Three cross",
              "Two diverge", "numerical divergence"]:
    if token in close:
        fail(f"form {token!r} leaks into the close")
ok("the close carries none of the six-class forms")

# 6. Token diff (numeric-token pattern from the skill).
pat = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")
def tokens(text): return Counter(pat.findall(text))
added = tokens(candidate) - tokens(base)
removed = tokens(base) - tokens(candidate)
if dict(added) == {"30": 2}: ok(f"arrivals {dict(added)}")
else: fail(f"arrivals {dict(added)}")
if dict(removed) == {"29": 2}: ok(f"removals {dict(removed)}")
else: fail(f"removals {dict(removed)}")

# 7. STE gate: offender sets must be equal between base and candidate.
LINT = f"{REPO}/ste-lint.py"
def lint_offenders(text_path):
    out = subprocess.check_output(
        ["python3", LINT, text_path], text=True, stderr=subprocess.STDOUT
    )
    return out.strip()

open(f"{REPO}/scratch/sw_sixclass_base.md", "w", encoding="utf-8").write(base)
open(f"{REPO}/scratch/sw_sixclass_candidate.md", "w", encoding="utf-8").write(candidate)
lbase = lint_offenders(f"{REPO}/scratch/sw_sixclass_base.md")
lcand = lint_offenders(f"{REPO}/scratch/sw_sixclass_candidate.md")
# the header and each hook line carry the scratch path by construction;
# compare the (category, count) sets only
def offender_set(lint_text):
    return set(re.findall(r"ste\] \S+: (\w+(?:\(\S+\))?) x(\d+)", lint_text))
lbase_set = offender_set(lbase)
lcand_set = offender_set(lcand)
if lbase_set == lcand_set:
    ok(f"STE gate: offender sets identical ({sorted(lbase_set)})")
else:
    fail(f"STE gate moved: base {sorted(lbase_set)} vs candidate {sorted(lcand_set)}")

open(f"{REPO}/scratch/sw_sixclass_fold_sim.log", "w", encoding="utf-8").write(
    "\n".join(log) + "\n\nBASE LINT:\n" + lbase + "\n\nCANDIDATE LINT:\n" + lcand + "\n"
)
print("\n".join(log))
print("\n--- s3.1 replacement block ---")
print(s31_new)
print("\n--- s5 replacement block ---")
print(s5_new)
