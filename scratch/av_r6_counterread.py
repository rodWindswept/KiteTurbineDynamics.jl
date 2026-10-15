#!/usr/bin/env python3
"""av-r6 counter-read — the round-6 folds and re-cuts at the aero desk.

Reads committed bytes only (git objects at the tip), runs no simulator.
Static census: python3 scratch/av_r6_counterread.py
Repro re-runs (F-REPRO, out of tree): python3 scratch/av_r6_counterread.py --repro
Log: scratch/av_r6_counterread.log (static), scratch/av_r6_repro.log (repro).
Exits nonzero on any fail.
"""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TIP = "9b414f3"
ORIGIN = "origin/bank-derate-cos2p65"
BASE = "4388fc5"          # pre-fold state (fig landing readback)
FOLD = "d0ed902"          # the v0.47 fold
LAND = "45ed95a"          # the figures landing (outputs + records)
SCR = "1af63fc"           # the figures script commit

DRAFT = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER = "docs/reporting/draft-tracker.md"
MAP = "docs/reporting/figures/figure-map.md"
REGISTER = "docs/reporting/numbers-register.md"
BLOCK = "scratch/sw_levers_reading_block.md"

n_ck = n_fail = 0
out = []


def chk(name, cond, detail=""):
    global n_ck, n_fail
    n_ck += 1
    if not cond:
        n_fail += 1
    out.append(f"check: {name}: {'OK' if cond else 'FAIL'}  {detail}")
    return cond


def say(s):
    out.append(s)


def run(cmd, cwd=None):
    return subprocess.run(cmd, cwd=cwd or ROOT, capture_output=True, text=True)


def run_b(cmd, cwd=None):
    return subprocess.run(cmd, cwd=cwd or ROOT, capture_output=True)


def blob_t(rev, path):
    r = run(["git", "show", f"{rev}:{path}"])
    if r.returncode != 0:
        raise RuntimeError(f"git show {rev}:{path} failed: {r.stderr.strip()}")
    return r.stdout


def blob_b(rev, path):
    r = run_b(["git", "show", f"{rev}:{path}"])
    if r.returncode != 0:
        raise RuntimeError(f"git show {rev}:{path} failed: {r.stderr.decode(errors='replace').strip()}")
    return r.stdout


def blob_id(rev, path):
    o = run(["git", "rev-parse", f"{rev}:{path}"]).stdout.strip()
    if not o:
        raise RuntimeError(f"blob_id empty for {rev}:{path} (path form?)")
    return o


def ls_files(d, rev=TIP):
    return [p.strip() for p in run(["git", "ls-tree", "-r", "--name-only", rev, "--", d]).stdout.splitlines() if p.strip()]


def sha256_bytes(b):
    return hashlib.sha256(b).hexdigest()


TOK = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")          # author tokenizer (au_v047_round6_fold.py)
HUBID = re.compile(r"(r_hub|R_HUB|hubring|hub_radius|blade_hub_radius|trpt_hub_radius|HUB_OFF|omega_hub|hub_altitude_drawn_m|hubz)")

SLUG = {"sa": "system-anatomy", "ru": "ring-utilisation", "tl": "twist-limit",
        "et": "eval-timeline", "hero": "machine-winner-hero", "strip": "machine-evolution-strip"}
KIT_DIRS = {k: f"docs/reporting/figures/{v}" for k, v in SLUG.items()}

# ── expected fold diff (draft), exact ± line sets ─────────────────────────
DRAFT_ADD = [
    "Internal engineering report. Draft v0.47. Date 2026-10-14.",
    "topmost-ring and ground radii, and the rotor count sets how many rings carry",
    "The top-segment helix force reads about 1278 N/vertex (NR-048).",
    "The capture topmost ring",
    "reads 15.033 at the final step (NR-021).",
    "| Topmost ring radius | 4.580 m | NR-011 |",
    "topmost ring radius is 4.580 metres and the ground radius 0.804 metres",
    "### 3.4 The levers of Performance",
    "The topmost rotor ring R6 governs the structural check at the winner operating point (NR-021).",
    "The topmost ring radius is 4.580 m and the ground radius is 0.804 m.",
    "| 2026-08-26 rotor-to-ring off-by-one | Decoder mapping error | The middle rotor landed on the topmost ring. Every expansion rotor shifted one ring. | Visual geometry check (`preview_genome_geometry.jl`) | Validate the rotor-to-ring map against the built geometry. | Corrected. |",
    "the topmost ring (2026-08-26).",
    "  the FoS fix, and its rotors sat one ring toward the top.",
    "The search found 508 feasible candidates in the searched space (NR-002).",
    "The best performing one had a mean power of 5.309 kW.",
    "Its airborne mass is 25.698 kilograms (NR-008, NR-018).",
]
DRAFT_REM = [
    "Internal engineering report. Draft v0.46. Date 2026-10-14.",
    "hub and ground radii, and the rotor count sets how many rings carry",
    "The hub-segment helix force reads about 1278 N/vertex (NR-048).",
    "The capture hub",
    "ring reads 15.033 at the final step (NR-021).",
    "| Hub radius | 4.580 m | NR-011 |",
    "hub radius is 4.580 metres and the ground radius 0.804 metres",
    "### 3.4 The levers",
    "The hub ring R6 governs the structural check at the winner operating point (NR-021).",
    "The hub radius is 4.580 m and the ground radius is 0.804 m.",
    "| 2026-08-26 rotor-to-ring off-by-one | Decoder mapping error | The middle rotor landed on the hub. Every expansion rotor shifted one ring. | Visual geometry check (`preview_genome_geometry.jl`) | Validate the rotor-to-ring map against the built geometry. | Corrected. |",
    "the hub (2026-08-26).",
    "  the FoS fix, and its rotors sat one ring toward the hub.",
    "The search found a feasible candidate in the searched space.",
    "Its mean power is 5.309 kW and its airborne mass is 25.698 kilograms (NR-008, NR-018).",
]
TRACKER_ADD = [
    "v0.47 pass by @author (2026-10-14).",
    "This pass folds the round-6 rulings, keyed on the science sign.",
    "The topmost-ring rename lands at the ten draft sites (topmost ring, topmost rotor ring and top).",
    "The conclusion prints the count 508 of 930 (NR-002), and the winner sentence takes the founder form.",
    "Section 3.4 retitles to The levers of Performance.",
    "No signed value changes.",
    "",
]

SIGNED_SITES = [
    ("topmost-ring and ground radii", "### 2.1 "),
    ("The top-segment helix force reads about 1278 N/vertex (NR-048).", "#### 2.2.2 "),
    ("The capture topmost ring", "### 3.3 "),
    ("| Topmost ring radius | 4.580 m | NR-011 |", "### 3.3 "),
    ("topmost ring radius is 4.580 metres and the ground radius 0.804 metres", "### 3.3 "),
    ("The topmost rotor ring R6 governs the structural check at the winner operating point (NR-021).", "### 3.4 "),
    ("The topmost ring radius is 4.580 m and the ground radius is 0.804 m.", "### 3.5 "),
    ("landed on the topmost ring.", "### 4.2 "),
    ("the topmost ring (2026-08-26).", "### 4.2 "),
    ("one ring toward the top.", "### 4.2 "),
]

APPENDIX_MAP = [
    ("Ring utilisation plate", "docs/reporting/figures/ring-utilisation",
     {"png": "ring-utilisation.png", "svg": "ring-utilisation.svg",
      "pdf": "ring-utilisation.pdf", "ledger": "label-ledger.txt"}),
    ("Twist limit plate", "docs/reporting/figures/twist-limit",
     {"png": "twist-limit.png", "svg": "twist-limit.svg",
      "pdf": "twist-limit.pdf", "ledger": "label-ledger.txt"}),
    ("Machine evolution strip", "docs/reporting/figures/machine-evolution-strip",
     {"png": "machine-evolution-strip.png", "svg": "machine-evolution-strip.svg",
      "pdf": "machine-evolution-strip.pdf", "checks": "checks.log"}),
    ("System anatomy plate", "docs/reporting/figures/system-anatomy",
     {"png": "system-anatomy.png", "pdf": "system-anatomy.pdf",
      "ledger": "label-ledger.txt", "checks": "checks.log"}),
    ("Levers landscape", "docs/reporting/figures/pca-landscape",
     {"png": "pca-landscape.png", "svg": "pca-landscape.svg",
      "pdf": "pca-landscape.pdf", "ledger": "label-ledger.txt"}),
    ("Parameter atlas", "docs/reporting/figures/pca-atlas",
     {"png": "pca-atlas.png", "svg": "pca-atlas.svg",
      "pdf": "pca-atlas.pdf", "ledger": "label-ledger.txt"}),
    ("Machine winner hero", "docs/reporting/figures/machine-winner-hero",
     {"png": "machine-winner-hero.png", "svg": "machine-winner-hero.svg",
      "pdf": "machine-winner-hero.pdf", "checks": "checks.log"}),
]


def parse_diff_minus_plus(text):
    add, rem = [], []
    for line in text.splitlines():
        if line.startswith("+++") or line.startswith("---"):
            continue
        if line.startswith("+"):
            add.append(line[1:])
        elif line.startswith("-"):
            rem.append(line[1:])
    return add, rem


def nearest_heading(lines, idx):
    h = None
    for i in range(idx, -1, -1):
        if lines[i].startswith("#"):
            h = lines[i]
            break
    return h


def main_static():
    # ── 1. pins ───────────────────────────────────────────────────────────
    say("== 1. blob pins ==")
    chk("head == origin", run(["git", "rev-parse", "HEAD"]).stdout.strip()
        == run(["git", "rev-parse", ORIGIN]).stdout.strip(), TIP)

    pin_paths = [DRAFT, TRACKER, MAP,
                 "docs/reporting/room-responses/science-validator-2026-10-15-round6-term-gate.md",
                 "docs/reporting/room-responses/figures-images-diagrams-2026-10-14-round6-hub-retirement-recut.md"]
    for d in KIT_DIRS.values():
        pin_paths += ls_files(d)
    bad = []
    for p in pin_paths:
        if blob_id(TIP, p) != blob_id(ORIGIN, p):
            bad.append(p)
    chk("all pin paths: tip == origin", not bad, "; ".join(bad[:6]))

    chk("draft: fold blob == tip blob", blob_id(FOLD, DRAFT) == blob_id(TIP, DRAFT))
    chk("tracker: fold blob == tip blob", blob_id(FOLD, TRACKER) == blob_id(TIP, TRACKER))
    for k in ("sa", "ru", "tl", "et", "hero"):
        p = f"{KIT_DIRS[k]}/{SLUG[k]}.py" if k != "hero" else f"{KIT_DIRS[k]}/{SLUG[k]}.jl"
        chk(f"{k} script pinned at script commit", blob_id(SCR, p) == blob_id(TIP, p), Path(p).name)

    moved = run(["git", "log", "--format=%h", f"{LAND}..{TIP}", "--", "docs/reporting/figures"]).stdout.split()
    chk("figures tree frozen since the landing", moved == [], str(moved))
    d_moved = run(["git", "log", "--format=%h", f"{LAND}..{TIP}", "--", "docs/reporting/drafts"]).stdout.split()
    chk("draft movers since landing == [d0ed902]", d_moved == [FOLD], str(d_moved))

    # ── 2. the fold census (draft) ────────────────────────────────────────
    say("== 2. the fold census (draft) ==")
    base_d = blob_t(BASE, DRAFT)
    cand_d = blob_t(FOLD, DRAFT)
    chk("cand reads the tip", cand_d == blob_t(TIP, DRAFT))

    diff_d = run(["git", "diff", BASE, FOLD, "--", DRAFT]).stdout
    add_d, rem_d = parse_diff_minus_plus(diff_d)
    chk("draft added set == declared (16 lines)", sorted(add_d) == sorted(DRAFT_ADD), f"got {len(add_d)} lines")
    if sorted(add_d) != sorted(DRAFT_ADD):
        only_a = [l for l in add_d if l not in DRAFT_ADD]
        miss_a = [l for l in DRAFT_ADD if l not in add_d]
        say(f"  added-only: {only_a[:6]}")
        say(f"  expected-missing: {miss_a[:6]}")
    chk("draft removed set == declared (15 lines)", sorted(rem_d) == sorted(DRAFT_REM), f"got {len(rem_d)} lines")
    if sorted(rem_d) != sorted(DRAFT_REM):
        only_r = [l for l in rem_d if l not in DRAFT_REM]
        miss_r = [l for l in DRAFT_REM if l not in rem_d]
        say(f"  removed-only: {only_r[:6]}")
        say(f"  expected-missing: {miss_r[:6]}")

    ta, tb = Counter(TOK.findall(base_d)), Counter(TOK.findall(cand_d))
    add_tok, rem_tok = dict(tb - ta), dict(ta - tb)
    say(f"draft token delta add {dict(sorted(add_tok.items()))} rem {dict(sorted(rem_tok.items()))}")
    chk("draft token delta == declared {47,508} / {46}",
        add_tok == {"47": 1, "508": 1} and rem_tok == {"46": 1})

    hub_b = len(re.findall(r"(?i)hub", base_d))
    hub_c = len(re.findall(r"(?i)hub", cand_d))
    top_b = len(re.findall(r"(?i)topmost", base_d))
    top_c = len(re.findall(r"(?i)topmost", cand_d))
    chk("hub census 10 -> 0", hub_b == 10 and hub_c == 0, f"{hub_b} -> {hub_c}")
    chk("topmost census 1 -> 9", top_b == 1 and top_c == 9, f"{top_b} -> {top_c}")

    lines_c = cand_d.splitlines()
    for s, sec in SIGNED_SITES:
        chk(f"signed site once + in section: {s[:40]}", cand_d.count(s) == 1)
        idx = next((i for i, l in enumerate(lines_c) if s in l), None)
        h = nearest_heading(lines_c, idx) if idx is not None else None
        chk(f"site sits in {sec.strip()}: {s[:34]}", h is not None and h.startswith(sec), str(h))
    chk("count sentence once", cand_d.count("The search found 508 feasible candidates in the searched space (NR-002).") == 1)
    chk("winner sentence once", cand_d.count("The best performing one had a mean power of 5.309 kW.") == 1)
    chk("mass sentence once", cand_d.count("Its airborne mass is 25.698 kilograms (NR-008, NR-018).") == 1)
    chk("retitle lands once", cand_d.count("### 3.4 The levers of Performance") == 1
        and "### 3.4 The levers\n" not in cand_d)

    def region(text, start, end):
        i = text.index(start)
        j = text.index(end, i)
        return text[i:j]

    sec5 = region(cand_d, "## 5 Conclusion", "## 6 Nomenclature")
    chk("count prints alone (no reject split in 5)", all(x not in sec5 for x in ("301", "110", "reject")))
    chk("classified line holds", "- Of the 930, 508 designs pass every gate. The other 422 designs read 301 reject, 110 clearance_reject and 11 reject_twist (NR-002)." in cand_d)

    for name, a, b in [
        ("region 1-2.1", "## 1 Introduction", "### 2.1 The kite turbine and its terms"),
        ("region 2.4-3.3", "### 2.4 The campaign", "### 3.3 The winner"),
        ("region 3.6-4.2", "### 3.6 Design implications", "### 4.2 The failure ledger"),
        ("region 4.3-5", "### 4.3 Model boundaries", "## 5 Conclusion"),
    ]:
        chk(f"byte-held {name}", region(cand_d, a, b) == region(base_d, a, b))
    chk("byte-held 6 to end", cand_d.split("## 6 Nomenclature")[1] == base_d.split("## 6 Nomenclature")[1])

    block = blob_t(TIP, BLOCK).rstrip("\n")
    bmd5 = hashlib.md5(block.encode()).hexdigest()
    log_txt = blob_t(TIP, "scratch/au_v047_round6_fold.log")
    m = re.search(r"frozen levers block: (\d+) bytes, md5 ([0-9a-f]{32})", log_txt)
    chk("frozen block: declared size/md5 read from the author log", m is not None)
    if m:
        # the author log prints a character count under the word "bytes"
        chk("frozen block: recompute == declared (chars) + md5",
            len(block) == int(m.group(1)) and bmd5 == m.group(2),
            f"chars {len(block)} bytes {len(block.encode())} md5 {bmd5}")
    chk("frozen block held once in cand", cand_d.count(block) == 1)
    chk("frozen block held once in base", base_d.count(block) == 1)

    mk_b = re.findall(r"^\[Figure seated:.*$", base_d, re.M)
    mk_c = re.findall(r"^\[Figure seated:.*$", cand_d, re.M)
    chk("seven seated markers hold", len(mk_c) == 7 and mk_c == mk_b, f"{len(mk_c)}")

    for v in ("4.580", "15.033", "5.309", "25.698", "0.804", "930"):
        chk(f"value counter holds: {v}", cand_d.count(v) == base_d.count(v))
    chk("508 grows by exactly one", cand_d.count("508") == base_d.count("508") + 1)
    chk("(NR-002) grows by exactly one", cand_d.count("(NR-002)") == base_d.count("(NR-002)") + 1)

    # ── 3. tracker ────────────────────────────────────────────────────────
    say("== 3. tracker ==")
    base_t = blob_t(BASE, TRACKER)
    cand_t = blob_t(FOLD, TRACKER)
    diff_t = run(["git", "diff", BASE, FOLD, "--", TRACKER]).stdout
    add_t2, rem_t2 = parse_diff_minus_plus(diff_t)
    chk("tracker added set == declared (7 lines)", sorted(add_t2) == sorted(TRACKER_ADD), f"got {len(add_t2)}")
    chk("tracker removed set empty", rem_t2 == [])
    tta, ttb = Counter(TOK.findall(base_t)), Counter(TOK.findall(cand_t))
    add_tt, rem_tt = dict(ttb - tta), dict(tta - ttb)
    say(f"tracker token delta add {dict(sorted(add_tt.items()))} rem {dict(sorted(rem_tt.items()))}")
    chk("tracker token delta == declared", add_tt == {"47": 1, "508": 1, "930": 1, "3.4": 1} and rem_tt == {})
    hb = len(re.findall(r"(?i)hub", base_t))
    hc = len(re.findall(r"(?i)hub", cand_t))
    chk("tracker hub sites untouched (2)", hb == hc == 2, f"{hb} == {hc}")

    # ── 4. register NR-002 ────────────────────────────────────────────────
    say("== 4. register ==")
    reg = blob_t(TIP, REGISTER)
    mrow = [l for l in reg.splitlines() if re.match(r"\| NR-002 \|", l)]
    chk("NR-002 row reads the mix",
        len(mrow) == 1 and "508 ok / 301 reject / 110 clearance_reject / 11 reject_twist" in mrow[0],
        mrow[0][:120] if mrow else "missing")
    chk("mix sums to 930", 508 + 301 + 110 + 11 == 930)

    # ── 5. the plates: pins, forms, ledger deltas ────────────────────────
    say("== 5. the plates ==")
    ledgers = {}
    for k in ("sa", "ru", "tl", "et"):
        d = KIT_DIRS[k]
        man = json.loads(blob_t(TIP, f"{d}/manifest.json"))
        badp = []
        sp = man["script"]
        if sha256_bytes(blob_b(TIP, sp["path"])) != sp["sha256"]:
            badp.append("script")
        for name, pin in man.get("outputs", {}).items():
            if sha256_bytes(blob_b(TIP, f"{d}/{name}")) != pin:
                badp.append(name)
        for iname, ipin in man.get("inputs", {}).items():
            if isinstance(ipin, dict) and "path" in ipin and "sha256" in ipin:
                if sha256_bytes(blob_b(TIP, ipin["path"])) != ipin["sha256"]:
                    badp.append(iname)
        chk(f"{k} manifest pins recompute", not badp, "; ".join(badp))
        if "script_commit" in man:
            chk(f"{k} manifest script_commit", man.get("script_commit") == SCR, str(man.get("script_commit", "")))
        else:
            chk(f"{k} manifest command pins the script commit",
                "--script-commit 1af63fc" in man.get("command", ""), man.get("command", "")[:90])
            say(f"note: {k} manifest carries no script_commit key; the commit pins via the command string")
        ledgers[k] = (blob_t(SCR, f"{d}/label-ledger.txt"), blob_t(TIP, f"{d}/label-ledger.txt"))

    # hero manifest pins (capture + extracts + outputs)
    d = KIT_DIRS["hero"]
    hman = json.loads(blob_t(TIP, f"{d}/manifest.json"))
    badp = []
    if sha256_bytes(blob_b(TIP, hman["script"]["path"])) != hman["script"]["sha256"]:
        badp.append("script")
    for name, pin in hman.get("outputs", {}).items():
        if sha256_bytes(blob_b(TIP, f"{d}/{name}")) != pin:
            badp.append(name)
    if sha256_bytes(blob_b(TIP, hman["capture"]["path"])) != hman["capture"]["sha256"]:
        badp.append("capture")
    for ex in hman.get("extracts", []):
        if sha256_bytes(blob_b(TIP, ex["path"])) != ex["sha256"]:
            badp.append(ex["purpose"])
    chk("hero manifest pins recompute", not badp, "; ".join(badp))
    chk("hero manifest script_commit", hman.get("script_commit") == SCR, str(hman.get("script_commit", "")))

    # sa: drawn strings in tex + pdf text layer
    sa_tex = blob_t(TIP, f"{KIT_DIRS['sa']}/system-anatomy.tex")
    chk("sa tex: R6, the topmost ring", "R6, the topmost ring" in sa_tex)
    chk("sa tex: no hub", not re.search(r"(?i)hub", sa_tex))
    tmppdf = Path("/tmp/av_r6_sa.pdf")
    tmppdf.write_bytes(blob_b(TIP, f"{KIT_DIRS['sa']}/system-anatomy.pdf"))
    pt = run(["pdftotext", str(tmppdf), "-"]).stdout
    chk("sa pdf text: R6, the topmost ring", "R6, the topmost ring" in pt)
    chk("sa pdf text: no hub", not re.search(r"(?i)hub", pt))
    sal = ledgers["sa"][1]
    chk("sa ledger: R6, the topmost ring", "R6, the topmost ring" in sal)
    hit = [l for l in sal.splitlines() if re.search(r"(?i)hub", l) and not HUBID.search(l)]
    chk("sa ledger: no retired form", not hit, str(hit[:3]))

    key = {
        "ru": ["R6 (top)"],
        "tl": ["R6 (top)", "ground to top"],
        "et": ["\u03c9 top", "top \u00b7 tip \u00b7 Betz"],
    }
    for k, keys in key.items():
        d = KIT_DIRS[k]
        svg = blob_t(TIP, f"{d}/{SLUG[k]}.svg")
        for s in keys:
            chk(f"{k} svg: {s}", s in svg)
        old = [l for l in svg.splitlines() if re.search(r"(?i)hub", l) and not HUBID.search(l)]
        chk(f"{k} svg: no retired form", not old, str(old[:2]))
        led = ledgers[k][1]
        for s in keys:
            chk(f"{k} ledger: {s}", s in led)

    for k in ("sa", "ru", "tl", "et"):
        oldb, newb = ledgers[k]
        same = Counter(TOK.findall(oldb)) == Counter(TOK.findall(newb))
        oldl, newl = set(oldb.splitlines()), set(newb.splitlines())
        say(f"{k} ledger: numeric multiset equal={same}; old-only lines={len(oldl - newl)} new-only lines={len(newl - oldl)}")
        chk(f"{k} ledger numbers unmoved", same)
        for l in sorted(oldl - newl)[:6]:
            say(f"  old-only: {l[:120]}")
        for l in sorted(newl - oldl)[:6]:
            say(f"  new-only: {l[:120]}")

    # et NR-042 footer
    d = KIT_DIRS["et"]
    et_svg = blob_t(TIP, f"{d}/eval-timeline.svg")
    et_led = ledgers["et"][1]
    et_rs = blob_t(TIP, f"{d}/register-status.md")
    et_spec = blob_t(TIP, f"{d}/SPEC.md")
    chk("et svg carries NR-042", "NR-042" in et_svg)
    chk("et ledger carries NR-042", "NR-042" in et_led)
    chk("et register-status: footer join + v5", "takes NR-042 at the round-6 build" in et_rs
        and "**Delta** v5 (2026-10-14): the hub-name retirement" in et_rs)
    chk("et SPEC: v2 delta", "- v2 (2026-10-14): the hub-name retirement sweep" in et_spec)
    et_man = json.loads(blob_t(TIP, f"{d}/manifest.json"))
    chk("et manifest register_rows carry NR-042", "NR-042" in json.dumps(et_man.get("inputs", {})))

    # hero
    hj = blob_t(TIP, f"{d and KIT_DIRS['hero']}/machine-winner-hero.jl")
    chk("hero jl: topmost ring R6 drawn string",
        'text="topmost ring R6"' in hj and 'text="hub ring R6"' not in hj)
    hcl = blob_t(TIP, f"{KIT_DIRS['hero']}/checks.log")
    chk("hero checks: drawn topmost-ring altitude",
        "drawn topmost-ring altitude" in hcl and "drawn hub altitude" not in hcl)
    hrs = blob_t(TIP, f"{KIT_DIRS['hero']}/register-status.md")
    chk("hero register-status: script commit + command + re-cut",
        "**Script commit** `1af63fc`" in hrs and "--script-commit 1af63fc`" in hrs
        and "**Re-cut** v2 (2026-10-14): the hub-name retirement" in hrs)
    chk("hero register-status: NR-011 row", "topmost ring and ground radii" in hrs)

    # strip
    d = KIT_DIRS["strip"]
    sc = blob_t(TIP, f"{d}/captions.md")
    chk("strip captions: topmost ring radius 4.580 m",
        "topmost ring radius 4.580 m" in sc and "hub radius 4.580 m" not in sc)
    srs = blob_t(TIP, f"{d}/register-status.md")
    chk("strip register-status: delta", "**Delta** (2026-10-14): the hub-name retirement" in srs)

    # sweep set
    tl_spec = blob_t(TIP, f"{KIT_DIRS['tl']}/SPEC.md")
    chk("tl SPEC: v7 delta + top forms", "- v7 (2026-10-14): the hub-name retirement sweep" in tl_spec
        and "ground \u2192 top" in tl_spec and "ring N top" in tl_spec)
    ru_proto = blob_t(TIP, f"{KIT_DIRS['ru']}/prototype.html")
    tld = run(["git", "diff", SCR, LAND, "--", f"{KIT_DIRS['tl']}/SPEC.md"]).stdout
    tla, tlr = parse_diff_minus_plus(tld)
    say(f"tl SPEC sweep: {len(tlr)} removed lines / {len(tla)} added lines; "
        f"hub occurrences in removed = {sum(l.count('hub') for l in tlr)}")
    chk("tl SPEC sweep: 6 edited lines / 7 replaced occurrences",
        len(tlr) == 6 and sum(l.count("hub") for l in tlr) == 7)
    chk("ru prototype: 4 sites", ru_proto.count("hub") == 0
        and blob_t(SCR, f"{KIT_DIRS['ru']}/prototype.html").count("hub") == 4
        and "topmost-ring inclusion" in ru_proto)

    # ── 6. appendix cells + draft cells ──────────────────────────────────
    say("== 6. appendix cells ==")
    app = cand_d.split("## Appendix: Figure provenance", 1)[1]
    chk("appendix count sentence", "All seven read dataset commit `dd3cc6a`." in app)
    cells_bad = []
    total_cells = 0
    subjects = [s for s, _, _ in APPENDIX_MAP]
    for subject, d, fmap in APPENDIX_MAP:
        start = app.index(f"{subject}:") + len(subject) + 1
        ends = [app.index(f"{s}:") for s in subjects if s != subject and f"{s}:" in app]
        end = min([e for e in ends if e > start], default=len(app))
        seg = app[start:end]
        cells = re.findall(r"- `(\w+)` `([0-9a-f]{64})`", seg)
        got = {lbl: h for lbl, h in cells}
        if len(got) != len(fmap):
            cells_bad.append(f"{subject}: {len(got)} cells != {len(fmap)}")
            continue
        for lbl, fn in fmap.items():
            want = sha256_bytes(blob_b(TIP, f"{d}/{fn}"))
            total_cells += 1
            if got.get(lbl) != want:
                cells_bad.append(f"{subject}/{lbl}")
    chk(f"all {total_cells} appendix hash cells recompute", not cells_bad and total_cells == 28,
        "; ".join(cells_bad[:6]))
    chk("four script cells read 1af63fc", cand_d.count("`1af63fc`") == 4, str(cand_d.count("`1af63fc`")))

    # ── 7. map ────────────────────────────────────────────────────────────
    say("== 7. map ==")
    mp = blob_t(TIP, MAP)
    chk("v37 delta reads", "- **v37 (2026-10-14):** the round-6 hub-name retirement sweep lands" in mp)
    for s in ["Next: the aero counter-read of the round-6 re-cut",
              "Next: the aero counter-read of the re-cut, then Rod's visual pass and the fold",
              "Next: the aero counter-read of the re-cut. The visual pass by Rod follows"]:
        chk(f"map read sits: {s[:44]}", s in mp)
    chk("row 9: sign-off", "Then sign-off" in mp)
    chk("row 23: family build opens", "The family-mode build opens at this seat" in mp)
    chk("map carries the re-cut script (>=5)", mp.count("1af63fc") >= 5, str(mp.count("1af63fc")))

    # ── 8. retired-word census across the kit trees ──────────────────────
    say("== 8. kit-tree census ==")
    art_hits = []
    record_hits = 0
    formnotes = []
    file_count = 0
    for k, d in KIT_DIRS.items():
        for p in ls_files(d):
            ext = Path(p).suffix.lower()
            if ext not in (".md", ".txt", ".svg", ".tex", ".html", ".py", ".jl", ".json", ".log"):
                continue
            file_count += 1
            t = blob_t(TIP, p)
            hits = [l for l in t.splitlines() if re.search(r"(?i)hub", l)]
            if not hits:
                continue
            if ext in (".svg", ".tex", ".html"):
                for l in hits:
                    if not HUBID.search(l):
                        art_hits.append(f"{p}: {l.strip()[:90]}")
            elif ext in (".py", ".jl"):
                for i, l in enumerate(t.splitlines(), 1):
                    if re.search(r"(?i)hub", l):
                        if HUBID.search(l):
                            continue
                        if ("retirement" in l) or ("re-cut" in l):
                            continue
                        formnotes.append(f"{p}:{i}")
                        say(f"  formnote {p}:{i}: {l.strip()[:110]}")
            else:  # .md .txt .log .json
                for l in hits:
                    if HUBID.search(l):
                        continue
                    if (("2026-10-14" in l) or ("hub-name retirement" in l) or ("re-cut" in l)
                            or ("retirement" in l) or ("delta" in l.lower()) or ("sweep" in l.lower())
                            or ("v5" in l) or ("v6" in l) or ("v2" in l) or ("v7" in l) or ("v8" in l)):
                        record_hits += 1
                    else:
                        art_hits.append(f"{p}: UNCLASSIFIED: {l.strip()[:100]}")
    chk("delivered art carries no retired form", not art_hits, "; ".join(art_hits[:5]))
    say(f"kit census: {file_count} text files; record lines {record_hits}; form notes {len(formnotes)}")
    chk("form notes == the five enumerated lines", len(formnotes) == 5, str(formnotes))
    chk("form-note loci", any("eval-timeline.py:10" in f for f in formnotes)
        and sum("machine-winner-hero.jl" in f for f in formnotes) == 4, str(formnotes))

    # ── 9. the open legs (routed to science-writer) ──────────────────────
    say("== 9. open legs ==")
    trk = blob_t(TIP, TRACKER)
    chk("tracker legs still read (2)", len(re.findall(r"(?i)hub", trk)) == 2)
    gc = blob_t(TIP, "docs/reporting/glossary-candidates.md")
    gc_hits = [l for l in gc.splitlines() if re.search(r"(?i)hub", l)]
    say(f"candidates: {len(gc_hits)} hit lines")
    for l in gc_hits[:6]:
        say(f"  candidates: {l.strip()[:110]}")
    try:
        sp_txt = blob_t(TIP, "docs/agents/stale-phrases.md")
        sp_hits = [l for l in sp_txt.splitlines() if re.search(r"(?i)hub", l)]
        say(f"stale-phrases: {len(sp_hits)} hit lines")
        chk("stale-phrases leg reads (4)", len(sp_hits) == 4, str(len(sp_hits)))
    except RuntimeError as e:
        chk("stale-phrases leg reads", False, str(e))

    # ── 10. copy boundary ─────────────────────────────────────────────────
    say("== 10. copy boundary ==")
    cp = ROOT / "scratch/report-pdf-build/draft-live.docx"
    if cp.exists():
        md5 = hashlib.md5(cp.read_bytes()).hexdigest()
        chk("copy unchanged since the v0.45 walk", md5 == "c88d19015e5d755f347f30d0e456634d", md5)
    else:
        chk("copy present", False, "missing")

    # ── 11. STE re-read on the 19 touched files ──────────────────────────
    say("== 11. STE ==")
    LINT = [
        "docs/reporting/figures/system-anatomy/captions-draft.md",
        "docs/reporting/figures/system-anatomy/captions.md",
        "docs/reporting/figures/system-anatomy/SPEC.md",
        "docs/reporting/figures/system-anatomy/register-status.md",
        "docs/reporting/figures/ring-utilisation/captions.md",
        "docs/reporting/figures/ring-utilisation/captions-draft.md",
        "docs/reporting/figures/ring-utilisation/SPEC.md",
        "docs/reporting/figures/ring-utilisation/register-status.md",
        "docs/reporting/figures/twist-limit/captions.md",
        "docs/reporting/figures/twist-limit/SPEC.md",
        "docs/reporting/figures/twist-limit/register-status.md",
        "docs/reporting/figures/eval-timeline/SPEC.md",
        "docs/reporting/figures/eval-timeline/register-status.md",
        "docs/reporting/figures/machine-winner-hero/register-status.md",
        "docs/reporting/figures/machine-evolution-strip/captions.md",
        "docs/reporting/figures/machine-evolution-strip/register-status.md",
        "docs/reporting/figures/figure-map.md",
        "docs/reporting/draft-tracker.md",
        DRAFT,
    ]
    bad_ste = []
    for f in LINT:
        r = run(["python3", "ste-lint.py", "--fail-above", "2.0", f])
        if r.returncode != 0:
            bad_ste.append(f)
    chk("STE rc=0 across the 19 touched files", not bad_ste, "; ".join(bad_ste[:4]))

    out.append("")
    out.append(f"CHECKER: {n_ck} checks, {n_fail} fail")
    text = "\n".join(out) + "\n"
    (ROOT / "scratch/av_r6_counterread.log").write_text(text, encoding="utf-8")
    print(text)
    return 1 if n_fail else 0


def main_repro():
    """F-REPRO: re-run the five generators out of tree (worktree), byte-compare."""
    SCR_DIR = ROOT / "scratch/av_r6"
    WT = SCR_DIR / "wt"
    log = []

    def w(s):
        log.append(s)
        print(s, flush=True)

    w(f"repro start · tip {TIP} · worktree {WT}")
    SCR_DIR.mkdir(parents=True, exist_ok=True)
    if not WT.exists():
        r = run(["git", "worktree", "add", "--detach", str(WT), TIP])
        w(f"worktree add rc={r.returncode} {r.stderr.strip()}")
        if r.returncode != 0:
            (ROOT / "scratch/av_r6_repro.log").write_text("\n".join(log) + "\n")
            return 1
    sid = SCR_DIR / "CoaxialAutogyroStacking.jl"
    if not sid.exists():
        sid.symlink_to(Path("/home/rod/Documents/GitHub/CoaxialAutogyroStacking.jl"))
    dep = WT / ".julia_depot"
    if not dep.exists():
        dep.symlink_to(ROOT / ".julia_depot")

    def cmp_outputs(drel, files, tag):
        bad = []
        for fn in files:
            p1 = SCR_DIR / f"run1_{tag}" / fn
            p2 = SCR_DIR / f"run2_{tag}" / fn
            if not p1.exists() or not p2.exists():
                bad.append(f"{fn}: missing run copy")
                continue
            b1, b2 = p1.read_bytes(), p2.read_bytes()
            origin = blob_b(TIP, f"{drel}/{fn}")
            if b1 != b2:
                bad.append(f"{fn}: run1 != run2")
            if b1 != origin:
                bad.append(f"{fn}: run1 != origin")
        chk(f"F-REPRO {tag}: {len(files)} outputs byte-identical (run1==run2==origin)", not bad, "; ".join(bad[:6]))
        w(f"F-REPRO {tag}: {'OK' if not bad else 'FAIL ' + '; '.join(bad)}")

    for k in ("ru", "tl", "et"):
        slug = SLUG[k]
        d = f"docs/reporting/figures/{slug}"
        files = [f"{slug}.svg", f"{slug}.pdf", f"{slug}.png", "label-ledger.txt", "manifest.json"]
        for run_i in (1, 2):
            r = run(["/usr/bin/python3", f"{d}/{slug}.py", "--script-commit", SCR], cwd=WT)
            w(f"{k} run{run_i}: rc={r.returncode}")
            w(r.stdout.strip()[-1500:])
            if r.returncode != 0:
                w(r.stderr.strip()[-800:])
            dst = SCR_DIR / f"run{run_i}_{k}"
            dst.mkdir(parents=True, exist_ok=True)
            for fn in files:
                shutil.copyfile(WT / d / fn, dst / fn)
        cmp_outputs(d, files, k)

    d = KIT_DIRS["sa"]
    files = ["system-anatomy.tex", "prototype.html", "label-ledger.txt", "system-anatomy.pdf", "system-anatomy.png"]
    for run_i in (1, 2):
        r = run(["/usr/bin/python3", "system-anatomy.py"], cwd=WT / d)
        w(f"sa run{run_i} gen: rc={r.returncode}")
        w(r.stdout.strip()[-600:])
        env = dict(os.environ, SOURCE_DATE_EPOCH="0", FORCE_SOURCE_DATE="1")
        r = subprocess.run(["pdflatex", "-interaction=nonstopmode", "system-anatomy.tex"],
                           cwd=WT / d, capture_output=True, text=True, env=env)
        w(f"sa run{run_i} pdflatex: rc={r.returncode}")
        r = subprocess.run(["pdftoppm", "-png", "-r", "300", "-singlefile", "system-anatomy.pdf", "system-anatomy"],
                           cwd=WT / d, capture_output=True, text=True)
        w(f"sa run{run_i} pdftoppm: rc={r.returncode}")
        dst = SCR_DIR / f"run{run_i}_sa"
        dst.mkdir(parents=True, exist_ok=True)
        for fn in files:
            shutil.copyfile(WT / d / fn, dst / fn)
    cmp_outputs(d, files, "sa")

    d = KIT_DIRS["hero"]
    files = ["machine-winner-hero.png", "machine-winner-hero.svg", "machine-winner-hero.pdf", "checks.log", "manifest.json"]
    for run_i in (1, 2):
        r = run(["scripts/ktd-julia", f"{d}/machine-winner-hero.jl", "--script-commit", SCR], cwd=WT)
        w(f"hero run{run_i}: rc={r.returncode}")
        w(r.stdout.strip()[-1500:])
        if r.returncode != 0:
            w(r.stderr.strip()[-1500:])
        if r.returncode == 0:
            dst = SCR_DIR / f"run{run_i}_hero"
            dst.mkdir(parents=True, exist_ok=True)
            for fn in files:
                shutil.copyfile(WT / d / fn, dst / fn)
    cmp_outputs(d, files, "hero")

    log.append("")
    log.append(f"REPRO CHECKER: {n_ck} checks, {n_fail} fail")
    (ROOT / "scratch/av_r6_repro.log").write_text("\n".join(log) + "\n", encoding="utf-8")
    return 1 if n_fail else 0


if __name__ == "__main__":
    if "--repro" in sys.argv:
        sys.exit(main_repro())
    sys.exit(main_static())
