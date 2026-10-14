#!/usr/bin/env python3
"""F-VALUE counter-read: the Harris-3.5 mechanism-pair plates (aero-validator, 2026-10-14).

Independent pass over the delivered ring-utilisation and twist-limit kits,
read at tip 25eb0eb, kit bytes pinned at e4ff3c1, script commit 671ab96.

Sections:
  [1] manifest pins recompute (script, extract, every output);
  [2] stamps resolve (commit ancestry, path drift, blob identity);
  [3] F-VALUE: every drawn value recomputed from the committed extract
      against the signed register rows at the drawn precision;
  [4] F-LABEL re-walk (SVG text set vs ledger set, both directions);
  [5] numeric census over both ledgers (nothing unclassified);
  [6] cite surfaces: presence and direction (notes, captions);
  [7] F-REPRO: two fresh out-of-tree runs per kit, byte-compared;
  [8] "no drawn value moves" (v1 against v2 drawn sets);
  [9] the draft figure-provenance appendix, with computed fix lines;
      the review copy (draft-live.docx) checked beside it.

Reads committed bytes only. Runs no simulator.
Exit nonzero only on fail; defects and queries route to owners.
"""
import csv
import hashlib
import html
import json
import math
import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
FIGS = ROOT / "docs/reporting/figures"
DRAFT = ROOT / "docs/reporting/drafts/2026-10-08-report-first-draft.md"
REGISTER = ROOT / "docs/reporting/numbers-register.md"
DOCX = ROOT / "scratch/report-pdf-build/draft-live.docx"
SCRATCH = ROOT / "scratch"
TIP = "25eb0eb"
PIN = "e4ff3c1"
H1 = "671ab96"
H0 = "eacf073"

OK = 0
DEFECT = 0
QUERY = 0
FAIL = 0


def ok(msg):
    global OK
    OK += 1
    print(f"  ok     {msg}")


def defect(msg):
    global DEFECT
    DEFECT += 1
    print(f"  DEFECT {msg}")


def query(msg):
    global QUERY
    QUERY += 1
    print(f"  QUERY  {msg}")


def fail(msg):
    global FAIL
    FAIL += 1
    print(f"  FAIL   {msg}")


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read_text(path):
    return Path(path).read_text(encoding="utf-8")


def git(*args):
    r = subprocess.run(["git", "-C", str(ROOT), *args],
                       capture_output=True, text=True)
    return r.returncode, r.stdout.strip(), r.stderr.strip()


KITS = {
    "ring-utilisation": FIGS / "ring-utilisation",
    "twist-limit": FIGS / "twist-limit",
}
KITFILES = ["{s}.svg", "{s}.pdf", "{s}.png", "label-ledger.txt", "manifest.json"]


def load_extract():
    rows = {"segment": [], "ring": []}
    with (FIGS / "pair-extract/extract-winner-operating-point.csv").open(
            newline="", encoding="utf-8") as fh:
        lines = [ln for ln in fh if not ln.startswith("#")]
    for row in csv.DictReader(lines):
        rows[row["block"]].append(row)
    return rows


def fmt_fos(v):
    if v >= 1e4:
        return f"{round(v):,}"
    return f"{v:.3f}"


print(f"[0] context   tip {TIP}   kit pin {PIN}   script {H1}")

# ---------------------------------------------------------------- [1] pins
print("[1] manifest pins recompute")
manifests = {}
for slug, d in KITS.items():
    man = json.loads((d / "manifest.json").read_text())
    manifests[slug] = man
    (ok if sha256(d / f"{slug}.py") == man["script"]["sha256"]
        else fail)(f"{slug}: script sha256")
    extract = FIGS / "pair-extract/extract-winner-operating-point.csv"
    (ok if sha256(extract) == man["inputs"]["extract"]["sha256"]
        else fail)(f"{slug}: extract sha256")
    for out, want in man["outputs"].items():
        (ok if sha256(d / out) == want else fail)(f"{slug}: output pin {out}")
    (ok if H1 in man["command"] else fail)(f"{slug}: command cite {H1}")

# ---------------------------------------------------------------- [2] stamps
print("[2] stamps resolve")
rc, out, _ = git("merge-base", "--is-ancestor", "f8114be", "HEAD")
(ok if rc == 0 else fail)("authority commit f8114be is an ancestor of HEAD")
rc, out, _ = git("merge-base", "--is-ancestor", "671ab96", "HEAD")
(ok if rc == 0 else fail)("script commit 671ab96 is an ancestor of HEAD")
rc, out, _ = git("log", "--format=%h", f"{PIN}..HEAD",
                 "docs/reporting/figures/ring-utilisation/",
                 "docs/reporting/figures/twist-limit/")
(ok if out == "" else fail)("no kit path moves in e4ff3c1..HEAD")

revs = []
for slug in KITS:
    for f in ["{s}.svg", "{s}.pdf", "{s}.png", "label-ledger.txt",
              "manifest.json"]:
        fn = f.format(s=slug)
        p = f"docs/reporting/figures/{slug}/{fn}"
        revs += [f"{PIN}:{p}", f"HEAD:{p}", f"origin/bank-derate-cos2p65:{p}"]
rc, out, _ = git("rev-parse", *revs)
shas = out.splitlines()
blob_ok = True
for i in range(0, len(shas), 3):
    if not (shas[i] == shas[i + 1] == shas[i + 2]):
        blob_ok = False
(ok if blob_ok else fail)(
    f"blob identity pin == HEAD == origin across all 10 kit files")

hdr = read_text(FIGS / "pair-extract/extract-winner-operating-point.csv")
for token, name in [("computing commit: f8114be60e6c1ff842b90d2267d588ddc40e0098",
                     "CSV computing commit f8114be"),
                    ("data commit dd3cc6a", "CSV data commit dd3cc6a"),
                    ("run-id: pair-extract-2026-10-08-winner-ops",
                     "CSV capture id")]:
    (ok if token in hdr else fail)(name)

reg = read_text(REGISTER)
for token in ("1724859", "49.99999483862295"):
    (ok if token in reg else fail)(f"capture stamp token {token} in register")
for slug, d in KITS.items():
    ledger = read_text(d / "label-ledger.txt")
    svg = read_text(d / f"{slug}.svg")
    for token in (f"script commit {H1}", "authority commit f8114be"):
        (ok if token in ledger else fail)(f"{slug}: stamp in ledger ({token[:28]})")
        (ok if token in svg else fail)(f"{slug}: stamp in SVG ({token[:28]})")

# ------------------------------------------------------------ [3] F-VALUE
print("[3a] F-VALUE ring plate: recompute from the committed extract")
data = load_extract()
ring_reg_line = next(ln for ln in reg.splitlines() if ln.startswith("| NR-021 |"))
ring_chunks = {}
for m in re.finditer(
        r"R(\d)(?: hub)? ([\d.eE+-]+) = ([\d.eE+-]+) \+ ([\d.eE+-]+),"
        r" FoS ([\d.]+?)\.?(?= |$)", ring_reg_line):
    ring_chunks[f"R{m.group(1)}"] = m.groups()[1:]

ring_ledger = set((KITS["ring-utilisation"] / "label-ledger.txt")
                  .read_text().splitlines())
ring_readouts = set()
for r in data["ring"]:
    rid = r["id"]
    maxu = float(r["max_util"])
    ax = float(r["util_axial"])
    bd = float(r["util_bending"])
    fos = float(r["ring_fos"])
    resid = (ax + bd) - maxu
    (ok if abs(resid) <= math.ulp(maxu) else fail)(
        f"{rid}: axial + bending = max_util (residual {resid:.3g})")
    inv = 1.0 / maxu
    (ok if abs(inv - fos) <= math.ulp(fos) else fail)(
        f"{rid}: ring_fos = 1 / max_util (ulp {abs(inv - fos):.3g})")
    tok = ring_chunks.get(rid)
    if tok is None:
        fail(f"{rid}: register chunk not parsed")
        continue
    pairs = [(r["max_util"], tok[0]), (r["util_axial"], tok[1]),
             (r["util_bending"], tok[2]), (r["ring_fos"], tok[3])]
    match = all(a == b for a, b in pairs)
    (ok if match else fail)(
        f"{rid}: extract tokens string-equal to NR-021 chunk")
    form = f"FoS {fmt_fos(fos)}"
    ring_readouts.add(form)
    (ok if form in ring_ledger else fail)(f"{rid}: drawn readout {form}")
(ok if ring_readouts == {"FoS 15.033", "FoS 29.807", "FoS 30.087",
                         "FoS 326,974", "FoS 35.236"} else fail)(
    "ring readout set reads 15.033 / 29.807 / 30.087 / 35.236 / 326,974")

print("[3b] F-VALUE twist plate: recompute from the committed extract")
twist_ledger = set((KITS["twist-limit"] / "label-ledger.txt")
                   .read_text().splitlines())
twist_reg_line = next(ln for ln in reg.splitlines() if ln.startswith("| NR-022 |"))
alt = next(ln for ln in reg.splitlines() if ln.startswith("| NR-023 |"))
m040 = next(ln for ln in reg.splitlines() if ln.startswith("| NR-040 |"))

alphas = {k: v.rstrip(".")
          for k, v in re.findall(r"S(\d) ([\d.]+)°",
                                 twist_reg_line.split("dcrit:")[0])}
dcrit_part = twist_reg_line.split("dcrit:")[1]
gm = re.search(r"S1 to S4 ([\d.]+)°", dcrit_part)
s5m = re.search(r"S5 ([\d.]+)°", dcrit_part)
if gm is None or s5m is None:
    fail("register dcrit parse failed")
    group_dcrit, s5_dcrit = "?", "?"
else:
    group_dcrit, s5_dcrit = gm.group(1), s5m.group(1)
tq_part, cap_part = alt.split("torque_capacity:")
torques = {k: v.rstrip(".")
           for k, v in re.findall(r"S(\d) ([\d.]+)", tq_part)}
caps = {k: v.rstrip(".")
        for k, v in re.findall(r"S(\d) ([\d.]+)", cap_part)}

seg_ok = True
for s in data["segment"]:
    sid = s["id"]  # S1..S5
    n = sid[1]
    checks = [
        (s["abs_dalpha_deg"], alphas[n], f"{sid} abs_dalpha"),
        (s["segment_torque_Nm"], torques[n], f"{sid} segment torque"),
        (s["torque_capacity_Nm"], caps[n], f"{sid} capacity"),
    ]
    if n in ("1", "2", "3"):
        checks.append((s["dcrit_deg"], group_dcrit, f"{sid} dcrit (group)"))
    elif n == "4":
        checks.append((s["dcrit_deg"], "98.85908296054016",
                       f"{sid} dcrit (own value, 2026-10-09 amend)"))
    else:
        checks.append((s["dcrit_deg"], s5_dcrit, f"{sid} dcrit"))
    for got, want, label in checks:
        if got == want:
            ok(f"{label}: string-equal to register")
        else:
            seg_ok = False
            fail(f"{label}: extract {got} vs register {want}")

twist_drawn = set()
for s in data["segment"]:
    twist_drawn |= {f"{float(s['abs_dalpha_deg']):.1f}",
                    f"{float(s['dcrit_deg']):.1f}",
                    f"{float(s['segment_torque_Nm']):.1f}",
                    f"{float(s['torque_capacity_Nm']):.1f}"}
missing = twist_drawn - twist_ledger
(ok if not missing else fail)(
    f"twist drawn value set present in ledger ({len(twist_drawn)} forms)")

margins = []
for s in data["segment"]:
    div = float(s["torque_capacity_Nm"]) / float(s["segment_torque_Nm"])
    margins.append(repr(div))
m040_toks = [(k, v.rstrip("."))
             for k, v in re.findall(r"S(\d) ([\d.]+)", m040)]
for (n, tok), got in zip(m040_toks, margins):
    (ok if got == tok else fail)(f"S{n} margin recomputes {tok} (repr-equal)")
(ok if min(float(x) for x in margins) == float(margins[0]) else fail)(
    "S1 carries the least margin (2.03)")

print("[3c] the floor arithmetic")
floor = math.degrees(math.asin(1.0 / 1.05))
form = f"{floor:.2f}"
(ok if form == "72.25" else fail)(
    f"asin(1/1.05) = {floor:.6f} deg, drawn form {form}")
(ok if f"realisability floor {form}°" in twist_ledger else fail)(
    "floor label present in ledger")
dec = read_text(ROOT / "DECISIONS.md")
(ok if "1/1.05" in dec and "72.25" in dec else fail)(
    "DECISIONS.md carries the 1/1.05 basis and the 72.25 deg floor")

# -------------------------------------------------------------- [4] F-LABEL
print("[4] F-LABEL re-walk (independent extraction)")
for slug, d in KITS.items():
    ledger = set((d / "label-ledger.txt").read_text().splitlines())
    svg = (d / f"{slug}.svg").read_text()
    found = {html.unescape(re.sub(r"<[^>]+>", "", m)).strip()
             for m in re.findall(r"<text[^>]*>(.*?)</text>", svg, flags=re.S)}
    missing = found - ledger
    extra = ledger - found
    (ok if not missing and not extra else fail)(
        f"{slug}: SVG text set == ledger set both ways "
        f"({len(ledger)} strings, missing {len(missing)}, extra {len(extra)})")

# -------------------------------------------------------------- [5] census
print("[5] numeric census over both ledgers")


def classify_ring(s):
    ticks = {"1", "10⁻¹", "10⁻²", "10⁻³", "10⁻⁴", "10⁻⁵", "10⁻⁶"}
    labels = {"R1", "R2", "R3", "R4", "R5", "R6 (hub)",
              "R1 — ground ring · not checked (ground-supported)"}
    texts = {
        "Beam-column interaction per checked ring · island-3 winner operating point",
        "Every checked ring sits far below its fail boundary",
        "fail boundary",
        "fail boundary — interaction at the unit value",
        "readout: ring FoS = 1 / ring utilisation",
        "utilisation (N/N_crit + √(M_ip²+M_oop²)/M_el, worst beam)",
        "utilisation — beam-column interaction, log scale",
    }
    stamp1 = ("source: data commit dd3cc6a · extract "
              "extract-winner-operating-point.csv · capture "
              "pair-extract-2026-10-08-winner-ops")
    stamp2 = ("s = 1724859 (t = 49.99999483862295 s) · rows NR-021 · "
              "script commit 671ab96 · authority commit f8114be")
    if s in ticks:
        return "tick"
    if s in ring_readouts:
        return "readout"
    if s in labels:
        return "label"
    if s in texts:
        return "text"
    if s in (stamp1, stamp2):
        return "stamp"
    return None


def classify_twist(s):
    ticks = {"0", "20", "40", "60", "80", "100", "200", "400", "600", "800",
             "1000"}
    labels = {"R1", "R2", "R3", "R4", "R5", "R6 (hub)",
              "S1", "S2", "S3", "S4", "S5"}
    texts = {
        "A — twist: transmitted twist |Δα| against its binding limit, the realisability floor",
        "B — torque: segment torque against torsional capacity, paired at the same state",
        "Every segment of the winner runs well inside its binding limit",
        "Transmitted twist against its binding limit, the realisability floor · shaft profile S1–S5, ground to hub · island-3 winner operating point",
        "crossing limit δα* — every segment gates on its own collapse-detector limit. That limit is not the over-twist limit.",
        "no limit — the segment's tether is shorter than the sum of its end radii. Its lines cannot reach the axis,",
        "so no over-twist limit exists. Tether break strain and ring compression carry the limit instead.",
        "realisability floor — sin Δα ≤ 1/1.05 holds the geometry only to 72.25°.",
        "transmitted twist (panel A)",
        "segment torque (panel B)",
        "δcrit over-twist limit",
        "torsional capacity",
        "twist angle — degrees",
        "torque — N·m",
        "realisability floor 72.25°",
    }
    stamp1 = ("source: data commit dd3cc6a · extract "
              "extract-winner-operating-point.csv · capture "
              "pair-extract-2026-10-08-winner-ops")
    stamp2 = ("s = 1724859 (t = 49.99999483862295 s) · rows NR-022 · "
              "NR-023 · script commit 671ab96 · authority commit f8114be")
    if s in ticks:
        return "tick"
    if s in twist_drawn:
        return "drawn"
    if s in labels:
        return "label"
    if s in texts:
        return "text"
    if s in (stamp1, stamp2):
        return "stamp"
    return None


for slug, cls, ledger in [
        ("ring-utilisation", classify_ring, ring_ledger),
        ("twist-limit", classify_twist, twist_ledger)]:
    un = [s for s in sorted(ledger) if cls(s) is None]
    (ok if not un else fail)(
        f"{slug}: every ledger string classifies ({len(ledger)} strings, "
        f"{len(un)} unclassified)")
    for s in un:
        print(f"         UNCLASSIFIED {s!r}")

# ------------------------------------------------------- [6] cite surfaces
print("[6] cite surfaces: presence and direction")
rs_ring = read_text(KITS["ring-utilisation"] / "register-status.md")
rs_twist = read_text(KITS["twist-limit"] / "register-status.md")
cap_ring = read_text(KITS["ring-utilisation"] / "captions.md")
cap_twist = read_text(KITS["twist-limit"] / "captions.md")
for token, where in [
        ("326,974", rs_ring), ("326974.1011237028", rs_ring),
        ("15.033", rs_ring), ("15.032534020684876", rs_ring),
        ("FoS 15.033", cap_ring), ("326,974 (NR-021)", cap_ring),
        ("FoS 2.5 or above (NR-015)", cap_ring),
        ("2.03 (NR-040)", cap_twist), ("sin Δα ≤ 1/1.05", cap_twist),
        ("trpt_twist_limit", cap_twist), ("2.0288", rs_twist),
        ("2.6938", rs_twist)]:
    (ok if token in where else fail)(f"cite surface carries {token!r}")
bend_share_max = max(
    float(r["util_bending"]) / float(r["max_util"])
    for r in data["ring"]
    if r["id"] != "R5" and float(r["util_bending"]) > 0)
(ok if bend_share_max < 0.0005 else fail)(
    f"ring caption bound: max bending share on the other rings "
    f"{bend_share_max*100:.4f} per cent < 0.05")

# -------------------------------------------------------------- [7] F-REPRO
print("[7] F-REPRO: two fresh out-of-tree runs per kit")
for slug in KITS:
    runs = []
    for n in (1, 2):
        outdir = SCRATCH / f"av_fig35_run{n}_{slug.split('-')[0]}"
        cmd = ["/usr/bin/python3",
               str(KITS[slug] / f"{slug}.py"),
               "--script-commit", H1, "--outdir", str(outdir)]
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode != 0:
            fail(f"{slug} run {n}: generator rc {r.returncode}")
            continue
        if "F-LABEL self-check: OK" not in r.stdout:
            fail(f"{slug} run {n}: F-LABEL self-check missing")
        runs.append({f.format(s=slug): sha256(outdir / f.format(s=slug))
                     for f in KITFILES})
    if len(runs) == 2:
        same = all(runs[0][f] == runs[1][f] for f in runs[0])
        (ok if same else fail)(f"{slug}: run 1 == run 2 across 5 outputs")
        committed = {f.format(s=slug): sha256(KITS[slug] / f.format(s=slug))
                     for f in KITFILES}
        samec = all(runs[0][f] == committed[f] for f in committed)
        (ok if samec else fail)(
            f"{slug}: fresh runs == committed bytes (manifest included)")

# ------------------------------------------------- [8] no drawn value moves
print("[8] 'no drawn value moves' (v1 against v2)")
for slug, want in [("ring-utilisation", ring_readouts),
                   ("twist-limit", twist_drawn)]:
    rc, v1, err = git("show", f"{PIN}^:docs/reporting/figures/{slug}/"
                      "label-ledger.txt")
    if rc != 0:
        fail(f"{slug}: v1 ledger not readable ({err[:40]})")
        continue
    v1set = set(v1.splitlines())
    missing = {w for w in want if w not in v1set}
    (ok if not missing else fail)(
        f"{slug}: drawn sets identical v1 == v2 "
        f"({len(want)} forms, {len(missing)} moved)")

# ------------------------------------------------------- [9] the appendix
print("[9] the draft figure-provenance appendix")
draft = read_text(DRAFT)
appendix_region = draft.split("## Appendix: Figure provenance", 1)[1]
rows_in_appendix = re.findall(
    r"\n\| (Ring utilisation plate|Twist limit plate|Machine evolution strip"
    r"|System anatomy plate) ", appendix_region)
(ok if len(rows_in_appendix) == 4 else fail)(
    f"appendix carries 4 exhibit rows ({len(rows_in_appendix)} found)")

# block-scoped sections, one per exhibit
sections = {}
heads = list(re.finditer(
    r"^(Ring utilisation plate|Twist limit plate|Machine evolution strip"
    r"|System anatomy plate):$", appendix_region, flags=re.M))
for i, m in enumerate(heads):
    start = m.end()
    end = heads[i + 1].start() if i + 1 < len(heads) else len(appendix_region)
    sections[m.group(1)] = appendix_region[start:end]

man_out = {slug: manifests[slug]["outputs"] for slug in KITS}
fix_lines = []
hash_fix = [
    ("Ring utilisation plate", KITS["ring-utilisation"],
     [("png", "ring-utilisation.png"), ("svg", "ring-utilisation.svg"),
      ("pdf", "ring-utilisation.pdf"), ("ledger", "label-ledger.txt")]),
    ("Twist limit plate", KITS["twist-limit"],
     [("png", "twist-limit.png"), ("svg", "twist-limit.svg"),
      ("pdf", "twist-limit.pdf"), ("ledger", "label-ledger.txt")]),
]
for exhibit, d, items in hash_fix:
    slug = d.name
    body = sections.get(exhibit, "")
    for label, fn in items:
        new = sha256(d / fn)
        m = re.search(rf"^- `{label}` `([0-9a-f]{{64}})`$", body, flags=re.M)
        if m is None:
            fail(f"{slug}: appendix {label} line not found")
            continue
        old = m.group(1)
        if old == new:
            ok(f"{slug}: appendix {label} hash already current")
            continue
        if new in draft:
            fail(f"{slug}: appendix {label} new token already present")
            continue
        fixed = m.group(0).replace(old, new)
        fix_lines.append((m.group(0), fixed))
        defect(f"{slug}: appendix {label} hash stale")
for exhibit in ("Ring utilisation plate", "Twist limit plate"):
    m = re.search(rf"^\| {exhibit} \|.*\|$", draft, flags=re.M)
    if m is None:
        fail(f"{exhibit}: exhibit row not found")
        continue
    line = m.group(0)
    if f"`{H0}`" not in line:
        fail(f"{exhibit}: expected old script commit {H0} in row")
        continue
    if f"`{H1}`" in line:
        fail(f"{exhibit}: new script commit already present")
        continue
    fixed = line.replace(f"`{H0}`", f"`{H1}`")
    fix_lines.append((line, fixed))
    defect(f"{exhibit}: exhibit row script commit stale (eacf073 -> 671ab96)")

print("      computed fix lines (verbatim):")
for old, fixed in fix_lines:
    print(f"        - {old}")
    print(f"        + {fixed}")

print("      the review copy (draft-live.docx)")
if DOCX.exists():
    dz = zipfile.ZipFile(DOCX)
    dxml = dz.read("word/document.xml").decode("utf-8")
    dtext = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", dxml))
    for oldtok, name in [
            ("6f19832088375b96cdc566af", "ring png v1"),
            ("ec0f4b96f3fa9b646183e1f7", "ring svg v1"),
            ("7ff5c05cc0caa0890400fec5", "twist png v1"),
            ("ffac9c1eba5386fe79d3c1f5", "twist svg v1")]:
        (ok if oldtok in dtext else fail)(f"docx prints {name} hash")
    for newtok, name in [("f49aaaa1bda8d1699c6db556", "ring png v2"),
                         ("45104b967009ef52c54f2ca4", "twist svg v2")]:
        (ok if newtok not in dtext else fail)(
            f"docx does not print {name} hash (stale block stands)")
    media = {}
    for n in dz.namelist():
        if "media/" in n and n.endswith(".png"):
            media[hashlib.sha256(dz.read(n)).hexdigest()[:24]] = n
    for tok, name in [("f49aaaa1bda8d1699c6db556", "ring png"),
                      ("00cd857a5769be853142a4e3", "twist png"),
                      ("8e9d1d40684b984059601f31", "strip png"),
                      ("f1c322bc20068299651bea79", "anatomy png")]:
        (ok if tok in media else fail)(
            f"docx embeds delivered {name} bytes")
    print(f"      docx md5 {hashlib.md5(DOCX.read_bytes()).hexdigest()}")
else:
    fail("review copy missing")

# strip and anatomy rows verify current
for slug, exhibit, d, pairs in [
        ("machine-evolution-strip", "Machine evolution strip",
         FIGS / "machine-evolution-strip",
         [("png", "machine-evolution-strip.png"),
          ("svg", "machine-evolution-strip.svg"),
          ("pdf", "machine-evolution-strip.pdf"),
          ("checks", "checks.log")]),
        ("system-anatomy", "System anatomy plate",
         FIGS / "system-anatomy",
         [("png", "system-anatomy.png"),
          ("pdf", "system-anatomy.pdf"),
          ("ledger", "label-ledger.txt"),
          ("checks", "checks.log")])]:
    body = sections.get(exhibit, "")
    for label, fn in pairs:
        m = re.search(rf"^- `{label}` `([0-9a-f]{{64}})`$", body, flags=re.M)
        if m and m.group(1) == sha256(d / fn):
            ok(f"{slug}: appendix {label} row current")
        else:
            fail(f"{slug}: appendix {label} row")

# the levers query
pca_in_appendix = "pca" in appendix_region.lower()
(ok if not pca_in_appendix else fail)(
    "appendix carries no levers row (the copy embeds both levers plates)")
if not pca_in_appendix:
    query("rows 20 and 21 have no figure-provenance row; the copy embeds "
          "six plates against four rows")

print(f"\nchecks: {OK + DEFECT + QUERY + FAIL}  ok: {OK}  "
      f"defect: {DEFECT}  query: {QUERY}  fail: {FAIL}")
sys.exit(1 if FAIL else 0)
