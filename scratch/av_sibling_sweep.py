#!/usr/bin/env python3
"""Item-8 aero leg, part 2: the sibling-phrasing sweep
(aero-validator, 2026-10-14).

The founder flagged the section 4.1 pair: it reads as permission for
snapped ropes. The author pass took the detector forms. This sweep
reads the base tip (`9166686`) and reaches the wider permission forms
on the named live surfaces, the room-consultation line included:

  [A] the family census on the named surfaces at the base tip;
  [B] the strict tree-wide rope-permission census, every hit
      classified (live / records-evidence / exempt-verbatim);
  [C] the two fixes: the NR-025 register amend (append-only, mine) and
      the room-consultation line (one line, wording only);
  [D] the current tree re-reads: the old forms zero on the reader
      surfaces, the fixed forms present.

No number and no ruling moves. Stdlib only.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
BASE = "9166686"
SURFACES = [
    "docs/reporting/drafts/2026-10-08-report-first-draft.md",
    "docs/reporting/draft-tracker.md",
    "docs/reporting/numbers-register.md",
    "docs/reporting/2026-10-08-room-consultation.md",
    "docs/reporting/2026-10-08-reporting-framework.md",
    "handovers/handover-2026-10-08-reporting-room-boot.md",
    "handovers/handover-2026-10-14-reporting-room-queue.md",
]
CONSULT = "docs/reporting/2026-10-08-room-consultation.md"
REG = "docs/reporting/numbers-register.md"
DRAFT = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER = "docs/reporting/draft-tracker.md"
OLD_CONSULT = "enables rope-breaks on the measurement window only"
NEW_CONSULT = "limits break detection to the measurement window only"
ROW_FORM = "rope breaks enabled across both"
FAMILY = re.compile(r"\b(enabl\w*|allow\w*|permit\w*|permission\w*|consult\w*"
                    r"|licen\w*|entitl\w*)", re.I)
STRICT = re.compile(
    r"(enabl|allow|permit|licen)\w*[^.\n]{0,40}rope[- ]?break"
    r"|rope[- ]?break\w*[^.\n]{0,40}(enabl|allow|permit|licen)", re.I)
BREAKS = re.compile(r"allow\w* break|permit\w* break", re.I)
EXEMPT = ("docs/reporting/room-responses/", "scratch/", "docs/reporting/feedback/",
          "DECISIONS.md")

OK = 0
FAIL = 0


def ok(msg):
    global OK
    OK += 1
    print(f"  ok   {msg}")


def bad(msg):
    global FAIL
    FAIL += 1
    print(f"  FAIL {msg}")


def git(*args):
    return subprocess.run(["git", "-C", str(ROOT), *args],
                          capture_output=True, text=True).stdout.strip()


def show(rev, rel):
    return subprocess.run(["git", "-C", str(ROOT), "show", f"{rev}:{rel}"],
                          capture_output=True, text=True).stdout


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def hits(text, rx):
    out = []
    for i, line in enumerate(text.splitlines(), 1):
        if rx.search(line):
            out.append((i, line.strip()))
    return out


def lines_with(text, sub):
    return [(i, l.strip()) for i, l in enumerate(text.splitlines(), 1)
            if sub in l]


print(f"av_sibling_sweep — base tip {BASE} "
      f"| HEAD {git('rev-parse', '--short', 'HEAD')}")
(ok if git("merge-base", "--is-ancestor", BASE, "HEAD") == "" and
     subprocess.run(["git", "-C", str(ROOT), "merge-base", "--is-ancestor",
                     BASE, "HEAD"]).returncode == 0 else bad)(
    f"base tip {BASE} is an ancestor of HEAD")

# ── A. the family census on the named surfaces at the base tip ──────────
print("[A] the family census on the named surfaces (base tip)")
base_fam = {}
for s in SURFACES:
    h = hits(show(BASE, s), FAMILY)
    base_fam[s] = h
    for ln, txt in h:
        print(f"    {s}:{ln}: {txt[:100]}")
exp_draft = [t for _, t in base_fam[DRAFT]]
(ok if exp_draft == ["The fix removes false rejections. It never allows breaks."]
 else bad)(f"draft family hits read the one negation line ({len(exp_draft)})")
(ok if [t for _, t in base_fam[DRAFT] if "allows" in t][0].endswith(
    "It never allows breaks.") else bad)("the draft's one permission-family verb "
                                         "reads as a negation")
(ok if [t for _, t in base_fam[TRACKER]] ==
     ["The two shorthand forms take their safety-first replacements, and the "
      "sentence set states that breaks are never permitted."] else bad)(
    "tracker family hit reads the negation only")

# ── B. the strict census, every hit classified ──────────────────────────
print("[B] the strict tree-wide rope-permission census (base tip)")
files = git("ls-files", "*.md").splitlines()
strict_out, strict_live = [], []
for f in files:
    for ln, txt in hits(show(BASE, f), STRICT):
        strict_out.append((f, ln))
        if not f.startswith(EXEMPT):
            strict_live.append((f, ln, txt))
print(f"    strict hits: {len(strict_out)} across "
      f"{len({f for f, _ in strict_out})} files")
for f, ln in strict_out:
    print(f"    {f}:{ln}")
exp = {(CONSULT, 69), (REG, 332)}
(ok if set((f, ln) for f, ln, _ in strict_live) == exp else bad)(
    f"live strict hits read exactly the two targets "
    f"({[(f, ln) for f, ln, _ in strict_live]})")
brk = []
for f in files:
    for ln, txt in hits(show(BASE, f), BREAKS):
        if not f.startswith(EXEMPT):
            brk.append((f, ln, txt))
(ok if [(f, txt) for f, _, txt in brk] ==
     [(DRAFT, "The fix removes false rejections. It never allows breaks.")]
 else bad)(f"'allows breaks' outside records reads the draft negation only "
           f"({[(f, ln) for f, ln, _ in brk]})")

# ── C. the two fixes ────────────────────────────────────────────────────
print("[C] the two fixes")
reg = read(REG)
regn = re.sub(r"\s+", " ", reg)
(ok if '"the rope-break check armed across both"' in regn else bad)(
    "NR-025 amend carries the detector form")
(ok if '## Aero wording amends: NR-025 (2026-10-14, aero-validator)' in reg
 else bad)("NR-025 amend block lands")
(ok if 'reads as permission' in reg and 'No number and no ruling moves.' in reg
 else bad)("the amend declares the reading and the no-move")
cur_row = [l for l in reg.splitlines() if l.startswith("| NR-025 |")]
base_row = [l for l in show(BASE, REG).splitlines() if l.startswith("| NR-025 |")]
(ok if len(cur_row) == 1 and len(base_row) == 1 and cur_row[0] == base_row[0]
 else bad)("the signed NR-025 row reads byte-identical to the base")
consult = read(CONSULT)
(ok if OLD_CONSULT not in consult else bad)("room-consultation old form reads zero")
(ok if NEW_CONSULT in consult else bad)("room-consultation detector form reads")
d = subprocess.run(["git", "-C", str(ROOT), "diff", "--numstat", BASE, "--",
                    CONSULT, REG], capture_output=True, text=True).stdout
n_consult = [l for l in d.splitlines() if l.endswith(CONSULT)]
n_reg = [l for l in d.splitlines() if l.endswith(REG)]
(ok if n_consult and n_consult[0].split()[0] == "1" and
     n_consult[0].split()[1] == "1" else bad)(
    f"consultation edit reads one line in, one line out ({n_consult})")
(ok if n_reg and n_reg[0].split()[1] == "0" else bad)(
    f"register edit reads additions only ({n_reg})")

# ── D. the current tree re-reads ────────────────────────────────────────
print("[D] the current tree re-reads")
for s in SURFACES:
    cur = hits(read(s), STRICT)
    if s == REG:
        rl = [txt for _, txt in cur if txt.startswith("| NR-025 |")]
        ql = [txt for _, txt in cur if "reads as permission" in txt]
        (ok if len(cur) == 2 and len(rl) == 1 and len(ql) == 1 else bad)(
            f"current register keeps the row and the amend quote only "
            f"({len(cur)} strict hits)")
    else:
        (ok if cur == [] else bad)(f"current {s} reads zero strict hits "
                                   f"({cur[:2]})")
(ok if 'enables rope-breaks' not in read(CONSULT) else bad)(
    "current consultation reads zero permission reading")
(ok if read(REG).count("armed across both") == 1 else bad)(
    "the detector form reads once in the amend bullet")

print(f"\nchecks: {OK + FAIL}  ok: {OK}  fail: {FAIL}")
print("AV_SIBLING_SWEEP_DONE" if FAIL == 0 else "AV_SIBLING_SWEEP_FAIL")
sys.exit(1 if FAIL else 0)
