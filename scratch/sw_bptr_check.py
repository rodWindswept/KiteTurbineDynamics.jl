#!/usr/bin/env python3
"""Independent check on the live glossary file after the v19 fold.

Re-derives every claim in the receipt from the artefact and the record,
not from the fold script.  rc=0 and N checks, 0 fail = clean.
"""
import hashlib
import pathlib
import re
import subprocess
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIVE = ROOT / "docs/reporting/glossary-candidates.md"
BASE = ROOT / "scratch/sw_bptr_base.md"
NEW = ROOT / "scratch/sw_bptr_new.md"
DOCX = ROOT / "scratch/report-pdf-build/draft-live.docx"
NOTES = ROOT / "docs/NOTES_MPPT_TWIST.md"
PLAN = ROOT / "docs/plans/2026-09-25-trpt-tulloch-criterion-correction.md"
DECISIONS = ROOT / "DECISIONS.md"

ROW = ("| destructive resonance | The shaft failure mode of an earlier gain sweep. "
       "The twist ripple grows and does not settle. The shaft snaps between states, "
       "and the power falls to zero in intervals. The report names the term for that "
       "earlier round only. That round and this campaign share no number. "
       "| `docs/NOTES_MPPT_TWIST.md` section 3, the 2026-09-25 Tulloch plan section 9 "
       "| supply |")

fails = []
count = [0]


def check(name, cond, extra=""):
    count[0] += 1
    if cond:
        print(f"ok    {name}")
    else:
        print(f"FAIL  {name} {extra}")
        fails.append(name)


def md5(p):
    return hashlib.md5(pathlib.Path(p).read_bytes()).hexdigest()


def sh(*args):
    return subprocess.run(args, cwd=ROOT, capture_output=True, text=True).stdout


live = LIVE.read_text()
base = BASE.read_text()
new = NEW.read_text()

# --- artifact identity -------------------------------------------------------
check("live file == the pinned candidate by md5", md5(LIVE) == md5(NEW), md5(LIVE))
check("candidate md5 reads c0d82058355ce53118d675ed30162b43",
      md5(NEW) == "c0d82058355ce53118d675ed30162b43", md5(NEW))
check("pinned base == the committed blob at HEAD",
      sh("git", "show", "HEAD:docs/reporting/glossary-candidates.md") == base)

# --- the fold ----------------------------------------------------------------
check("status line reads PREP v19 once", live.count("**Status** PREP v19") == 1)
check("no PREP v17 token survives", "PREP v17" not in live)
check("the row carries the term once", live.count("| destructive resonance |") == 1)
check("row census reads 141", sum(1 for l in live.splitlines() if l.startswith("|")) == 141)
check("line count reads 400", len(live.splitlines()) == 400)

rows_now = [l for l in live.splitlines() if l.startswith("|")]
rows_before = [l for l in base.splitlines() if l.startswith("|")]
check("every base row survives byte-held", all(r in rows_now for r in rows_before))
check("exactly one row is new, and it is the supplied row",
      [r for r in rows_now if r not in rows_before] == [ROW])
check("row census grew by exactly one", len(rows_now) - len(rows_before) == 1)

rowline = [l for l in live.splitlines() if l.startswith("| destructive resonance")][0]
cell = rowline.split("|")[2]
check("the definition cell is numbers-free", not any(ch.isdigit() for ch in cell))
check("the row sits between the collapse-margin and FoS rows",
      "| collapse margin |" in live.splitlines()[live.splitlines().index(rowline) - 1]
      and "| FoS (factor of safety) |" in live.splitlines()[live.splitlines().index(rowline) + 1])

# --- the delta block ---------------------------------------------------------
v18_base = base[base.index("- **v18 (2026-10-15):**"):].rstrip("\n")
v18_live = live[live.index("- **v18 (2026-10-15):**"):live.index("- **v19 (2026-10-15):**")].rstrip("\n")
check("the v18 delta entry is byte-identical", v18_base == v18_live)
check("the v19 delta entry lands once", live.count("- **v19 (2026-10-15):**") == 1)
check("the v19 entry names the row, the value gate and the bow hold",
      all(t in live for t in ["Section 2 takes the destructive-resonance row",
                              "stays a binding slot for Track D",
                              "The bow row does not land"]))

# --- the printed state the row answers to ------------------------------------
with zipfile.ZipFile(DOCX) as z:
    text = re.sub(r"<[^>]+>", "", z.read("word/document.xml").decode("utf8"))
check("the live draft prints the term once", text.lower().count("destructive resonance") == 1)
check("the live draft prints no bow", len(re.findall(r"\bbow\b", text, re.I)) == 0)

# --- the grounds --------------------------------------------------------------
notes = NOTES.read_text()
check("the ground carries the term in its failure-mode section",
      "destructive resonance" in notes and "Instability Cliff" in notes)
check("the plan exists and carries section 9",
      PLAN.exists() and "## 9." in PLAN.read_text())
check("the row cites both grounds",
      "docs/NOTES_MPPT_TWIST.md" in rowline and "2026-09-25 Tulloch plan" in rowline)

# --- the seat's own discipline -------------------------------------------------
ste = sh("python3", "ste-lint.py", "docs/reporting/glossary-candidates.md")
per100 = re.search(r"per100w=\s*([0-9.]+)", ste)
total = re.search(r"total=\s*(\d+)", ste)
check("STE rc=0 at or below the gate", per100 is not None and float(per100.group(1)) < 2.0,
      per100.group(0) if per100 else "no reading")
check("STE total is unchanged by the fold", total is not None and total.group(1) == "15",
      total.group(0) if total else "no reading")
check("no other tracked file is modified",
      sh("git", "diff", "--name-only").split() == ["docs/reporting/glossary-candidates.md"],
      repr(sh("git", "diff", "--name-only")))

# --- the bow row that did NOT land (staged supply only) -------------------------
dec = DECISIONS.read_text()
dec_flat = re.sub(r"\s+", " ", dec)
check("the bow ruling carries the output-not-constraint form",
      "Bow is an output, not a constraint." in dec_flat)
check("the bow ruling bars the September figure as a result",
      "1.5 m figure must not be quoted as a result" in dec_flat)
check("no bow row has landed", "\n| bow |" not in live and "| bow (" not in live)

print(f"\n{count[0]} checks, {len(fails)} fail")
sys.exit(1 if fails else 0)
