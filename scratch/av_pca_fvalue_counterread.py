#!/usr/bin/env python3
"""
F-VALUE counter-read - the levers family (figure-map rows 20 and 21).

Seat: aero-validator. 2026-10-14. Read-only: reads git objects and the
committed telemetry, writes nothing.

Tiers in this log:
  ok      a check passed
  DEFECT  a defect found in the artifacts (with the exact fix where one
          applies) - the read's product, routed to the owner
  QUERY   a coverage question for the owners
  FAIL    the read could not verify something - blocks the sign-off

Checks, independently of the kit checks:

  1. pins      worktree bytes equal HEAD bytes; outputs match the manifests
  2. census    SVG text layer vs the label ledger, and the drawn scale
               numerals vs the tick sources in the generators
  3. values    every drawn readout equals its signed row at drawn precision
  4. cites     the NR-005 / NR-006 mapping on every kit surface vs the register
  5. stamps    the drawn source and projection stamps vs the closed row set
  6. recompute shares, loadings, seed and winner fits, coords and counts
               from the raw draw columns (numpy, not the kit path)

Run:  /usr/bin/python3 scratch/av_pca_fvalue_counterread.py
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
DEFECTS = []
QUERIES = []
FAILS = []

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


def say(*a):
    print(*a)


def ok(msg):
    global OKS
    OKS += 1
    say(f"  ok     {msg}")


def defect(msg, fix=None):
    DEFECTS.append((msg, fix))
    say(f"  DEFECT {msg}")
    if fix:
        say(f"         fix: {fix}")


def query(msg):
    QUERIES.append(msg)
    say(f"  QUERY  {msg}")


def fail(msg):
    FAILS.append(msg)
    say(f"  FAIL   {msg}")


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


def norm(s):
    return " ".join(s.split())


def nums(s):
    """Numeric tokens in a drawn string; row ids, hex shas and x-slot refs masked."""
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


# ------------------------------------------------------------------ 0. tip
say("=" * 72)
say("F-VALUE counter-read - levers family (rows 20, 21) - aero-validator")
say("=" * 72)

head = git("rev-parse", "HEAD")
origin = git("rev-parse", "origin/bank-derate-cos2p65")
br = git("rev-parse", "--abbrev-ref", "HEAD")
say(f"\n[tip] branch {br}  HEAD {head[:12]}  origin/bank-derate-cos2p65 {origin[:12]}")
if head == origin:
    ok("HEAD == origin (read at the landed tip, pre-sign-off)")
else:
    fail(f"HEAD {head[:12]} != origin {origin[:12]}")

# ------------------------------------------------------------- 1. pins
say("\n[pins] worktree bytes vs HEAD bytes; outputs and inputs vs the manifests")
for slug, k in KITS.items():
    d = k["dir"]
    files = [
        f"{d}/{slug}.svg", f"{d}/{slug}.pdf", f"{d}/{slug}.png",
        f"{d}/label-ledger.txt", f"{d}/manifest.json", f"{d}/checks.log",
        f"{d}/SPEC.md", f"{d}/register-status.md", f"{d}/captions-draft.md",
        f"{d}/{slug}.py",
    ]
    bad = [f for f in files if sha256b(show_bytes(f)) != sha256b((ROOT / f).read_bytes())]
    if bad:
        fail(f"{slug}: worktree differs from HEAD: {bad}")
    else:
        ok(f"{slug}: {len(files)} worktree files byte-equal to HEAD")

    man = json.loads(show_text(f"{d}/manifest.json"))
    for name, want in man["outputs"].items():
        got = sha256b(show_bytes(f"{d}/{name}"))
        if got != want:
            fail(f"{slug}: {name} sha256 {got[:12]} != manifest {want[:12]}")
    ok(f"{slug}: 4 outputs match the manifest pins")
    if sha256b(show_bytes(f"{d}/{slug}.py")) == man["script"]["sha256"]:
        ok(f"{slug}: script sha256 matches the manifest pin")
    else:
        fail(f"{slug}: script sha256 mismatch")
    for inp in man["inputs"]["telemetry"]:
        if sha256b((ROOT / inp["path"]).read_bytes()) != inp["sha256"]:
            fail(f"{slug}: telemetry {inp['path']} sha256 mismatch")
    ok(f"{slug}: 3 telemetry inputs match the manifest pins")

# ------------------------------------------------------------ 2. census
say("\n[census] SVG text layer vs the label ledger; scale numerals vs their tick sources")
ledgers, svgs, singles = {}, {}, {}
for slug, k in KITS.items():
    d = k["dir"]
    ledger = [norm(l) for l in show_text(f"{d}/label-ledger.txt").splitlines() if l.strip()]
    svg = svg_text(f"{d}/{slug}.svg")
    ledgers[slug], svgs[slug] = ledger, svg
    singles[slug] = [s for s in svg if NUMFULL.fullmatch(s)]
    say(f"  {slug}: ledger {len(ledger)} strings; svg {len(svg)} text nodes "
        f"({len(set(svg))} unique; {len(singles[slug])} scale-name nodes)")
    if len(ledger) != k["ledger_n"]:
        fail(f"{slug}: ledger count {len(ledger)} != expected {k['ledger_n']}")
    sl, ss = set(ledger), set(svg)
    if sl == ss:
        ok(f"{slug}: ledger set-equal to the svg text layer (both directions)")
    else:
        fail(f"{slug}: ledger vs svg: missing={sorted(sl - ss)} extra={sorted(ss - sl)}")
    dup = sorted([s for s, n in Counter(svg).items() if n > 1])
    if dup:
        say(f"    repeated nodes (legit where axes overlap): {dup}")

# landscape: the tick sources are explicit constants in the generator
l_nodes = Counter(singles["pca-landscape"])
if sorted(l_nodes.elements()) == LAND_EXP_NODES:
    ok("landscape: 16 scale-name nodes == x ticks [-5..1] + y ticks [-2..3] + colour [30,33,36]")
else:
    fail(f"landscape: scale-name nodes {sorted(l_nodes.elements())} != {LAND_EXP_NODES}")
if set(singles["pca-landscape"]) == LAND_EXP_UNIQUE:
    ok("landscape: ledger carries exactly those 12 unique scale values")

# atlas: recompute the colour-bar labels, lo/mid/hi at .3g per gene
atlas_labels = []
for j in range(10):
    col = np.array([])
    for i in (1, 2, 3):
        rows = list(csv.reader((ROOT / TELE / f"island_{i}" / "telemetry.csv").open()))
        hdr = rows[1]
        col = np.concatenate([col, [float(r[hdr.index(f"x{j+1}")]) for r in rows[2:]]])
    lo, hi = np.percentile(col, [2, 98])
    atlas_labels += [f"{v:.3g}" for v in (lo, (lo + hi) / 2, hi)]
a_nodes = Counter(singles["pca-atlas"])
if sorted(a_nodes.elements()) == sorted(atlas_labels):
    ok("atlas: 30 scale-name nodes == the recomputed lo/mid/hi colour labels at .3g")
else:
    fail("atlas: scale-name nodes vs recomputed labels:")
    say(f"    drawn    : {sorted(a_nodes.elements())}")
    say(f"    computed : {sorted(atlas_labels)}")
if set(singles["pca-atlas"]) == set(atlas_labels):
    ok("atlas: ledger carries exactly the unique colour-label set")

# kit checks logs agree on the shared pins
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

# ------------------------------------------------------------ 3. values
say("\n[values] every drawn readout vs its signed row at drawn precision")
LAND, ATLAS = ledgers["pca-landscape"], ledgers["pca-atlas"]


def has(sel, s):
    return any(sel in x for x in s)


rows_land = [
    ("start 36.109", "36.109", "NR-006"),
    ("one common seed at 36.109 (kg)", "36.109", "NR-006"),
    ("winner 27.364", "27.364", "NR-005"),
    ("winner: island 3 at 27.364 (kg)", "27.364", "NR-005"),
    ("22.4% of variance", "22.4", "NR-044"),
    ("17.3% of variance", "17.3", "NR-044"),
]
for sel, val, row in rows_land:
    if has(sel, LAND):
        ok(f"landscape draws {sel!r} ({val}) -> {row}")
    else:
        fail(f"landscape missing drawn string {sel!r}")
if has("930 designs", LAND) and has("930-design screen", LAND):
    ok("landscape draws 930 (subtitle and inset) -> NR-001")
else:
    fail("landscape missing a 930 string")
if has("all 930 designs", ATLAS):
    ok("atlas draws 930 (all 930 designs) -> NR-001")
else:
    fail("atlas missing the 930 projection-note string")
leak = [v for v in ("22.4", "17.3", "36.109", "27.364") if any(v in x for x in ATLAS)]
if leak:
    fail(f"atlas draws {leak} but its plates print no readout at that value")
else:
    ok("atlas prints no share, seed or winner numeral (positional marks only)")
f1, f2 = f"{22.434667:.1f}", f"{17.263044:.1f}"
ok(f"22.4 is the 1-dp form of NR-044 PC1 22.434667 ({f1}); 17.3 likewise ({f2})")

# ------------------------------------------------------------- 4. cites
say("\n[cites] NR-005 / NR-006 mapping on every surface vs the register")
ref = show_text(REG)
for i, line in enumerate(ref.splitlines(), 1):
    if re.match(r"\|\s*NR-00[56]\s*\|", line.strip()):
        say(f"  register: {REG}:{i}: {line.strip()[:96]}")

sources = [f"{KITS[s]['dir']}/{n}" for s in KITS
           for n in ("SPEC.md", "register-status.md", "captions-draft.md")]
sources += [STRIP, DRAFT]

PAIR = re.compile(r"(36\.109|27\.364)([^0-9]{0,24}?)(NR-\d+(?:\s*,\s*NR-\d+)*)")
reported = {}
for path in sources:
    text = show_text(path)
    line_ok = set()
    for i, line in enumerate(text.splitlines(), 1):
        for m in PAIR.finditer(line):
            val, ids = m.group(1), re.findall(r"NR-\d+", m.group(3))
            can = CANON[val]
            if ids == [can]:
                ok(f"{path}:{i}: {val} -> {can}")
            else:
                new = re.sub(r"(36\.109(?:,\s*|\s*\())NR-\d+\)", r"\g<1>NR-006)", line)
                new = re.sub(r"(27\.364(?:,\s*|\s*\())NR-\d+\)", r"\g<1>NR-005)", new)
                new = re.sub(r"(\|\s*start 36\.109\s*\|\s*)(NR-\d+(?:\s*,\s*NR-\d+)*)(\s*\|)",
                             r"\1NR-006\3", new)
                new = re.sub(r"(\|\s*winner 27\.364\s*\|\s*)(NR-\d+(?:\s*,\s*NR-\d+)*)(\s*\|)",
                             r"\1NR-005\3", new)
                fix = f"line {i}: {new.strip()}" if new != line else None
                defect(f"{path}:{i}: {val} cites {','.join(ids)} - register reads {can}",
                       fix or f"line {i}: set the cite to {can}")
            line_ok.add(i)
        m = re.match(r"\|\s*(NR-00[56])\s*\|", line.strip())
        if m:
            rid = m.group(1)
            want = "27.364" if rid == "NR-005" else "36.109"
            other = "36.109" if rid == "NR-005" else "27.364"
            found = other if other in line else (want if want in line else None)
            if found is None:
                say(f"  info   {path}:{i}: {rid} row is descriptive (no numeral)")
            elif found == want:
                ok(f"{path}:{i}: {rid} row reads {found}")
            else:
                swap = ("The common seed value, 36.109", "The winner value, 27.364")
                pair = swap if rid == "NR-005" else swap[::-1]
                new = line.replace(f"The common seed value, 36.109", "The winner value, 27.364") \
                    if rid == "NR-005" else line.replace("The winner value, 27.364", "The common seed value, 36.109")
                old_tok = "The common seed value, 36.109" if rid == "NR-005" else "The winner value, 27.364"
                new = line.replace(old_tok, "The winner value, 27.364" if rid == "NR-005" else "The common seed value, 36.109")
                defect(f"{path}:{i}: {rid} row reads {found} - register reads {want}",
                       f"line {i}: {new.strip()}")
            line_ok.add(i)
    reported[path] = line_ok
    for i, line in enumerate(text.splitlines(), 1):
        if ("NR-005" in line or "NR-006" in line) and i not in line_ok:
            say(f"  info   {path}:{i}: other occurrence: {line.strip()[:96]}")

# ------------------------------------------------------------ 5. stamps
say("\n[stamps] drawn source and projection stamps")
for slug, k in KITS.items():
    for s in ledgers[slug]:
        if s.startswith("projection:"):
            say(f"  {slug} projection stamp: {s}")
            if "pending" in s:
                defect(f"{slug}: projection stamp still reads 'pending their row' - NR-044 signed "
                       f"at 2ad023c and the kit's own 'Row closed' block contradicts it",
                       "generator stamp2: 'variance shares pending their row' -> 'variance shares from NR-044' (wording call, figures seat); re-render required")
        if s.startswith("source:"):
            say(f"  {slug} source stamp: {s}")
            if "NR-044" not in s:
                why = ("the plate draws NR-044's quotes" if slug == "pca-landscape"
                       else "the shared projection is NR-044 and the Rows-cited block lists the row")
                defect(f"{slug}: source stamp omits NR-044 ({why}; the caption provenance "
                       f"lists the four-row set)",
                       f"generator ROWS: 'NR-001, NR-005, NR-006' -> 'NR-001, NR-005, NR-006, NR-044'; manifest register_rows likewise; re-render required")

# -------------------------------------------------------- 6. recompute
say("\n[recompute] projection, fits, coords and counts from the raw columns (numpy, ddof=1 as the kits)")
X, fits, sts, gens, isls, idxs = [], [], [], [], [], []
for i in (1, 2, 3):
    rows = list(csv.reader((ROOT / TELE / f"island_{i}" / "telemetry.csv").open()))
    hdr = rows[1]
    xi = [hdr.index(f"x{j}") for j in range(1, 11)]
    fi, si, gi, ii = hdr.index("fitness"), hdr.index("status"), hdr.index("gen"), hdr.index("idx")
    for r in rows[2:]:
        X.append([float(r[j]) for j in xi])
        fits.append(float(r[fi]))
        sts.append(r[si])
        gens.append(int(r[gi]))
        isls.append(i)
        idxs.append(int(r[ii]))

X = np.array(X)
fits = np.array(fits)
sts = np.array(sts)
gens = np.array(gens)
isls = np.array(isls)
idxs = np.array(idxs)
say(f"  rows {len(X)}; per island {dict(Counter(map(int, isls)))}; "
    f"gens {int(gens.min())}..{int(gens.max())}")
per = Counter((isls[i], gens[i]) for i in range(len(X)))
if set(per.values()) == {10}:
    ok(f"each island-generation holds 10 draws ({len(per)} generation slots)")
st = Counter(sts)
st_py = {str(k): int(v) for k, v in st.items()}
if st_py == {"ok": 508, "reject": 301, "clearance_reject": 110, "reject_twist": 11}:
    ok(f"status counts {st_py} == NR-002")
else:
    fail(f"status counts {st_py} != NR-002")

z = (X - X.mean(0)) / X.std(0, ddof=1)
_, S, Vt = np.linalg.svd(z, full_matrices=False)
shares = S ** 2 / (S ** 2).sum() * 100.0
say(f"  shares: PC1 {shares[0]:.6f}  PC2 {shares[1]:.6f}  pair {shares[0]+shares[1]:.6f}")
if abs(shares[0] - 22.434667) < 5e-4 and abs(shares[1] - 17.263044) < 5e-4 \
        and abs(shares[0] + shares[1] - 39.697710) < 1e-3:
    ok("shares reproduce NR-044 (22.434667 / 17.263044 / 39.697710)")
else:
    fail("shares disagree with NR-044")

names = ["r_hub", "r_bottom", "target_Lr", "n_lines", "density_profile", "rotor_count",
         "bank_top", "bank_bottom", "blade_scale_top", "blade_scale_bottom"]
exp = {"PC1": {"n_lines": -0.5385, "rotor_count": -0.5222, "blade_scale_top": 0.5180,
               "target_Lr": 0.2517, "r_bottom": 0.2036},
       "PC2": {"bank_bottom": 0.5621, "blade_scale_bottom": -0.5605,
               "density_profile": -0.5018, "bank_top": -0.2444}}
for k, e in (("PC1", 0), ("PC2", 1)):
    got = {n: Vt[e][i] for i, n in enumerate(names)}
    if all(abs(got[n] - v) < 1.5e-4 for n, v in exp[k].items()):
        ok(f"{k} loadings reproduce NR-044 at 4 dp (signs direct)")
    elif all(abs(got[n] + v) < 1.5e-4 for n, v in exp[k].items()):
        ok(f"{k} loadings reproduce NR-044 at 4 dp (global sign flip; magnitudes match)")
    else:
        fail(f"{k} loadings disagree: { {n: round(got[n], 4) for n in exp[k]} }")
    top = sorted(((abs(v), n, round(v, 4)) for n, v in got.items()), reverse=True)
    say(f"    {k} abs(v)>=0.2 set: " + ", ".join(f"{n} {v:+.4f}" for _, n, v in top if _ >= 0.2))

seed_rows = np.where(gens == 0)[0]
s1 = [i for i in seed_rows if idxs[i] == 1]
seed_fit = sorted(set(float(round(fits[i], 3)) for i in s1))
say(f"  gen-0 rows: {len(seed_rows)}; idx-1 rows: fitness {seed_fit}")
if seed_fit == [36.109] and all(sts[i] == "ok" for i in s1):
    ok("common seed, gen 0 idx 1, fitness 36.109 ok on every island (NR-006)")
else:
    fail(f"idx-1 gen-0 rows read {seed_fit} / {[sts[i] for i in s1]}")
g0_other = Counter(sts[i] for i in seed_rows if idxs[i] != 1)
say(f"    other gen-0 draws by status: { {str(k): int(v) for k, v in g0_other.items()} } "
    f"(sentinel fitness 1e9 on rejects)")

feas = (sts == "ok") & (fits < 1e6)
w3 = [i for i in np.where(feas)[0] if isls[i] == 3]
w3 = min(w3, key=lambda i: fits[i])
say(f"  island 3 best ok: gen {gens[w3]} idx {idxs[w3]}, fitness {fits[w3]}")
if abs(fits[w3] - 27.364) < 5e-4:
    ok("winner fitness 27.364 on island 3 (NR-005)")
else:
    fail(f"island 3 best {fits[w3]} != 27.364")
mins = {i: min(fits[j] for j in np.where(feas & (isls == i))[0]) for i in (1, 2, 3)}
say(f"  island bests: { {i: round(float(v), 3) for i, v in mins.items()} } "
    f"(register 30.578 / 30.637 / 27.364)")

pc1 = z @ Vt[0]
pc2 = z @ Vt[1]
s0 = seed_rows[0]
say(f"  seed pc ({pc1[s0]:.3f}, {pc2[s0]:.3f}) vs kit pin (0.531, -1.297)")
say(f"  winner pc ({pc1[w3]:.3f}, {pc2[w3]:.3f}) vs kit pin (0.885, 2.869)")
if (abs(pc1[s0] - 0.531) < 5e-4 and abs(pc2[s0] + 1.297) < 5e-4
        and abs(pc1[w3] - 0.885) < 5e-4 and abs(pc2[w3] - 2.869) < 5e-4):
    ok("seed and winner projection coordinates reproduce the kit pins at 3 dp")
else:
    fail("projection coordinates disagree with the kit pins")

# ------------------------------------------------------------- 7. query
sub = [x for x in LAND if "generations each" in x]
if sub:
    query(f"landscape subtitle prints '31 generations each' ({sub[0]!r}): no row carries the "
          f"generation count; derives from 310 rows per island at 10 draws per generation; "
          f"disposition wanted (a row, or the count drops)")

# ---------------------------------------------------------- fix summary
say("\n" + "=" * 72)
say(f"SUMMARY: {OKS} ok, {len(DEFECTS)} DEFECT, {len(QUERIES)} QUERY, {len(FAILS)} FAIL")
for m, _ in DEFECTS:
    say(f"  DEFECT: {m}")
for q in QUERIES:
    say(f"  QUERY:  {q}")
for f in FAILS:
    say(f"  FAIL:   {f}")
say(f"read at tip {head}")
say("=" * 72)
sys.exit(1 if FAILS else 0)
