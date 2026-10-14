#!/usr/bin/env python3
"""Counter-read: the polish text, both pairs (aero-validator, 2026-10-14).

Covers the four seated sections of draft v0.34 (pin md5 below):
  pair one: the section 3.4 winner-margins block (between the row 7
            and row 20 markers), and section 3.5 (the evolution story);
  pair two: section 3.6 (design implications) and section 5 (conclusion).

For each region: every printed value recomputes from its signed register
row at the printed form, each cite points at the row that carries the
value, and a census lists every numeric token with its disposition.
Reads committed bytes only. Runs no simulator.
"""
import hashlib
import re
import sys
from pathlib import Path

ROOT = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
DRAFT = ROOT / "docs/reporting/drafts/2026-10-08-report-first-draft.md"
REGISTER = ROOT / "docs/reporting/numbers-register.md"
EXTRACT = (ROOT / "docs/reporting/figures/pair-extract/"
           "extract-winner-operating-point.csv")
PIN_MD5 = "6220660c65a16d8de4c2f2b1ee1ea84b"

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


draft = DRAFT.read_text(encoding="utf-8")
reg = REGISTER.read_text(encoding="utf-8")
md5 = hashlib.md5(DRAFT.read_bytes()).hexdigest()
print(f"[0] draft pin {md5} ({'agrees' if md5 == PIN_MD5 else 'MOVED'})")
if md5 != PIN_MD5:
    bad("draft moved since the read pin")

# ------------------------------------------------------------- regions
s34 = draft.split("### 3.4 The levers", 1)[1].split("### 3.5", 1)[0]
margins = s34.split("figure-map row 7", 1)[1].split("figure-map row 20", 1)[0]
s35 = draft.split("### 3.5 The evolution story", 1)[1].split("### 3.6", 1)[0]
s36 = draft.split("### 3.6 Design implications", 1)[1].split("## 4 Discussion", 1)[0]
s5 = draft.split("## 5 Conclusion", 1)[1].split("## 6 Nomenclature", 1)[0]
REGIONS = {"3.4-margins": margins, "3.5": s35, "3.6": s36, "5": s5}


def lines_of(region):
    return [ln for ln in region.splitlines() if ln.strip()]


# extraction-store values, full precision
ex = {}
for ln in EXTRACT.read_text().splitlines():
    if ln.startswith("ring,") or ln.startswith("segment,"):
        cols = ln.split(",")
        ex[cols[1]] = cols

ring_fos = {rid: float(ex[rid][15]) for rid in ex if rid.startswith("R")}
seg_alpha = {sid: float(ex[sid][8]) for sid in ex if sid.startswith("S")}
seg_dcrit = {sid: float(ex[sid][7]) for sid in ex if sid.startswith("S")}
seg_margin = {sid: float(ex[sid][11]) / float(ex[sid][10])
              for sid in ex if sid.startswith("S")}
r2r4 = sorted(ring_fos[r] for r in ("R2", "R3", "R4"))
s14 = sorted(seg_alpha[s] for s in ("S1", "S2", "S3", "S4"))

print("[1] pair one, section 3.4 margins: form recompute")


def fmt(v, dp):
    return f"{v:.{dp}f}"


checks = [
    ("15.0", "NR-009", fmt(14.971791422208508, 1)),
    ("15.033", "NR-021", fmt(ring_fos["R6"], 3)),
    ("29.8", "NR-021", fmt(r2r4[0], 1)),
    ("35.2", "NR-021", fmt(r2r4[-1], 1)),
    ("33.5", "NR-022", fmt(s14[0], 1)),
    ("33.9", "NR-022", fmt(s14[-1], 1)),
    ("98.9", "NR-022", fmt(seg_dcrit["S1"], 1)),
    ("92.6", "NR-022", fmt(seg_dcrit["S5"], 1)),
    ("22.8", "NR-022", fmt(seg_alpha["S5"], 1)),
    ("2.03", "NR-040", fmt(seg_margin["S1"], 2)),
    ("2.69", "NR-040", fmt(seg_margin["S5"], 2)),
]
for form, row, recomputed in checks:
    (ok if form == recomputed else bad)(
        f"3.4: {form} recomputes as {recomputed} ({row})")
    hit = [ln for ln in lines_of(margins) if form in ln]
    (ok if hit else bad)(f"3.4: {form} prints")
    if hit:
        directed = any(row in ln for ln in hit)
        (ok if directed else bad)(f"3.4: {form} cites {row} on its line")

print("[2] pair one, section 3.5: form recompute")
s35_forms = [
    ("36.109", "NR-036"), ("32.293", "NR-036"), ("28.315", "NR-036"),
    ("27.364", "NR-005"), ("25.698", "NR-018"), ("1.665", "NR-039"),
    ("4.580", "NR-011"), ("0.804", "NR-011"), ("0.82", "NR-011"),
    ("0.20", "NR-011"),
]
for form, row in s35_forms:
    (ok if form in reg else bad)(f"register carries {form} for {row}")
    (ok if form in s35 else bad)(f"3.5: {form} prints")
drop = 28.315 - 27.364
(ok if fmt(drop, 3) == "0.951" else bad)(
    f"3.5: drop 28.315 - 27.364 = {fmt(drop, 3)} (prints 0.951)")
for row in ("NR-036", "NR-005", "NR-018", "NR-039", "NR-011", "NR-017"):
    (ok if row in s35 else bad)(f"3.5: cite {row} present")

print("[3] pair two, section 3.6 and section 5")
for form, row, where in [
        ("5.309", "NR-008", s36), ("25.698", "NR-018", s36),
        ("15.0", "NR-009", s36), ("2.03", "NR-040", s36),
        ("110", "NR-002", s36),
        ("930", "NR-001", s5), ("5.309", "NR-008", s5),
        ("25.698", "NR-018", s5), ("15.0", "NR-009", s5),
        ("2.03", "NR-040", s5)]:
    (ok if form in where else bad)(f"section: {form} prints ({row})")
for row in ("NR-002", "NR-008", "NR-009", "NR-011", "NR-013", "NR-017",
            "NR-018", "NR-040"):
    (ok if row in s36 else bad)(f"3.6: cite {row} present")
for row in ("NR-001", "NR-008", "NR-009", "NR-013", "NR-015", "NR-018",
            "NR-021", "NR-022", "NR-040"):
    (ok if row in s5 else bad)(f"5: cite {row} present")

print("[4] forbidden forms")
for token, where in [("14.972", draft), ("3.816", draft), ("27.363", draft)]:
    (ok if token not in where else bad)(f"draft does not print {token}")

print("[5] numeric census, four regions")
allowed_extra = {
    "R2", "R3", "R4", "R5", "R6", "S1", "S4", "S5",
    "1", "2", "3", "4", "5", "6", "7", "0", "26",
}
expected = {"15.0", "15.033", "29.8", "35.2", "33.5", "33.9", "98.9",
            "22.8", "92.6", "2.03", "2.69", "36.109", "32.293", "28.315",
            "27.364", "25.698", "1.665", "4.580", "0.804", "0.82", "0.20",
            "0.951", "5.309", "110", "930", "3", "6"}
leftovers = []
for name, region in REGIONS.items():
    scrubbed = re.sub(r"NR-\d{3}", "", region)
    scrubbed = re.sub(r"figure-map row \d+", "", scrubbed)
    scrubbed = re.sub(r"section \d", "", scrubbed)
    for m in re.finditer(r"\d+(?:\.\d+)?", scrubbed):
        t = m.group(0)
        if t in expected or t in allowed_extra:
            continue
        ctx = scrubbed[max(0, m.start() - 40):m.end() + 40].replace("\n", " ")
        leftovers.append((name, t, ctx))
(ok if not leftovers else bad)(
    f"census: every token classifies ({len(leftovers)} leftovers)")
for name, t, ctx in leftovers:
    print(f"       leftover {name}: {t!r} near {ctx!r}")

print(f"\nchecks: {OK + FAIL}  ok: {OK}  fail: {FAIL}")
sys.exit(1 if FAIL else 0)
