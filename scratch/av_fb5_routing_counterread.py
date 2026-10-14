#!/usr/bin/env python3
"""av_fb5_routing_counterread.py

The feedback round 5 routing counter-read (aero-validator, 2026-10-14).
Checks the routing record against committed bytes only. No simulator run.
"""
import hashlib, re, subprocess, zipfile
from xml.etree import ElementTree as ET

REPO = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl"
ATTACH = "/home/rod/.hermes/profiles/aero-validator/attachments/draft-live-rods-comments.docx"
RETURN = f"{REPO}/docs/reporting/feedback/2026-10-14-founder-docx-return.docx"
DRAFT = f"{REPO}/docs/reporting/drafts/2026-10-08-report-first-draft.md"
RUNNER = f"{REPO}/scripts/run_v13_5kw_masslift.jl"
REGISTER = f"{REPO}/docs/reporting/numbers-register.md"
KIT_ANAT = f"{REPO}/docs/reporting/figures/system-anatomy/captions.md"
KIT_STRIP = f"{REPO}/docs/reporting/figures/machine-evolution-strip/captions.md"
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'

PASS = FAIL = 0

def check(name, ok, detail=""):
    global PASS, FAIL
    if ok:
        PASS += 1
    else:
        FAIL += 1
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f" :: {detail}" if detail else ""))

def read(p):
    return open(p, encoding="utf-8").read()

def md5(p):
    return hashlib.md5(open(p, "rb").read()).hexdigest()

def flat(s):
    return re.sub(r"\s+", " ", s)

def doc_text(z, part):
    root = ET.fromstring(z.read(part))
    return flat("".join(t.text or "" for t in root.iter(f"{{{W}}}t")))

print("=== av feedback-5 routing counter-read, 2026-10-14 ===")

# 0. the tip
h = subprocess.run(["git", "-C", REPO, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
o = subprocess.run(["git", "-C", REPO, "rev-parse", "origin/bank-derate-cos2p65"], capture_output=True, text=True).stdout.strip()
check("tip: local == origin", h == o, f"{h[:7]} == {o[:7]}")

# 1. the return copy bytes
a1, a2 = md5(ATTACH), md5(RETURN)
check("return copy: attachment bytes == repo archive", a1 == a2, a1)

z = zipfile.ZipFile(RETURN)
copy_text = doc_text(z, "word/document.xml")

# 2. the census
cx = ET.fromstring(z.read("word/comments.xml"))
comments = cx.findall(f"{{{W}}}comment")
ids = [c.get(f"{{{W}}}id") for c in comments]
check("census: 17 comments, ids 0..16", ids == [str(i) for i in range(17)], ",".join(ids))
print("      authors:", sorted({c.get(f'{{{W}}}author') for c in comments}))
print("      dates:", min(c.get(f'{{{W}}}date') for c in comments), "to", max(c.get(f'{{{W}}}date') for c in comments))

doc = ET.fromstring(z.read("word/document.xml"))
body = doc.find(f"{{{W}}}body")
seen = []
for p in body.iter(f"{{{W}}}p"):
    here = [e.get(f"{{{W}}}id") for e in p.iter(f"{{{W}}}commentRangeStart")]
    here += [e.get(f"{{{W}}}id") for e in p.iter(f"{{{W}}}commentReference")]
    for i in here:
        if i not in seen:
            seen.append(i)
check("census: every comment anchors, document order 0..16", seen == [str(i) for i in range(17)], ",".join(seen))

# 3. the anchor sample reads in the live tree
draft = read(DRAFT)
dk = flat(draft)
samples = [
    ("id0 blade scale", "Blade scale sets the blade size. The scale multiplies the blade span and chord"),
    ("id1 ring gene", "The ring geometry sets the hub and ground radii"),
    ("id3 probes", "The probes that compare the paths sit in scripts/probe_rapid_vs_ode_winners.jl and scripts/probe_warm_reject_cause.jl"),
    ("id4 930 designs", "The campaign evaluated 930 designs (NR-001)"),
    ("id5 swing line", "Its window swing reads 0.029 kW on 5.309 kW"),
    ("id6 lifter", "The lifter is a stack of autogyros"),
    ("id7 blade-scale slots", "The winner genome contains two blade-scale slots. Slot 1 reads 0.82"),
    ("id8 second bank slot", "A second bank slot reads 22 degrees."),
    ("id9 eras", "This result differs from earlier eras for recorded reasons."),
    ("id10 breadth", "This run also trades breadth for fidelity"),
    ("id11 ring caption thread", "The hub ring R6 governs the structural check"),
]
for label, needle in samples:
    check(f"draft anchor reads: {label}", flat(needle) in dk)

check("kit anchor reads: id2 anatomy caption", "This figure shows the whole machine and the names of its parts" in flat(read(KIT_ANAT)))
check("kit anchor reads: id16 strip caption", "Island 3's best-so-far objective falls as the built geometry converges" in flat(read(KIT_STRIP)))

# 4. the one display shift and the two kW forms
check("return copy swing site: 'kilowatts'", "0.029 kilowatts on 5.309 kilowatts" in copy_text)
check("draft swing site: kW forms", "0.029 kW on 5.309 kW" in dk)
check("return copy gate cell: P_mean 5.309", "pass, P_mean 5.309 kW" in copy_text)
check("draft gate cell: P_end 5.314 with margin", "pass, P_end 5.314 kW. Margin +0.314 kW / +6.28 per cent" in dk)

# 5. the guards
cone_hits = [m.start() for m in re.finditer(r"[Cc]one", draft)]
cone_numeric = [c for c in cone_hits if re.search(r"\d", draft[max(0, c - 60):c + 60])]
check("guard: no number within 60 chars of any cone site", not cone_numeric, f"{len(cone_hits)} sites, {len(cone_numeric)} numeric")
deg22 = [m.start() for m in re.finditer(r"22 degrees", draft)]
check("guard: one '22 degrees' site (the bank slot)", len(deg22) == 1, f"{len(deg22)} sites")

# 6. the two read pins
runner_text = read(RUNNER)
runner = runner_text.splitlines()
seg = "\n".join(runner[261:264])  # lines 262-264
print("      runner lines 262-264:")
for ln in runner[261:264]:
    print("      |", ln)
check("pin: runner 262-264 carries start_mode = :cold", "start_mode = :cold" in seg)
check("pin: cfg holds cone_slope_deg = 22.0", "cone_slope_deg = 22.0" in runner_text)
check("pin: decode takes the cone from cfg, not the genome", "cone_slope_deg=cfg.cone_slope_deg" in runner_text)

# 7. the distinct record quantities
reg = read(REGISTER)
check("NR-008: mean 5.309 / P_end 5.314", "5.309 / P_end 5.314" in reg)
check("NR-014: swing reads the mean", "P_range 0.029 on 5.309 kW" in reg)

print(f"=== checks: {PASS} pass, {FAIL} fail ===")
raise SystemExit(1 if FAIL else 0)
