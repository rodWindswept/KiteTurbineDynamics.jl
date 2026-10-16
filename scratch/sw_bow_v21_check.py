#!/usr/bin/env python3
"""Independent checker: the v21 bow-row delta (science-writer seat).

Reads the live file and the base revision from git, re-derives every claim the
receipt makes by routes distinct from the fold's own, and counts.
Routes used here: git plumbing, the shipped `ste-lint.py` as a subprocess,
the printed draft source, and the signed register row.
"""
import hashlib
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
REL = "docs/reporting/glossary-candidates.md"
BASE_REV = "8ffb803"
BOW_ROW_MD5 = "20ce48c214cc8b8213a14a92b2fef78b"
DRAFT_REL = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
REGISTER_REL = "docs/reporting/numbers-register.md"

checks = []


def check(name, cond, detail=""):
    checks.append((name, bool(cond), detail))
    print(("PASS  " if cond else "FAIL  ") + name + (("  | " + detail) if detail else ""))


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True).stdout


living = (ROOT / REL).read_text()
base = git("show", f"{BASE_REV}:{REL}")
draft = (ROOT / DRAFT_REL).read_text()
reg = (ROOT / REGISTER_REL).read_text()

check("live md5 matches the receipt", hashlib.md5(living.encode()).hexdigest() == BOW_ROW_MD5,
      hashlib.md5(living.encode()).hexdigest())
check("base rev reads", bool(base), BASE_REV)

bl, nl = base.splitlines(), living.splitlines()
diff = subprocess.run(["git", "diff", "--numstat", f"{BASE_REV}", "--", REL],
                      cwd=ROOT, capture_output=True, text=True).stdout.strip()
check("numstat one file, 7 added 2 removed", diff.startswith("7\t2\t"), diff)

bow_rows = [l for l in nl if l.startswith("| bow |")]
check("exactly one bow row", len(bow_rows) == 1, str(len(bow_rows)))
row = bow_rows[0]
check("row keeps the no-translation form",
      "The stack does not translate sideways: the bow is a rearrangement in which the lines "
      "reorient at near-constant length." in row)
check("row now names gravity and the direction", "Gravity pulls the sag straight down." in row)
check("row now carries the instrument-finding clause",
      "A disagreement on the bowed shape reads as an instrument finding, not a design question." in row)
check("row still states the rule", "The settle calculation and the run must agree on it." in row)
check("row holds no value", not re.search(r"\d", row.split("|")[2]))
check("row grounds unchanged", row.split("|")[3] == base.splitlines()[111].split("|")[3])
check("row action still supply", row.rstrip().endswith("supply |"))

guard = [l for l in nl if l.startswith('| "bow" as a sideways move')]
check("guard row byte-held and present", len(guard) == 1 and guard[0] in base)
check("status line moves to v21", living.count("**Status** PREP v21,") == 1
      and "**Status** PREP v20," not in living)
check("one v21 delta bullet", living.count("- **v21 (2026-10-16):**") == 1)
check("v21 bullet is the last bullet in the file", living.rstrip().endswith("No other change."))
check("bow row is the first row line after the destructive-resonance row",
      nl.index(row) == nl.index([l for l in nl if l.startswith("| destructive resonance")][0]) + 1)
check("row census by the row-line method holds",
      sum(1 for l in bl if l.startswith("| ")) == sum(1 for l in nl if l.startswith("| ")) == 137)
check("line count 409 -> 414", (len(bl), len(nl)) == (409, 414), f"{len(bl)} -> {len(nl)}")

# STE by a second route: the shipped linter as a subprocess, on both revisions
p_base = ROOT / "scratch/sw_bow_v21_check_base.md"
p_base.write_text(base)
r_new = subprocess.run(["python3", str(ROOT / "ste-lint.py"), str(ROOT / REL)],
                       cwd=ROOT, capture_output=True, text=True)
r_old = subprocess.run(["python3", str(ROOT / "ste-lint.py"), str(p_base)],
                       cwd=ROOT, capture_output=True, text=True)
check("ste-lint rc=0 with no --fail-above", r_new.returncode == 0, str(r_new.returncode))
tot = lambda s: (re.search(r"total=\s*(\d+)", s).group(1) if re.search(r"total=\s*(\d+)", s) else "NA")
per = lambda s: (re.search(r"per100w=\s*([\d.]+)", s).group(1) if re.search(r"per100w=\s*([\d.]+)", s) else "NA")
check("STE total 15 both sides", tot(r_new.stdout) == tot(r_old.stdout) == "15",
      f"{tot(r_old.stdout)} -> {tot(r_new.stdout)}")
check("STE per100w under 2.0", float(per(r_new.stdout)) < 2.0, per(r_new.stdout))
hooks_new = sorted(l.split(": ", 1)[1] for l in r_new.stdout.splitlines() if "[HOOK:ste]" in l)
hooks_old = sorted(l.split(": ", 1)[1] for l in r_old.stdout.splitlines() if "[HOOK:ste]" in l)
check("offender set identical both sides", hooks_new == hooks_old,
      f"{len(hooks_old)} vs {len(hooks_new)}")

# the printed report carries the two facts the row now backs
check("draft prints the gravity direction",
      "sagging straight down under gravity" in draft)
check("draft prints the disagreement as an instrument finding",
      "The two do not agree on the bowed shape." in draft
      and "instrument finding, not a design question" in draft)
check("draft cites NR-059 for the bow read", "NR-059" in draft)
check("register NR-059 signed", "| NR-059 | Winner bow (island 3)" in reg
      and "signed (science-validator, 2026-10-16)" in reg)
check("register keeps the founder station rule",
      "- The founder station reads the midpoint ring (ring 5)." in reg)
check("glossary entry carries no value per the register rule",
      "- The glossary entry (v20) carries no value. The value reads from this row." in reg)

bad = [c for c in checks if not c[1]]
print(f"\n{len(checks)} checks, {len(bad)} fail")
sys.exit(1 if bad else 0)
