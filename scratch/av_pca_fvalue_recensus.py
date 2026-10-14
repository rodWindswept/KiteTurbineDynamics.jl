#!/usr/bin/env python3
"""
F-VALUE re-census - the levers family after the cites-and-pins fix.

Seat: aero-validator. 2026-10-14. Read-only: reads git objects and the
committed telemetry, writes nothing.

Target: figure-map rows 20 and 21, slugs `pca-landscape` and `pca-atlas`,
at the fix commit d6d4db9 (kit bytes), read at the tip.

Checks:
  1. range      no kit path moves after the fix commit; blob identity
                fix == HEAD == origin across the twenty kit files
  2. pins       worktree == HEAD; manifests; the v3 hash blocks recompute
  3. census     SVG text layer vs the label ledger; scale nodes; no
                'pending' byte in any delivered file
  4. values     the drawn readouts vs their signed rows
  5. cites      the NR-005 / NR-006 mapping reads the register on every
                surface; NR-045 cites ride the landscape surfaces only
  6. stamps     the recut stamps read their signed forms
  7. recompute  shares, loadings, fits, coords, counts; the NR-045
                anchors (31 generations, winner from gen 26, step 0.951)
  8. runchecks  the three new in-script checks are present and pass

Run:  /usr/bin/python3 scratch/av_pca_fvalue_recensus.py
"""

import csv
import hashlib
import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]

OKS = 0
FAILS = []
NOTES = []

KITS = {
    "pca-landscape": {"dir": "docs/reporting/figures/pca-landscape", "ledger_n": 46},
    "pca-atlas": {"dir": "docs/reporting/figures/pca-atlas", "ledger_n": 37},
}

REG = "docs/reporting/numbers-register.md"
DRAFT = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
STRIP = "docs/reporting/figures/machine-evolution-strip/register-status.md"
TELE = "scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2"

CANON = {"36.109": "NR-006", "27.364": "NR-005"}
LAND_EXP_UNIQUE = {"-5", "-4", "-3", "-2", "-1", "0", "1", "2", "3", "30", "33", "36"}
LAND_EXP_NODES = sorted(
    ["-5", "-4", "-3", "-2", "-1", "0", "1"] + ["-2", "-1", "0", "1", "2", "3"] + ["30", "33", "36"]
)
NUMFULL = re.compile(r"-?\d+(?:\.\d+)?")

KIT_FILES = [
    "{d}/{s}.svg", "{d}/{s}.pdf", "{d}/{s}.png", "{d}/label-ledger.txt",
    "{d}/manifest.json", "{d}/checks.log", "{d}/SPEC.md",
    "{d}/register-status.md", "{d}/captions-draft.md", "{d}/{s}.py",
]


def say(*a):
    print(*a)


def ok(msg):
    global OKS
    OKS += 1
    say(f"  ok   {msg}")


def fail(msg):
    FAILS.append(msg)
    say(f"  FAIL {msg}")


def note(msg):
    NOTES.append(msg)
    say(f"  note {msg}")


def git(*args):
    r = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True)
    if r.returncode != 0:
        say(f"git {' '.join(args)} failed: {r.stderr.strip()}")
        sys.exit(2)
    return r.stdout.strip()


def show_bytes(path):
    r = subprocess.run(["git", "show", f"HEAD:{path}"], cwd=ROOT, capture_output=True)
    if r.returncode != 0:
        raise SystemExit(f"git show HEAD:{path} failed")
    return r.stdout


def show_text(path):
    return show_bytes(path).decode("utf-8")


def sha256b(b):
    return hashlib.sha256(b).hexdigest()


def md5b(b):
    return hashlib.md5(b).hexdigest()


def norm(s):
    return " ".join(s.split())


def nums(s):
    s2 = re.sub(r"NR-\d+", " ", s)
    s2 = re.sub(r"(?<![0-9A-Za-z])[0-9a-f]{7,40}(?![0-9A-Za-z])", " ", s2)
    s2 = re.sub(r"[xX]\d+", " ", s2)
    return re.findall(r"(?<![0-9A-Za-z])-?\d+(?:\.\d+)?", s2)


def svg_text(path):
    import xml.etree.ElementTree as ET

    root = ET.fromstring(show_bytes(path))
    out = []
    for el in root.iter():
        if el.tag.endswith("}text"):
            t = norm("".join(el.itertext()))
            if t:
                out.append(t)
    return out


say("=" * 72)
say("F-VALUE re-census - levers family (rows 20, 21) after the fix - aero-validator")
say("=" * 72)

head = git("rev-parse", "HEAD")
origin = git("rev-parse", "origin/bank-derate-cos2p65")
br = git("rev-parse", "--abbrev-ref", "HEAD")
say(f"\n[tip] branch {br}  HEAD {head[:12]}  origin {origin[:12]}")

# ------------------------------------------------------------- 1. range
fix = git("log", "-1", "--format=%H", "--", "docs/reporting/figures/pca-landscape")
fix2 = git("log", "-1", "--format=%H", "--", "docs/reporting/figures/pca-atlas")
say(f"\n[range] kit last-change commit: {fix[:12]}")
if fix == fix2:
    ok(f"both kit trees last moved at {fix[:12]}")
else:
    fail(f"kit last commits differ: {fix[:12]} vs {fix2[:12]}")

moved = git("log", "--format=%h", f"{fix}..HEAD", "--",
            "docs/reporting/figures/pca-landscape", "docs/reporting/figures/pca-atlas")
if moved == "":
    ok("no kit path moves in the range fix..HEAD")
else:
    fail(f"kit paths moved after the fix commit: {moved}")

range_ = git("rev-list", "--count", f"{fix}..HEAD")
say(f"  range {fix[:8]}..{head[:8]} holds {range_} commits")

bad = []
for slug, k in KITS.items():
    for tmpl in KIT_FILES:
        p = tmpl.format(d=k["dir"], s=slug)
        a = git("rev-parse", f"{fix}:{p}")
        b = git("rev-parse", f"HEAD:{p}")
        c = git("rev-parse", f"origin/bank-derate-cos2p65:{p}")
        if not (a == b == c):
            bad.append(p)
if bad:
    fail(f"blob identity broken: {bad}")
else:
    ok("blob identity fix == HEAD == origin across all 20 kit files")

# ------------------------------------------------------------- 2. pins
say("\n[pins] worktree == HEAD; manifests; the v3 hash blocks recompute")
for slug, k in KITS.items():
    d = k["dir"]
    bad = [p for tmpl in KIT_FILES
           for p in [tmpl.format(d=d, s=slug)]
           if sha256b(show_bytes(p)) != sha256b((ROOT / p).read_bytes())]
    if bad:
        fail(f"{slug}: worktree differs from HEAD: {bad}")
    else:
        ok(f"{slug}: 10 worktree files byte-equal to HEAD")

    man = json.loads(show_text(f"{d}/manifest.json"))
    for name, want in man["outputs"].items():
        got = sha256b(show_bytes(f"{d}/{name}"))
        if got != want:
            fail(f"{slug}: {name} sha256 != manifest pin")
    ok(f"{slug}: 4 outputs match the manifest pins")
    if sha256b(show_bytes(f"{d}/{slug}.py")) == man["script"]["sha256"]:
        ok(f"{slug}: script sha256 matches the manifest pin")
    else:
        fail(f"{slug}: script sha256 mismatch")
    for inp in man["inputs"]["telemetry"]:
        if sha256b((ROOT / inp["path"]).read_bytes()) != inp["sha256"]:
            fail(f"{slug}: telemetry pin mismatch")
    ok(f"{slug}: 3 telemetry inputs match the manifest pins")

    want_rows = ["NR-001", "NR-005", "NR-006", "NR-044"] + (["NR-045"] if slug == "pca-landscape" else [])
    if man["inputs"]["register_rows"] == want_rows:
        ok(f"{slug}: manifest register_rows == {','.join(want_rows)}")
    else:
        fail(f"{slug}: register_rows {man['inputs']['register_rows']} != {want_rows}")
    if man["inputs"]["row_wants"] == []:
        ok(f"{slug}: manifest row_wants empty")
    else:
        fail(f"{slug}: row_wants not empty")
    if man["script_commit"] == "e23f226" and "e23f226" in man["command"]:
        ok(f"{slug}: manifest script_commit e23f226 (command agrees)")
    else:
        fail(f"{slug}: script_commit {man['script_commit']} != e23f226")

    blk = show_text(f"{d}/register-status.md")
    want_md5 = dict(re.findall(r"^\s+(\S+)\s+([0-9a-f]{32})$", blk, re.M))
    exp = {"label-ledger.txt", f"{slug}.pdf", f"{slug}.png", f"{slug}.svg", "manifest.json"}
    if set(want_md5) == exp:
        ok(f"{slug}: v3 hash block lists the five files")
    else:
        fail(f"{slug}: v3 hash block set {sorted(want_md5)} != {sorted(exp)}")
    for name, want in want_md5.items():
        got = md5b(show_bytes(f"{d}/{name}"))
        if got != want:
            fail(f"{slug}: v3 block md5 {name} {got} != {want}")
    ok(f"{slug}: v3 hash block recomputes from the committed bytes")

# ------------------------------------------------------------- 3. census
say("\n[census] ledger vs SVG; scale nodes; no 'pending' byte")
ledgers, svgs = {}, {}
for slug, k in KITS.items():
    d = k["dir"]
    ledger = [norm(l) for l in show_text(f"{d}/label-ledger.txt").splitlines() if l.strip()]
    svg = svg_text(f"{d}/{slug}.svg")
    ledgers[slug], svgs[slug] = ledger, svg
    singles = [s for s in svg if NUMFULL.fullmatch(s)]
    say(f"  {slug}: ledger {len(ledger)} strings; svg {len(svg)} nodes; {len(singles)} scale nodes")
    if len(ledger) != k["ledger_n"]:
        fail(f"{slug}: ledger count {len(ledger)} != {k['ledger_n']}")
    if set(ledger) == set(svg):
        ok(f"{slug}: ledger set-equal to the svg text layer")
    else:
        fail(f"{slug}: ledger vs svg: missing={sorted(set(ledger)-set(svg))} extra={sorted(set(svg)-set(ledger))}")
    pend = [p for tmpl in KIT_FILES for p in [tmpl.format(d=d, s=slug)]
            if b"pending" in show_bytes(p)]
    if pend:
        fail(f"{slug}: 'pending' still in delivered bytes: {pend}")
    else:
        ok(f"{slug}: no 'pending' byte in any of the 10 delivered files")

if sorted(s for s in svgs["pca-landscape"] if NUMFULL.fullmatch(s)) == LAND_EXP_NODES:
    ok("landscape: 16 scale nodes == x ticks + y ticks + colour ticks")
else:
    fail("landscape: scale nodes moved")
if set(s for s in svgs["pca-landscape"] if NUMFULL.fullmatch(s)) == LAND_EXP_UNIQUE:
    ok("landscape: 12 unique scale values")

# atlas labels recomputed
atlas_labels = []
hdr_cache = {}
for i in (1, 2, 3):
    rows = list(csv.reader((ROOT / TELE / f"island_{i}" / "telemetry.csv").open()))
    hdr_cache[i] = (rows[1], rows[2:])
for j in range(10):
    col = np.concatenate([[float(r[hdr_cache[i][0].index(f"x{j+1}")]) for r in hdr_cache[i][1]]
                          for i in (1, 2, 3)])
    lo, hi = np.percentile(col, [2, 98])
    atlas_labels += [f"{v:.3g}" for v in (lo, (lo + hi) / 2, hi)]
a_singles = sorted(s for s in svgs["pca-atlas"] if NUMFULL.fullmatch(s))
if a_singles == sorted(atlas_labels):
    ok("atlas: 30 scale nodes == the recomputed colour labels at .3g")
else:
    fail("atlas: scale nodes vs recomputed labels differ")


def log_checks(path):
    out = {}
    for line in show_text(path).splitlines():
        m = re.match(r"^check: (.*?): (.*?)  \(OK\)$", line)
        if m:
            out[m.group(1)] = m.group(2)
    return out


lchk = log_checks(f"{KITS['pca-landscape']['dir']}/checks.log")
achk = log_checks(f"{KITS['pca-atlas']['dir']}/checks.log")
shared = set(lchk) & set(achk)
diffs = [k for k in shared if lchk[k] != achk[k]]
if diffs:
    fail(f"checks.log disagreement on shared pins: {diffs}")
else:
    ok(f"checks.log: {len(shared)} shared pins agree across the two kits")

# ------------------------------------------------------------- 4. values
say("\n[values] the drawn readouts vs their signed rows")
LAND, ATLAS = ledgers["pca-landscape"], ledgers["pca-atlas"]


def has(sel, s):
    return any(sel in x for x in s)


for sel, val, row in [
    ("start 36.109", "36.109", "NR-006"),
    ("one common seed at 36.109 (kg)", "36.109", "NR-006"),
    ("winner 27.364", "27.364", "NR-005"),
    ("winner: island 3 at 27.364 (kg)", "27.364", "NR-005"),
    ("22.4% of variance", "22.4", "NR-044"),
    ("17.3% of variance", "17.3", "NR-044"),
    ("930 designs", "930", "NR-001"),
    ("31 generations each", "31", "NR-045"),
]:
    if has(sel, LAND):
        ok(f"landscape draws {sel!r} -> {row}")
    else:
        fail(f"landscape missing drawn string {sel!r}")
if has("all 930 designs", ATLAS):
    ok("atlas draws 930 (all 930 designs) -> NR-001")
else:
    fail("atlas missing the 930 string")
leak = [v for v in ("22.4", "17.3", "36.109", "27.364") if any(v in x for x in ATLAS)]
if leak:
    fail(f"atlas prints {leak} but draws no readout there")
else:
    ok("atlas prints no share, seed or winner numeral")

# ------------------------------------------------------------- 5. cites
say("\n[cites] the NR-005 / NR-006 mapping reads the register on every surface")
sources = [f"{KITS[s]['dir']}/{n}" for s in KITS
           for n in ("SPEC.md", "register-status.md", "captions-draft.md")]
sources += [STRIP, DRAFT]
PAIR = re.compile(r"(36\.109|27\.364)([^0-9]{0,24}?)(NR-\d+(?:\s*,\s*NR-\d+)*)")
cite_fails = 0
for path in sources:
    text = show_text(path)
    for i, line in enumerate(text.splitlines(), 1):
        for m in PAIR.finditer(line):
            val, ids = m.group(1), re.findall(r"NR-\d+", m.group(3))
            can = CANON[val]
            if ids == [can]:
                ok(f"{path}:{i}: {val} -> {can}")
            else:
                cite_fails += 1
                fail(f"{path}:{i}: {val} cites {','.join(ids)} - register reads {can}")
        m = re.match(r"\|\s*(NR-00[56])\s*\|", line.strip())
        if m:
            rid = m.group(1)
            want = "27.364" if rid == "NR-005" else "36.109"
            other = "36.109" if rid == "NR-005" else "27.364"
            found = other if other in line else (want if want in line else None)
            if found == want:
                ok(f"{path}:{i}: {rid} row reads {found}")
            elif found is None:
                note(f"{path}:{i}: {rid} row is descriptive (no numeral)")
            else:
                cite_fails += 1
                fail(f"{path}:{i}: {rid} row reads {found} - register reads {want}")
if cite_fails == 0:
    ok("zero cite defects across the ten lines and every surface")

for slug, k in KITS.items():
    d = k["dir"]
    hits = []
    for name in ("SPEC.md", "register-status.md", "captions-draft.md", "label-ledger.txt"):
        t = show_text(f"{d}/{name}")
        for i, line in enumerate(t.splitlines(), 1):
            if "NR-045" in line:
                hits.append(f"{name}:{i}")
    if slug == "pca-landscape":
        need = {"SPEC.md", "register-status.md", "captions-draft.md", "label-ledger.txt"}
        have = {h.split(":")[0] for h in hits}
        if need <= have:
            ok(f"landscape cites NR-045 on all four surfaces {sorted(need)}")
        else:
            fail(f"landscape NR-045 cites missing on {sorted(need - have)}")
    else:
        drawn = [h for h in hits if h.startswith(("label-ledger", "register-status"))]
        if not drawn:
            ok(f"atlas carries no NR-045 cite ({len(hits)} md mentions, none drawn)")
        else:
            note(f"atlas NR-045 mentions: {hits}")

# ------------------------------------------------------------- 6. stamps
say("\n[stamps] the recut stamps")
for slug, k in KITS.items():
    for s in ledgers[slug]:
        if s.startswith("projection:"):
            say(f"  {slug} projection: {s}")
            if "pending" in s:
                fail(f"{slug}: projection stamp still reads 'pending'")
            if slug == "pca-landscape":
                if "NR-044" in s and "script commit e23f226" in s:
                    ok("landscape projection stamp reads its signed form")
                else:
                    fail("landscape projection stamp wrong")
        if s.startswith("source:"):
            say(f"  {slug} source: {s}")
            if "NR-044" not in s:
                fail(f"{slug}: source stamp omits NR-044")
            if slug == "pca-landscape":
                if "NR-045" in s:
                    ok("landscape source stamp cites NR-044 and NR-045")
                else:
                    fail("landscape source stamp omits NR-045")
            else:
                if "NR-045" in s:
                    fail("atlas source stamp carries NR-045 (it draws no count)")
                else:
                    ok("atlas source stamp cites NR-044 only")

man_check = {slug: json.loads(show_text(f"{k['dir']}/manifest.json"))["script_commit"]
             for slug, k in KITS.items()}
for slug, k in KITS.items():
    stamp = [s for s in ledgers[slug] if s.startswith("projection:")][0]
    if man_check[slug] in stamp:
        ok(f"{slug}: stamp script commit == manifest script_commit ({man_check[slug]})")
    else:
        fail(f"{slug}: stamp script commit != manifest")

# -------------------------------------------------------- 7. recompute
say("\n[recompute] projection, fits, coords, counts, and the NR-045 anchors")
X, fits, sts, gens, isls, idxs = [], [], [], [], [], []
for i in (1, 2, 3):
    rows = list(csv.reader((ROOT / TELE / f"island_{i}" / "telemetry.csv").open()))
    hdr, data = rows[1], rows[2:]
    xi = [hdr.index(f"x{j}") for j in range(1, 11)]
    fi, si, gi, ii = hdr.index("fitness"), hdr.index("status"), hdr.index("gen"), hdr.index("idx")
    for r in data:
        X.append([float(r[j]) for j in xi])
        fits.append(float(r[fi])); sts.append(r[si]); gens.append(int(r[gi]))
        isls.append(i); idxs.append(int(r[ii]))
X, fits, sts, gens, isls, idxs = (np.array(v) for v in (X, fits, sts, gens, isls, idxs))

if len(X) == 930 and all(len(set(gens[isls == i])) == 31 for i in (1, 2, 3)) and \
        set(Counter((int(isls[i]), int(gens[i])) for i in range(len(X))).values()) == {10}:
    ok("31 generation indices per island, 10 draws each, 930 rows (NR-001, NR-045)")
else:
    fail("generation structure disagrees")
st_py = {str(k): int(v) for k, v in Counter(sts).items()}
if st_py == {"ok": 508, "reject": 301, "clearance_reject": 110, "reject_twist": 11}:
    ok(f"status counts {st_py} == NR-002")
else:
    fail(f"status counts {st_py} != NR-002")

z = (X - X.mean(0)) / X.std(0, ddof=1)
_, S, Vt = np.linalg.svd(z, full_matrices=False)
shares = S ** 2 / (S ** 2).sum() * 100.0
say(f"  shares: PC1 {shares[0]:.6f}  PC2 {shares[1]:.6f}  pair {shares[0]+shares[1]:.6f}")
if abs(shares[0] - 22.434667) < 5e-4 and abs(shares[1] - 17.263044) < 5e-4:
    ok("shares reproduce NR-044")
else:
    fail("shares disagree")

names = ["r_hub", "r_bottom", "target_Lr", "n_lines", "density_profile", "rotor_count",
         "bank_top", "bank_bottom", "blade_scale_top", "blade_scale_bottom"]
exp = {"PC1": {"n_lines": -0.5385, "rotor_count": -0.5222, "blade_scale_top": 0.5180,
               "target_Lr": 0.2517, "r_bottom": 0.2036},
       "PC2": {"bank_bottom": 0.5621, "blade_scale_bottom": -0.5605,
               "density_profile": -0.5018, "bank_top": -0.2444}}
for k, e in (("PC1", 0), ("PC2", 1)):
    got = {n: Vt[e][i] for i, n in enumerate(names)}
    if all(abs(got[n] - v) < 1.5e-4 for n, v in exp[k].items()):
        ok(f"{k} loadings reproduce NR-044 at 4 dp")
    else:
        fail(f"{k} loadings disagree")

seed_rows = np.where(gens == 0)[0]
s1 = [i for i in seed_rows if idxs[i] == 1]
if sorted(set(float(round(fits[i], 3)) for i in s1)) == [36.109] and all(sts[i] == "ok" for i in s1):
    ok("common seed 36.109 ok on every island (NR-006)")
else:
    fail("seed rows disagree")

feas = (sts == "ok") & (fits < 1e6)
per_gen = {}
for g in range(31):
    idxg = np.where(feas & (isls == 3) & (gens == g))[0]
    if len(idxg):
        per_gen[g] = float(min(fits[i] for i in idxg))
bsf = []
b = np.inf
for g in range(31):
    if g in per_gen:
        b = min(b, per_gen[g])
    bsf.append(b)
first26 = min(g for g in range(31) if abs(bsf[g] - 27.364) < 5e-4)
if first26 == 26 and abs(per_gen[25] - 28.315) < 5e-4 and abs((per_gen[25] - per_gen[26]) - 0.951) < 5e-4 \
        and all(abs(bsf[g] - 27.364) < 5e-4 for g in range(26, 31)):
    ok("NR-045 anchors hold: winner from gen 26, held to gen 30, closing step 0.951")
else:
    fail(f"NR-045 anchors: first26={first26} g25={per_gen.get(25)} g26={per_gen.get(26)}")

w3 = min(np.where(feas & (isls == 3))[0], key=lambda i: fits[i])
pc1 = z @ Vt[0]
pc2 = z @ Vt[1]
s0 = seed_rows[0]
if (abs(pc1[s0] - 0.531) < 5e-4 and abs(pc2[s0] + 1.297) < 5e-4
        and abs(pc1[w3] - 0.885) < 5e-4 and abs(pc2[w3] - 2.869) < 5e-4):
    ok("seed and winner coordinates reproduce the kit pins")
else:
    fail("coordinates disagree")

# ------------------------------------------------------- 8. runchecks
say("\n[runchecks] the three new in-script checks and the run log")
py = show_text(f"{KITS['pca-landscape']['dir']}/pca-landscape.py")
for pat, label in [
    ('"generation indices per island"', "generation-count check present in the generator"),
    ("1 dp drawn", "drawn-share checks present in the generator"),
]:
    if pat in py:
        ok(label)
    else:
        fail(f"missing in generator: {pat}")
for key, want in [("generation indices per island", "[31, 31, 31]"),
                  ("PC1 share (1 dp drawn)", "22.4"),
                  ("PC2 share (1 dp drawn)", "17.3")]:
    if lchk.get(key) == want:
        ok(f"checks.log: {key}: {want} (OK)")
    else:
        fail(f"checks.log: {key} reads {lchk.get(key)!r}, want {want!r}")

say("\n" + "=" * 72)
say(f"SUMMARY: {OKS} ok, {len(NOTES)} notes, {len(FAILS)} FAIL")
for n in NOTES:
    say(f"  note: {n}")
for f in FAILS:
    say(f"  FAIL: {f}")
say(f"re-census read at tip {head}")
say(f"kit bytes pinned at {fix}")
say("VERDICT: " + ("CLEAN" if not FAILS else "NOT CLEAN"))
say("=" * 72)
sys.exit(1 if FAILS else 0)
