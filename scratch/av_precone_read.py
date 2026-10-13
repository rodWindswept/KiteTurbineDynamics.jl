#!/usr/bin/env python3
"""av_precone_read.py — the AeroDyn pre-cone equivalence read (aero seat, 2026-10-13).

Founder docx return, note 10 (section 2.1): "the equivalent term in AeroDyn
is pre-cone". This script re-checks the read from committed bytes at HEAD,
plus the AeroDyn v5.0.0 deck on the NAS (primary source).

Groups:
  A. Install point — the draft's section 2.1 bank sentence; the gloss is net-new.
  B. The mapping — 09-aerodyn-geometry-knobs.md sections 4, 6, 8.
  C. The measurement record — 10-precone-sweep.md sections 1, 5, 7.
  D. The deck's own annotations — ad_driver_v5.inp lines 35-36, plus the pin.
  E. Register rows NR-019 / NR-020 and the tracker item.

Whitespace is collapsed before matching so wrapped lines compare clean.
Exit 0 when every check passes.
"""
import datetime
import hashlib
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DECK = Path("/mnt/Windswept Energy/_hermes_brain/KNOWLEDGE/aerodyn-v5.0.0/ad_driver_v5.inp")
DECK_SHA = "93edcf7ecf8fb042f4a79ae08a3a32b3563ddcb0391891d4683ad572e65602de"

checks = []


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def flat(text):
    return " ".join(text.split())


def check(name, ok, detail=""):
    checks.append(bool(ok))
    status = "PASS" if ok else "FAIL"
    line = f"[{status}] {name}"
    if detail:
        line += f" — {detail}"
    print(line)


head = subprocess.run(
    ["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"],
    capture_output=True, text=True, check=True).stdout.strip()
branch = subprocess.run(
    ["git", "-C", str(ROOT), "branch", "--show-current"],
    capture_output=True, text=True, check=True).stdout.strip()

print("av_precone_read — the AeroDyn pre-cone equivalence read (aero seat)")
print(f"date {datetime.date.today()}  repo HEAD {head}  branch {branch}")
print()

# --- A. the install point -------------------------------------------------
draft = flat(read("docs/reporting/drafts/2026-10-08-report-first-draft.md"))
bank_sentence = ("Bank is the blade angle away from the ring plane about its "
                 "chord axis at the ring.")
check("draft: section 2.1 bank sentence present", bank_sentence in draft)
check("draft: carries no AeroDyn mention yet", "AeroDyn" not in draft)
check("draft: carries no pre-cone mention yet",
      ("pre-cone" not in draft) and ("Precone" not in draft))

# --- B. the mapping record: 09-aerodyn-geometry-knobs.md ------------------
k09 = flat(read("docs/validation/trpt-reference/09-aerodyn-geometry-knobs.md"))
check("09 §4: bank row reads 'angled out of the ring plane, rigid and uniform'",
      "the blade angled out of the ring plane, rigid and uniform along the span" in k09)
check("09 §4: the knob column reads the only knob of this kind",
      "the only knob of this kind" in k09)
check("09 §4: Precone is the banking knob (elevation is ShftTilt)",
      ("is where the elevation goes" in k09) and ("is the banking knob" in k09))
check("09 §4: the old 'bank is a shaft tilt' claim reads corrected",
      '"the bank is a shaft tilt" was wrong' in k09)
check("09 §6: the root-pivot caveat", "pivoting at the blade root" in k09)
check("09 §8: pivot open, magnitude measured",
      "The pivot geometry is still open, but the magnitude is now measured." in k09)

# --- C. the measurement record: 10-precone-sweep.md -----------------------
k10 = flat(read("docs/validation/trpt-reference/10-precone-sweep.md"))
check("10: title reads the precone (bank) sweep", "The precone (bank) sweep" in k10)
check("10 §5: the closest AeroDyn analogue to our bank",
      "the closest AeroDyn analogue to our bank" in k10)
check("10 §7: radius convention open, not needed for the result",
      "The precone radius convention is open and is not needed for this result." in k10)

# --- D. the deck, primary source -----------------------------------------
deck = DECK.read_text(encoding="utf-8", errors="replace")
lines = deck.splitlines()
pc_line = next((ln for ln in lines if "Precone(1)" in ln), "")
st_line = next((ln for ln in lines if "ShftTilt(1)" in ln), "")
check("deck: Precone(1) line carries the Blade precone (deg) annotation",
      "Blade precone (deg)" in pc_line, pc_line.strip())
check("deck: ShftTilt(1) line carries the Shaft tilt (deg) annotation",
      "Shaft tilt (deg)" in st_line, st_line.strip())
deck_sha = hashlib.sha256(DECK.read_bytes()).hexdigest()
check("deck: sha256 matches the read pin", deck_sha == DECK_SHA, deck_sha)

# --- E. register rows and the tracker item --------------------------------
reg = flat(read("docs/reporting/numbers-register.md"))
check("register: NR-019 row present",
      "| NR-019 |" in reg)
check("register: NR-020 row present, cites the sweep",
      ("| NR-020 |" in reg) and ("10-precone-sweep" in reg))
check("register: both rows read signed (aero-validator, 2026-10-08)", reg.count(
    "signed (aero-validator, 2026-10-08)") >= 2)
trk = flat(read("docs/reporting/draft-tracker.md"))
check("tracker: the open item reads as stated",
      'The AeroDyn pre-cone equivalence for "bank": awaits the @aero-validator read (founder return note 10).' in trk)

print()
total = len(checks)
passed = sum(checks)
print(f"checks {total}  pass {passed}  fail {total - passed}")
sys.exit(1 if passed != total else 0)
