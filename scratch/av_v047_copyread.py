#!/usr/bin/env python3
"""The v0.47 copy counter-read and the round-6 leg folds (aero-validator, 2026-10-15).

Routed to this desk: the rebuilt review copy (md5 1115a201, record d0ed902)
keyed here by @author and @science-validator; the science-writer leg folds
(tracker, candidates, stale-phrases) routed here by @science-writer.

  [0] identity and freshness: copy md5, the archived build, the build
      record, the register ref, the embed set frozen, post-build moves;
  [1] the copy input census (v0.45 read state 34e3f81 -> d0ed902): movers,
      token deltas per commit, the net delta;
  [2] the round-6 fold surfaces in the built copy;
  [3] the appendix pins, the stamps and the seven embeds;
  [4] the register appendix and the retired-word holds;
  [5] the science-writer leg folds: diff sets, end states, STE, the no-verify note;
  [6] state anchors.

Reads committed bytes (git objects) and the delivered copy only.
Runs no simulator. Nothing rewrites a committed file.
"""
import hashlib
import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
DRAFT_REL = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER_REL = "docs/reporting/draft-tracker.md"
CAND_REL = "docs/reporting/glossary-candidates.md"
SP_REL = "docs/agents/stale-phrases.md"
REG_REL = "docs/reporting/numbers-register.md"
MAP_REL = "docs/reporting/figures/figure-map.md"
DOCX = ROOT / "scratch/report-pdf-build/draft-live.docx"
ARCHIVE = ROOT / "scratch/report-pdf-build/draft-d0ed902-20261015-124752.docx"
PREV_ARCHIVE = ROOT / "scratch/report-pdf-build/draft-34e3f81-20261014-204106.docx"
BUILD_RECORD = ROOT / "scratch/report-pdf-build/build-record-docx.txt"
TMP = ROOT / "scratch/av_r6_tmp"
FIG_REL = "docs/reporting/figures"
D_PREV_READ = "34e3f81"   # the last copy read state (v0.45 walk)
D_45ED = "45ed95a"        # the v0.46 re-pin (figures landing)
D_RECORD = "d0ed902"      # the v0.47 fold = the copy's record draft
REG_REF = "cb862df"       # register ref named in the build record
SW_A = "69ec727"          # the leg content commit (tracker + candidates)
SW_B = "50e0300"          # the stale-phrases commit
SW_RANGE = ("2a0d096", "e6122a2")
COPY_MD5 = "1115a2019872ad10929941d4baeb67a6"
V9_UNCITED = ["NR-024", "NR-031", "NR-033", "NR-034", "NR-035", "NR-037", "NR-038", "NR-041", "NR-051"]

TOK = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")

EXHIBITS = [
    ("Ring utilisation plate", "ring-utilisation", ["ledger", "pdf", "png", "svg"]),
    ("Twist limit plate", "twist-limit", ["ledger", "pdf", "png", "svg"]),
    ("Machine evolution strip", "machine-evolution-strip", ["checks", "pdf", "png", "svg"]),
    ("System anatomy plate", "system-anatomy", ["checks", "ledger", "pdf", "png"]),
    ("Levers landscape", "pca-landscape", ["ledger", "pdf", "png", "svg"]),
    ("Parameter atlas", "pca-atlas", ["ledger", "pdf", "png", "svg"]),
    ("Machine winner hero", "machine-winner-hero", ["checks", "pdf", "png", "svg"]),
]
EXHIBIT_FILES = {
    "ring-utilisation": ["ring-utilisation.png", "ring-utilisation.svg",
                         "ring-utilisation.pdf", "label-ledger.txt"],
    "twist-limit": ["twist-limit.png", "twist-limit.svg",
                    "twist-limit.pdf", "label-ledger.txt"],
    "machine-evolution-strip": ["machine-evolution-strip.png", "machine-evolution-strip.svg",
                                "machine-evolution-strip.pdf", "checks.log"],
    "system-anatomy": ["system-anatomy.png", "system-anatomy.pdf",
                       "label-ledger.txt", "checks.log"],
    "pca-landscape": ["pca-landscape.png", "pca-landscape.svg",
                      "pca-landscape.pdf", "label-ledger.txt"],
    "pca-atlas": ["pca-atlas.png", "pca-atlas.svg",
                  "pca-atlas.pdf", "label-ledger.txt"],
    "machine-winner-hero": ["machine-winner-hero.png", "machine-winner-hero.svg",
                            "machine-winner-hero.pdf", "checks.log"],
}
KIT_PNGS = [f"{s}/{s}.png" for s in EXHIBIT_FILES]
FRAMES = [
    "system-anatomy Figure (roster row 2) · system-anatomy",
    "machine-winner-hero Figure (roster row 10) · machine-winner-hero",
    "ring-utilisation Figure (roster row 6) · ring-utilisation",
    "twist-limit Figure (roster row 7) · twist-limit",
    "pca-landscape Figure (roster row 20) · pca-landscape",
    "pca-atlas Figure (roster row 21) · pca-atlas",
    "machine-evolution-strip Figure (roster row 9) · machine-evolution-strip",
]

TRK_ADD = [
    "The section 3.3 winner paragraph gains one line: NR-009 is the window minimum, and the capture topmost ring reads 15.033 at the final step (NR-021).",
    "NR-009 keeps the row value, and the capture topmost ring reading keeps its form.",
]
TRK_REM = [
    "The section 3.3 winner paragraph gains one line: NR-009 is the window minimum, and the capture hub ring reads 15.033 at the final step (NR-021).",
    "NR-009 keeps the row value, and the capture hub ring reading keeps its form.",
]
CAND_ADD = [
    "**Status** PREP v16, numbers-free by construction (no measurement values, no",
    '| topmost ring | The ring at the top of the TRPT. It carries the main rotor. The full name is "topmost rotor ring". The name "hub ring" retires (Rod, 2026-10-14). | physics-topology 4, CONTEXT.md | ratify |',
    '| main rotor | The topmost rotor. Everything below it is the transmission for its torque. Never write "hub rotor" or "hub ring". | physics-topology 4, CONTEXT.md | ratify |',
    '| "hub rotor", or "hub" for a rotor or the ring | main rotor, topmost ring | stale-phrases, physics-topology 4 |',
    "",
    "- **v16 (2026-10-15):** the hub-name retirement re-keys the ring pair.",
    "  The topmost ring row joins the machine group beside the ground ring.",
    "  The main-rotor guard and the retire list take the ring name.",
    "  The rename lands with the round-6 fold, so the term gate reads one form.",
    "  No other change.",
]
CAND_REM = [
    "**Status** PREP v15, numbers-free by construction (no measurement values, no",
    '| main rotor | The topmost rotor. Everything below it is the transmission for its torque. Never write "hub rotor". | physics-topology 4, CONTEXT.md | ratify |',
    '| "hub rotor", or "hub" for a rotor | main rotor, topmost rotor | stale-phrases, physics-topology 4 |',
]
SP_ADD = [
    "## The topmost ring hosts ONLY the cp/ct rotor",
    "## expansion_params_from_rotors excludes the decoder's topmost rotor",
    'Replacement: main rotor (the topmost rotor). "Hub" is not a rotor term, and it does not name the ring \u2014 see docs/agents/physics-topology.md \u00a74',
    'Note (2026-10-14): the part reads "topmost ring", or "topmost rotor ring" in full (Rod, 2026-10-14).',
]
SP_REM = [
    "## The hub ring hosts ONLY the cp/ct rotor",
    "## expansion_params_from_rotors excludes the decoder's hub rotor",
    'Replacement: main rotor (the topmost rotor). "Hub" is not a rotor term \u2014 see docs/agents/physics-topology.md \u00a74',
]

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


def note(msg):
    print(f"  note {msg}")


def git_bytes(*args):
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True).stdout


def git_txt(*args):
    return git_bytes(*args).decode("utf-8")


def gitc(*args):
    return git_txt(*args).strip()


def sha256_bytes(b):
    return hashlib.sha256(b).hexdigest()


def md5_bytes(b):
    return hashlib.md5(b).hexdigest()


def nrm(t):
    t = t.replace("`", "")
    t = re.sub(r"\s+", " ", t)
    return re.sub(r"\s+([.,:;])", r"\1", t)


def diff_lines(a, b, rel):
    out = git_txt("diff", "--unified=0", f"{a}..{b}", "--", rel)
    add = [l[1:] for l in out.splitlines() if l.startswith("+") and not l.startswith("+++")]
    rem = [l[1:] for l in out.splitlines() if l.startswith("-") and not l.startswith("---")]
    return add, rem


def manifest_stamp(manifest):
    bits = []
    cap = manifest.get("capture", {})
    if cap.get("run_id"):
        bits.append(cap["run_id"])
    data = manifest.get("data_commit")
    if data:
        bits.append(f"data {data}")
    else:
        sha = (manifest.get("inputs", {}).get("extract", {}) or {}).get("sha256", "")
        if sha:
            bits.append(f"data {sha[:7]}")
    script = manifest.get("script_commit")
    if not script:
        sha = manifest.get("script", {}).get("sha256", "")
        script = sha[:7] if sha else None
    if script:
        bits.append(f"script {script}")
    rows = manifest.get("registers") or manifest.get("inputs", {}).get("register_rows", [])
    if rows:
        bits.append("rows " + ", ".join(rows))
    return " \u00b7 ".join(bits)


def lint(paths):
    r = subprocess.run(["python3", "ste-lint.py", "--fail-above", "2.0", *[str(p) for p in paths]],
                       capture_output=True, cwd=ROOT)
    return r.returncode, r.stdout.decode("utf-8")


TMP.mkdir(parents=True, exist_ok=True)

z = zipfile_ok = None
import zipfile
z = zipfile.ZipFile(DOCX)
xml = z.read("word/document.xml").decode("utf-8")
dtext = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", xml))
dn = nrm(dtext)
rec = BUILD_RECORD.read_text(encoding="utf-8")
draft = git_txt("show", f"HEAD:{DRAFT_REL}")
draft_rec = git_txt("show", f"{D_RECORD}:{DRAFT_REL}")
reg_head = git_txt("show", f"HEAD:{REG_REL}")
reg_md = re.sub(r"\s+", " ", reg_head)
tip = gitc("rev-parse", "--short", "HEAD")
up = gitc("rev-parse", "--short", "origin/bank-derate-cos2p65")
md5 = md5_bytes(DOCX.read_bytes())
print(f"[0] v0.47 copy counter-read   tip {tip}   origin {up}   record {D_RECORD}   copy md5 {md5}")

print("[0] identity and freshness")
(ok if md5 == COPY_MD5 else bad)("copy md5 reads the declared value")
(ok if md5 == md5_bytes(ARCHIVE.read_bytes()) else bad)("copy byte-identical to its archived build")
(ok if DOCX.stat().st_size == ARCHIVE.stat().st_size else bad)("copy and archive carry one size")
for s, name in [("Draft: `d0ed902`", "build record names draft d0ed902"),
                ("file at `cb862df`", "build record refs register cb862df"),
                ("42 cited, every one signed (51 signed rows total)", "build record: 42 cited of 51 signed"),
                ("uncited: NR-024, NR-031, NR-033, NR-034, NR-035, NR-037, NR-038, NR-041, NR-051",
                 "build record uncited list reads the 9 ids"),
                ("checker exit 0", "build record: checker exit 0"),
                ("Seats resolved: 7 of 7", "build record: seven seats"),
                ("Built: 2026-10-15T12:47:52Z", "docx build stamp 12:47:52Z"),
                ("Embed route: SVG vector-first, PNG fallback", "build record embed route")]:
    (ok if s in rec else bad)(name)
a = gitc("rev-parse", f"{D_RECORD}:{DRAFT_REL}")
b = gitc("rev-parse", f"HEAD:{DRAFT_REL}")
c = gitc("rev-parse", f"origin/bank-derate-cos2p65:{DRAFT_REL}")
(ok if a and a == b == c else bad)("draft blob reads d0ed902 == HEAD == origin")
(ok if gitc("log", "--format=%h", f"{D_RECORD}..HEAD", "--", "docs/reporting/drafts") == ""
 else bad)("no draft move since the record")
a = gitc("rev-parse", f"{REG_REF}:{REG_REL}")
b = gitc("rev-parse", f"HEAD:{REG_REL}")
c = gitc("rev-parse", f"origin/bank-derate-cos2p65:{REG_REL}")
(ok if a and a == b == c else bad)("register ref cb862df == HEAD == origin")
(ok if gitc("log", "--format=%h", f"{REG_REF}..HEAD", "--", REG_REL) == ""
 else bad)("register unchanged since cb862df")
embed28 = [f"{FIG_REL}/{slug}/{fn}" for _, slug, _ in EXHIBITS for fn in EXHIBIT_FILES[slug]]
st = gitc("diff", "--stat", D_RECORD, "HEAD", "--", *embed28)
(ok if st == "" else bad)(f"the 28 embedded bytes hold since d0ed902 ({st.splitlines()[-1] if st else ''})")
moved = gitc("diff", "--name-only", D_RECORD, "HEAD").splitlines()
(ok if "docs/reporting/draft-tracker.md" in moved else bad)("tracker among post-build moves (the legs)")
(ok if "docs/reporting/numbers-register.md" not in moved else bad)("register not among post-build moves")
print(f"  post-build moves since {D_RECORD}: {len(moved)} paths")
for m in moved:
    print(f"    {m}")
(ok if tip == up else bad)("the read tip reads the same as origin")

print("[1] the copy input census (v0.45 read state -> record)")
mv_d = gitc("log", "--format=%h", f"{D_PREV_READ}..HEAD", "--", "docs/reporting/drafts").split()
(ok if sorted(mv_d) == sorted([D_45ED, D_RECORD]) else bad)(f"draft movers read [45ed95a, d0ed902] ({mv_d})")
mv_t = gitc("log", "--format=%h", f"{D_PREV_READ}..HEAD", "--", TRACKER_REL).split()
(ok if sorted(mv_t) == sorted([D_45ED, D_RECORD, SW_A]) else bad)(f"tracker movers read the three ({mv_t})")
for tag, a, b, exp_add, exp_rem in [
        ("v0.46 re-pin", D_PREV_READ, D_45ED, {"46": 1}, {"45": 1}),
        ("v0.47 fold", D_45ED, D_RECORD, {"47": 1, "508": 1}, {"46": 1})]:
    base = git_txt("show", f"{a}:{DRAFT_REL}")
    cand = git_txt("show", f"{b}:{DRAFT_REL}")
    ta, tb = Counter(TOK.findall(base)), Counter(TOK.findall(cand))
    add = dict(tb - ta)
    rem = dict(ta - tb)
    (ok if add == exp_add and rem == exp_rem else bad)(
        f"{tag}: token delta reads add {dict(sorted(add.items()))} / rem {dict(sorted(rem.items()))}")
base = git_txt("show", f"{D_PREV_READ}:{DRAFT_REL}")
ta, tb = Counter(TOK.findall(base)), Counter(TOK.findall(draft_rec))
add = dict(tb - ta)
rem = dict(ta - tb)
(ok if add == {"47": 1, "508": 1} and rem == {"45": 1} else bad)(
    f"net copy-input delta reads add {dict(sorted(add.items()))} / rem {dict(sorted(rem.items()))}")
(ok if draft == draft_rec else bad)("the draft at the record reads the draft at the tip")

print("[2] the round-6 fold surfaces in the built copy")
(ok if dtext.count("Draft v0.47") == 1 else bad)("copy head line reads Draft v0.47 once")
for s in ("v0.37", "v0.38", "v0.39", "v0.40", "v0.41", "v0.42", "v0.43", "v0.44", "v0.45", "v0.46"):
    (ok if dtext.count(s) == 0 else bad)(f"copy reads zero '{s}' marks")
for s, n, name in [("topmost ring", 9, "topmost ring"), ("topmost rotor ring", 2, "topmost rotor ring"),
                   ("Topmost ring radius", 1, "the table-row form (capital)"),
                   ("topmost ring radius", 3, "topmost ring radius"), ("topmost-ring", 1, "topmost-ring (hyphen)")]:
    c2 = dtext.count(s)
    (ok if c2 == n else bad)(f"copy count {name} reads {n} ({c2})")
c2 = len(re.findall(r"(?i)topmost", dtext))
(ok if c2 == 13 else bad)(f"copy count (?i)topmost reads 13 ({c2})")
(ok if dtext.count("The search found 508 feasible candidates in the searched space (NR-002).") == 1
 else bad)("copy reads the count sentence once")
(ok if dtext.count("The best performing one had a mean power of 5.309 kW.") == 1 else bad)(
    "copy reads the founder winner sentence once")
(ok if dtext.count("Its airborne mass is 25.698 kilograms (NR-008, NR-018).") == 1 else bad)(
    "copy reads the founder mass sentence once")
(ok if dtext.count("mean power of 5.309") == 1 else bad)("copy reads 'mean power of 5.309' once")
kg = dtext.count("25.698 kilograms")
(ok if kg == 4 else bad)(f"copy reads '25.698 kilograms' four times ({kg})")
(ok if dtext.count("The levers of Performance") == 1 else bad)("copy reads The levers of Performance once")
for m in re.finditer(r"25\.698 kilograms", dtext):
    print(f"    kg-ctx: {dtext[max(0, m.start()-70):m.end()+30].strip()[:150]}")
copy_bits = [
    ("2.1 radii", "topmost-ring and ground radii"),
    ("2.2.2 load", "The top-segment helix force reads about 1278 N/vertex (NR-048)."),
    ("3.3 capture", "The capture topmost ring reads 15.033 at the final step (NR-021)."),
    ("3.3 radius prose", "topmost ring radius is 4.580 metres and the ground radius 0.804 metres"),
    ("3.4 line", "The topmost rotor ring R6 governs the structural check at the winner operating point (NR-021)."),
    ("3.5 radius", "The topmost ring radius is 4.580 m and the ground radius is 0.804 m."),
    ("4.2 table", "landed on the topmost ring"),
    ("4.2 narrative", "the topmost ring (2026-08-26)"),
    ("4.2 tail", "one ring toward the top"),
    ("pointer line one", "The three movers carry their records. The bank derate is a calculated depowering of the main-rotor disc (NR-019, NR-020)."),
    ("pointer line two", "The window basis sits at section 2.2.2, and the gate set at section 2.4."),
    ("era row 1", "Before the bank derate Earlier winners read different bank-angle physics, so they are not directly comparable. Superseded as era record."),
    ("era row 2", "The bank-derate basis The measured bank derate applies to main-rotor disc power throughout (NR-019, NR-020). Current campaign basis."),
    ("era row 3a", "The pre-fold rows failed the floor (NR-027)."),
    ("era row 3b", "the folded class passes at 18.8 metres (NR-028)."),
    ("ledger lead", "Candidate entries. Each failure enters with its lesson."),
    ("ledger entry 1", "2026-08-14 inverted-taper divergence Geometry/decoder failure"),
    ("ledger entry 2", "2026-08-26 rotor-to-ring off-by-one"),
    ("ledger entry 3", "2026-08-22 blade-mass-law correction Model correction"),
    ("ledger entry 4", "2026-08-13 k-alignment fault Gain misalignment"),
    ("ledger entry 5", "2026-08-24 stale-gain re-gate Stale configuration"),
    ("ledger entry 6", "2026-08-22 FoS=Inf guard gap Gate near-miss"),
    ("ledger close 3", "Data voided, record kept."),
    ("ledger close 5", "The re-gate at the campaign gain returned 5.18 kilowatts."),
    ("ledger close 6", "Near-miss, no corrupted survivor found."),
    ("spelled form", "ran 5-kilowatt designs at the 50-kilowatt default gain"),
    ("round-5 base clause", "The base span reads 0.75 of the rotor radius, and the base chord reads 0.113 of it."),
    ("round-5 cone", "The shaft transition cone holds one fixed angle, 22 degrees, by construction."),
    ("round-5 cold path", "The campaign scored every design on the cold path (NR-012)."),
    ("round-5 slot", "The main-rotor slot, blade_scale_top, reads 0.82 and decodes to the single active rotor."),
    ("gate row power", "pass, P_end 5.314 kW. Margin +0.314 kW / +6.28 per cent"),
    ("gate row FoS", "pass, 15.0 minimum. 15.0 on 2.5, margin +12.5 / +500.0 per cent, 6.00 times"),
    ("gate row rope", "the warm path rejects healthy winners"),
]
for name, s in copy_bits:
    (ok if nrm(s) in dn else bad)(f"copy reads: {name}")
for name, s, n in [("22 degrees sites", "22 degrees", 3), ("shaft transition cone", "shaft transition cone", 3),
                   ("0.75", "0.75", 2), ("Tulloch", "Tulloch", 1), ("Jensen", "Jensen", 0),
                   ("lower-number key", "A lower number is better", 0)]:
    c2 = dtext.count(s)
    (ok if c2 == n else bad)(f"copy count {name} reads {n} ({c2})")

print("[3] the appendix pins, the stamps and the seven embeds")
region_draft = draft.split("## Appendix: Figure provenance", 1)[1]
n_vals = 0
pins = []
for exhibit, slug, labels in EXHIBITS:
    for label in labels:
        heads = list(re.finditer(r"^(Ring utilisation plate|Twist limit plate|Machine evolution strip"
                                 r"|System anatomy plate|Levers landscape|Parameter atlas"
                                 r"|Machine winner hero):$", region_draft, flags=re.M))
        body = ""
        for k, mm in enumerate(heads):
            if mm.group(1) == exhibit:
                start = mm.end()
                end = heads[k + 1].start() if k + 1 < len(heads) else len(region_draft)
                body = region_draft[start:end]
        m = re.search(rf"^- `{re.escape(label)}` `([0-9a-f]{{64}})`$", body, flags=re.M)
        if m is None:
            bad(f"{slug}: {label} line missing")
            continue
        n_vals += 1
        pin = m.group(1)
        fn = [f for f in EXHIBIT_FILES[slug]
              if f.endswith("." + label)
              or (label == "ledger" and f.endswith("label-ledger.txt"))
              or (label == "checks" and f.endswith("checks.log"))][0]
        got = sha256_bytes(git_bytes("show", f"HEAD:{FIG_REL}/{slug}/{fn}"))
        hb = gitc("rev-parse", f"HEAD:{FIG_REL}/{slug}/{fn}")
        ob = gitc("rev-parse", f"origin/bank-derate-cos2p65:{FIG_REL}/{slug}/{fn}")
        if got == pin and hb == ob and hb != "":
            ok(f"{slug}: {label} pinned == committed == HEAD == origin")
            pins.append((fn, pin))
        else:
            bad(f"{slug}: {label} pin {pin[:12]} committed {got[:12]}")
(ok if n_vals == 28 else bad)(f"28 pinned values walked ({n_vals})")
for fn, pin in pins:
    (ok if pin in dtext else bad)(f"copy prints the {fn} pin")
app = draft.split("## Appendix: Figure provenance", 1)[1]
(ok if app.count("`1af63fc`") == 4 else bad)(f"four appendix script cells read 1af63fc ({app.count('`1af63fc`')})")
exp_tok = Counter()
for exhibit, slug, labels in EXHIBITS:
    man = json.loads((ROOT / FIG_REL / slug / "manifest.json").read_text())
    st = manifest_stamp(man)
    rowm = re.search(rf"\| {re.escape(exhibit)} .*?`([0-9a-f]{{7,40}})` \|", app)
    if rowm:
        exp_tok[rowm.group(1)] += 1
    sm = re.search(r"script ([0-9a-f]{7})", st)
    if sm:
        exp_tok[sm.group(1)] += 1
for tok, n in sorted(exp_tok.items()):
    c2 = dtext.count(tok)
    (ok if c2 == n else bad)(f"copy token census {tok}: {c2} == expected {n}")
(ok if dtext.count("d243b37") == 0 else bad)("copy reads zero d243b37 marks")
(ok if dtext.count("9cecee3") == 0 else bad)("copy reads zero 9cecee3 marks")
stamps_ok = 0
for exhibit, slug, labels in EXHIBITS:
    manifest = json.loads((ROOT / FIG_REL / slug / "manifest.json").read_text())
    stn = nrm("Source: " + manifest_stamp(manifest))
    valid = 0
    for m in re.finditer(re.escape(stn), dn):
        if dn[m.end():m.end() + 1] != ",":
            valid += 1
    if valid == 1:
        stamps_ok += 1
        ok(f"copy stamp == manifest stamp ({slug})")
    else:
        bad(f"copy stamp missing or duplicated ({slug}): {stn[:80]} valid {valid}")
(ok if dtext.count("Source: ") == 7 else bad)(f"seven stamps read ({dtext.count('Source: ')})")
if PREV_ARCHIVE.exists():
    oz = zipfile.ZipFile(PREV_ARCHIVE)
    oxt = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", oz.read("word/document.xml").decode("utf-8")))
    (ok if "data dd5a9dd \u00b7 script 224e916" in oxt and "data dd5a9dd \u00b7 script 75d82de" in oxt
     else bad)("the held v0.45 copy carries the old sha-fallback forms")
    ru7 = json.loads((ROOT / FIG_REL / "ring-utilisation/manifest.json").read_text())["script"]["sha256"][:7]
    tl7 = json.loads((ROOT / FIG_REL / "twist-limit/manifest.json").read_text())["script"]["sha256"][:7]
    (ok if f"data dd5a9dd \u00b7 script {ru7}" in dtext and f"data dd5a9dd \u00b7 script {tl7}" in dtext
     else bad)(f"the new copy carries the manifest-derived fallback forms (script {ru7} / {tl7})")
    note("ring/twist stamps print the sha-fallback form (old manifests, no commit keys); the prefix moved "
         "with the re-cut script sha -- pre-existing schema, flagged")
for f in FRAMES:
    (ok if dtext.count(f) == 1 else bad)(f"frame reads once: {f[:56]}")
(ok if dtext.count("Figure (") == 7 else bad)(f"seven figure frames read ({dtext.count('Figure (')})")
(ok if dtext.count("Figure seated") == 0 else bad)("raw markers read zero in the copy")
i33 = dtext.find("3.3 The winner")
i34 = dtext.find("3.4 The levers of Performance")
jf = dtext.find("machine-winner-hero Figure (roster row 10)")
(ok if i33 >= 0 and i33 < jf < i34 else bad)("the hero frame sits inside section 3.3 in the copy")
media = sorted(sha256_bytes(git_bytes("show", f"HEAD:{FIG_REL}/{p}"))[:24] for p in KIT_PNGS)
embedded = sorted(hashlib.sha256(z.read(n)).hexdigest()[:24] for n in z.namelist() if "media/" in n and n.endswith(".png"))
(ok if media == embedded else bad)(f"copy embeds the delivered bytes on all seven exhibits ({len(embedded)})")

print("[4] the register appendix and the retired-word holds")
i_reg = dtext.find("Data register (cited rows)")
i_build = dtext.find("Build record (builder output)")
(ok if 0 < i_reg < i_build else bad)("appendix markers read")
region_ids = sorted(set(re.findall(r"NR-\d{3}", dtext[i_reg:i_build])))
ids_head = sorted({m.group(1) for m in re.finditer(r"^\| (NR-\d{3})", reg_head, flags=re.M)})
(ok if len(ids_head) == 51 else bad)(f"register at HEAD reads 51 ids ({len(ids_head)})")
cited = sorted(set(ids_head) - set(V9_UNCITED))
(ok if len(cited) == 42 else bad)(f"cited set reads 42 ({len(cited)})")
(ok if region_ids == cited else bad)(f"copy register appendix == cited set ({len(region_ids)} ids)")
for u in V9_UNCITED:
    (ok if u not in region_ids else bad)(f"uncited {u} stays out")
(ok if "NR-019" in region_ids and "NR-020" in region_ids else bad)("NR-019 and NR-020 enter the appendix set")
hits97 = [m.start() for m in re.finditer(re.escape("14.97"), dtext)]
(ok if len(hits97) == 1 and all(i_reg <= h < i_build for h in hits97) else bad)(
    f"14.97-class prints once, inside the register appendix ({len(hits97)})")
for name, s, n in [("full-precision 14.971...", "14.971791422208508", 0), ("guarded 3.816", "3.816", 0),
                   ("15.0", "15.0", 14), ("15.033", "15.033", 3), ("14.972", "14.972", 1),
                   ("27.3635412663488", "27.3635412663488", 2), ("27.364", "27.364", 11)]:
    c2 = dtext.count(s)
    (ok if c2 == n else bad)(f"copy display form {name} reads {n} ({c2})")
(ok if not re.findall(r"27\.363(?!\d)", dtext) else bad)("guarded rounded 27.363 reads zero")
(ok if dtext.count("unresolved") == 0 else bad)("no unresolved notice")
(ok if dtext.count("All seven read dataset commit") == 1 else bad)("copy count sentence reads 'All seven' once")
for s, name in [("14.972", "NR-009 row form"), ("27.364 (found gen 26)", "NR-005 value"),
                ("1.4994019682084492 (quote 1.499)", "NR-043 span"), ("2.4341173109692225", "NR-050 r_rotor"),
                ("cone_slope_deg 22.0", "NR-049 cone value"), ("bank_bot 22\u00b0", "NR-011 bank form")]:
    (ok if s in dtext[i_reg:i_build] else bad)(f"register appendix: {name}")
hub_all = [m for m in re.finditer(r"(?i)hub", dtext)]
hub_word = [m for m in re.finditer(r"(?i)\bhub\b", dtext)]
hub_host = [m for m in re.finditer(r"(?i)\bhub\b", dtext) if m.start() < i_reg or m.start() >= i_build]
(ok if len(hub_word) == 5 else bad)(f"the retired word reads 5 as a word ({len(hub_word)})")
(ok if not hub_host else bad)(f"the word reads zero outside the register appendix ({len(hub_host)})")
hub_ids = [m for m in re.finditer(r"(?i)(r_hub|blade_hub_radius)", dtext)]
(ok if len(hub_ids) == 2 else bad)(f"the two identifier holds read ({len(hub_ids)})")
(ok if dtext.count("Hub") == 0 else bad)(f"capitalised Hub reads zero ({dtext.count('Hub')})")
for m in hub_word:
    print(f"    hub-word: ...{dtext[max(0, m.start()-60):m.start()+60]}...")
frag_bad = []
for rid in ("NR-021", "NR-030", "NR-032", "NR-048"):
    for l in reg_head.splitlines():
        if l.startswith(f"| {rid} "):
            for m in re.finditer(r"(?i)\bhub\b", l):
                frag = nrm(l[max(0, m.start() - 35):m.start() + 45].replace("|", " "))
                if frag not in dn:
                    frag_bad.append(f"{rid}: {frag[:60]}")
(ok if not frag_bad else bad)(f"every register hub-quote reads in the copy ({len(frag_bad)} bad)")
(ok if "NR-051" not in region_ids else bad)("NR-051 stays out of the appendix")

print("[5] the science-writer leg folds")
mv = gitc("log", "--format=%h", f"{SW_RANGE[0]}..{SW_RANGE[1]}", "--", TRACKER_REL).split()
(ok if mv == [SW_A] else bad)(f"tracker moves once in the leg train ({mv})")
mv = gitc("log", "--format=%h", f"{SW_RANGE[0]}..{SW_RANGE[1]}", "--", CAND_REL).split()
(ok if mv == [SW_A] else bad)(f"candidates move once in the leg train ({mv})")
mv = gitc("log", "--format=%h", f"{SW_RANGE[0]}..{SW_RANGE[1]}", "--", SP_REL).split()
(ok if mv == [SW_B] else bad)(f"stale-phrases moves once in the leg train ({mv})")
add, rem = diff_lines(f"{SW_A}^", SW_A, TRACKER_REL)
(ok if sorted(add) == sorted(TRK_ADD) else bad)(f"tracker added set reads the two short-form lines ({len(add)})")
(ok if sorted(rem) == sorted(TRK_REM) else bad)(f"tracker removed set reads the two old-form lines ({len(rem)})")
trk_head = git_txt("show", f"HEAD:{TRACKER_REL}")
(ok if trk_head == git_txt("show", f"{SW_A}:{TRACKER_REL}") else bad)("tracker at HEAD reads the leg commit blob")
(ok if not re.search(r"(?i)hub", trk_head) else bad)("tracker reads the retired word zero, raw and as a word")
add, rem = diff_lines(f"{SW_A}^", SW_A, CAND_REL)
if sorted(add) != sorted(CAND_ADD):
    only = [l for l in add if l not in CAND_ADD]
    miss = [l for l in CAND_ADD if l not in add]
    print(f"    cand add-only: {only[:4]}")
    print(f"    cand expected-missing: {miss[:4]}")
(ok if sorted(add) == sorted(CAND_ADD) else bad)(f"candidates added set reads the declared 10 lines ({len(add)})")
(ok if sorted(rem) == sorted(CAND_REM) else bad)(f"candidates removed set reads the declared 3 lines ({len(rem)})")
add, rem = diff_lines(f"{SW_B}^", SW_B, SP_REL)
if sorted(add) != sorted(SP_ADD):
    print(f"    sp add-only: {[l for l in add if l not in SP_ADD][:4]}")
    print(f"    sp expected-missing: {[l for l in SP_ADD if l not in add][:4]}")
(ok if sorted(add) == sorted(SP_ADD) else bad)(f"stale-phrases added set reads the declared 4 lines ({len(add)})")
(ok if sorted(rem) == sorted(SP_REM) else bad)(f"stale-phrases removed set reads the declared 3 lines ({len(rem)})")
cand_head = git_txt("show", f"HEAD:{CAND_REL}")
cand_hub = [l for l in cand_head.splitlines() if re.search(r"(?i)hub", l)]
(ok if len(cand_hub) == 4 else bad)(f"candidates carry the old form on four ban-quote lines ({len(cand_hub)})")
for l in cand_hub:
    print(f"    cand hub-line: {l.strip()[:110]}")
sp_head = git_txt("show", f"HEAD:{SP_REL}")
sp_hub = [l for l in sp_head.splitlines() if re.search(r"(?i)hub", l)]
(ok if len(sp_hub) == 2 else bad)(f"stale-phrases carries the ban entry and its replacement ({len(sp_hub)})")
(ok if "## hub rotor" in sp_head and "Note (2026-10-14)" in sp_head else bad)("the ban entry and the dated note read")
for name, blob, exp in [
        ("stale-phrases before", git_txt("show", f"{SW_B}^:{SP_REL}"), (588, 20)),
        ("stale-phrases after", sp_head, (610, 20)),
        ("tracker at the leg", trk_head, (2927, 11)),
        ("candidates at the leg", cand_head, (4687, 12))]:
    p = TMP / (name.replace(" ", "_") + ".md")
    p.write_text(blob, encoding="utf-8")
    rc, out = lint([p])
    m = re.search(r"words=\s*(\d+) total=\s*(\d+) per100w=\s*([\d.]+)", out)
    got = (int(m.group(1)), int(m.group(2))) if m else None
    (ok if got == exp else bad)(f"STE {name}: words/total {exp} ({got}, {m.group(3) if m else '?'})")
rc, out = lint([SP_REL])
m = re.search(r"words=\s*(\d+) total=\s*(\d+) per100w=\s*([\d.]+)", out)
(ok if m and (int(m.group(1)), int(m.group(2))) == (610, 20) else bad)(
    f"stale-phrases at HEAD recounts 610 / 20 ({m.groups() if m else None})")
(ok if rc != 0 else bad)("stale-phrases at HEAD still reads over the gate (the disclosed legacy class)")
exempt = (ROOT / ".ste-exempt").read_text() if (ROOT / ".ste-exempt").exists() else ""
(ok if "stale-phrases" not in exempt else bad)("stale-phrases is not in .ste-exempt (the bypass is disclosed, not an exemption)")
msg = gitc("show", "-s", "--format=%B", SW_B)
(ok if "--no-verify" in msg and "legacy" in msg else bad)("the stale-phrases commit message discloses the --no-verify and the legacy class")

print("[6] state anchors")
for rel, needle, name in [
        ("docs/reporting/room-responses/author-2026-10-15-v047-round6-fold-and-rebuild.md",
         "1115a2019872ad10929941d4baeb67a6", "author receipt names the copy md5"),
        ("docs/reporting/room-responses/science-validator-2026-10-15-round6-term-gate-reread.md",
         "1115a201", "science-validator receipt names the copy"),
        ("docs/reporting/room-responses/science-writer-2026-10-15-round6-legs.md",
         "the capture topmost ring", "science-writer receipt names the tracker site"),
        ("docs/reporting/room-responses/figures-images-diagrams-2026-10-15-round6-counterread-foldback-and-corner-open.md",
         "3038656", "figures receipt names the counter-read close")]:
    body = (ROOT / rel).read_text()
    (ok if needle in body else bad)(name)
(ok if "v0.47 pass by @author (2026-10-14)." in trk_head else bad)("tracker carries the v0.47 entry")
(ok if "v0.46 pass by @fig-img-diagrams" in trk_head else bad)("tracker carries the v0.46 entry")
for s in ("60.646", "58.864", "33.704", "33.812"):
    (ok if s in reg_head else bad)(f"NR-051 carries pick value {s}")
mp = gitc("show", f"HEAD:{MAP_REL}")
(ok if "v37" in mp and "v38" in mp else bad)("map carries deltas v37 and v38")
(ok if "3038656" in mp else bad)("map rows read the counter-read close")
cg = ROOT / FIG_REL / "machine-corner-grid/extract-corner-grid.csv"
(ok if cg.exists() and sha256_bytes(cg.read_bytes()) ==
    "03abd0c660e0ad22db89f767a7b033c18db82f67dde69593c31cbb3a3919a4d5"
 else bad)("the corner extract reads its declared sha256 (the F-CITE read queues on the generator)")
(ok if tip == up else bad)("final: tip == origin")

print(f"\nchecks: {OK + FAIL}  ok: {OK}  fail: {FAIL}")
print("AV_V047_DONE" if FAIL == 0 else "AV_V047_FAIL")
sys.exit(1 if FAIL else 0)
