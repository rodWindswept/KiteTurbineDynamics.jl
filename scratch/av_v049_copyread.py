#!/usr/bin/env python3
"""The v0.49 copy counter-read (aero-validator, 2026-10-15).

Routed to this desk by @author (record 8169e36, live md5 24f98df6) and
@science-validator (the copy re-read rides the term gate).

  [0] identity and freshness: copy md5, the archive, the build record, the
      register ref, the embed set frozen, the post-build moves;
  [1] the copy input census (d0ed902 -> 8169e36): movers, token deltas;
  [2] the fold surfaces in the built copy (the relabel, the re-keys);
  [3] the appendix pins, the stamps, the seven embeds, the token census;
  [4] the register appendix and the retired-word holds;
  [5] the delta from the copy the founder last held, and the state anchors.

Reads committed bytes and the delivered copies only. Runs no simulator.
"""
import hashlib
import json
import re
import subprocess
import sys
import zipfile
from collections import Counter
from pathlib import Path

ROOT = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
DRAFT_REL = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER_REL = "docs/reporting/draft-tracker.md"
REG_REL = "docs/reporting/numbers-register.md"
DOCX = ROOT / "scratch/report-pdf-build/draft-live.docx"
ARCHIVE = ROOT / "scratch/report-pdf-build/draft-8169e36-20261015-144342.docx"
OLD_ARCHIVE = ROOT / "scratch/report-pdf-build/draft-d0ed902-20261015-124752.docx"
BUILD_RECORD = ROOT / "scratch/report-pdf-build/build-record-docx.txt"
FIG_REL = "docs/reporting/figures"
D_PREV = "d0ed902"     # the last copy read state (v0.47)
F48 = "6f19eee"        # the v0.48 pin (the SA cells)
D_RECORD = "8169e36"   # the v0.49 fold = the copy's record draft
REG_REF = "cb862df"    # register ref named in the build record
COPY_MD5 = "24f98df65d7274233bfea9cc9e736937"
V9_UNCITED = ["NR-024", "NR-031", "NR-033", "NR-034", "NR-035", "NR-037", "NR-038", "NR-041", "NR-051"]
CAPTION = "Three lifting bridles run from the bearing into the main rotor."

TOK = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")

EXHIBITS = [
    ("Ring utilisation plate", "ring-utilisation", ["ledger", "pdf", "png", "svg"]),
    ("Twist limit plate", "twist-limit", ["ledger", "pdf", "png", "svg"]),
    ("Machine evolution strip", "machine-evolution-strip", ["checks", "pdf", "png", "svg"]),
    ("System anatomy plate", "system-anatomy", ["checks", "ledger", "pdf", "png"]),
    ("Levers landscape", "pca-landscape", ["ledger", "pdf", "png", "svg"]),
    ("Parameter atlas", "pca-atlas", ["ledger", "pdf", "png", "svg"]),
    ("Machine winner", "machine-winner-hero", ["checks", "pdf", "png", "svg"]),
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
HEADS = (r"^(Ring utilisation plate|Twist limit plate|Machine evolution strip"
         r"|System anatomy plate|Levers landscape|Parameter atlas|Machine winner):$")

OK = FAIL = 0


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


def git_bytes(*a):
    return subprocess.run(["git", "-C", str(ROOT), *a], capture_output=True).stdout


def git_txt(*a):
    return git_bytes(*a).decode("utf-8")


def gitc(*a):
    return git_txt(*a).strip()


def sha256_bytes(b):
    return hashlib.sha256(b).hexdigest()


def md5_bytes(b):
    return hashlib.md5(b).hexdigest()


def nrm(t):
    t = t.replace("`", "")
    t = re.sub(r"\s+", " ", t)
    return re.sub(r"\s+([.,:;])", r"\1", t)


def manifest_stamp(m):
    bits = []
    cap = m.get("capture", {})
    if cap.get("run_id"):
        bits.append(cap["run_id"])
    data = m.get("data_commit")
    if data:
        bits.append(f"data {data}")
    else:
        s = (m.get("inputs", {}).get("extract", {}) or {}).get("sha256", "")
        if s:
            bits.append(f"data {s[:7]}")
    script = m.get("script_commit")
    if not script:
        s = m.get("script", {}).get("sha256", "")
        script = s[:7] if s else None
    if script:
        bits.append(f"script {script}")
    rows = m.get("registers") or m.get("inputs", {}).get("register_rows", [])
    if rows:
        bits.append("rows " + ", ".join(rows))
    return " · ".join(bits)


def docx_text(path):
    z = zipfile.ZipFile(path)
    xml = z.read("word/document.xml").decode("utf-8")
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", xml)), z


tip = gitc("rev-parse", "--short", "HEAD")
up = gitc("rev-parse", "--short", "origin/bank-derate-cos2p65")
dtext, z = docx_text(DOCX)
dn = nrm(dtext)
rec = BUILD_RECORD.read_text(encoding="utf-8")
draft = git_txt("show", f"HEAD:{DRAFT_REL}")
reg_head = git_txt("show", f"HEAD:{REG_REL}")
print(f"[0] v0.49 copy counter-read   tip {tip}   origin {up}   record {D_RECORD}   copy md5 {md5_bytes(DOCX.read_bytes())}")

print("[0] identity and freshness")
md5 = md5_bytes(DOCX.read_bytes())
(ok if md5 == COPY_MD5 else bad)("copy md5 reads the declared value")
(ok if md5 == md5_bytes(ARCHIVE.read_bytes()) else bad)("copy byte-identical to its archived build")
(ok if DOCX.stat().st_size == ARCHIVE.stat().st_size else bad)("copy and archive carry one size")
for s, name in [("Draft: `8169e36`", "build record names draft 8169e36"),
                ("file at `cb862df`", "build record refs register cb862df"),
                ("42 cited, every one signed (51 signed rows total)", "build record: 42 cited of 51 signed"),
                ("uncited: NR-024, NR-031, NR-033, NR-034, NR-035, NR-037, NR-038, NR-041, NR-051",
                 "build record uncited list reads the 9 ids"),
                ("checker exit 0", "build record: checker exit 0"),
                ("Seats resolved: 7 of 7", "build record: seven seats"),
                ("Built: 2026-10-15T14:43:42Z", "build record stamp 14:43:42Z"),
                ("Embed route: SVG vector-first, PNG fallback", "build record embed route")]:
    (ok if s in rec else bad)(name)
a = gitc("rev-parse", f"{D_RECORD}:{DRAFT_REL}")
b = gitc("rev-parse", f"HEAD:{DRAFT_REL}")
c = gitc("rev-parse", f"origin/bank-derate-cos2p65:{DRAFT_REL}")
(ok if a and a == b == c else bad)("draft blob reads 8169e36 == HEAD == origin")
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
(ok if st == "" else bad)("the 28 embedded bytes hold since the record")
(ok if gitc("log", "--format=%h", f"{D_RECORD}..HEAD", "--",
            "docs/reporting/figures/system-anatomy/captions.md") == ""
 else bad)("the builder caption input (captions.md) holds since the build")
moved = gitc("diff", "--name-only", D_RECORD, "HEAD").splitlines()
(ok if "docs/reporting/draft-tracker.md" not in moved else bad)("tracker not among post-build moves")
(ok if REG_REL not in moved and DRAFT_REL not in moved else bad)("register and draft not among post-build moves")
(ok if "docs/reporting/figures/system-anatomy/captions-draft.md" in moved else bad)(
    "the kit draft-captions file among the post-build moves (text only, not an embed)")
print(f"  post-build moves since {D_RECORD}: {len(moved)} paths")
(ok if tip == up else bad)("the read tip reads the same as origin")

print("[1] the copy input census (last read -> record)")
READ_PREV = "eb93928"  # the tip of the last copy read (the v0.47 walk)
mv_d = gitc("log", "--format=%h", f"{READ_PREV}..HEAD", "--", "docs/reporting/drafts").split()
(ok if sorted(mv_d) == sorted([F48, D_RECORD]) else bad)(f"draft movers read [6f19eee, 8169e36] ({mv_d})")
mv_t = gitc("log", "--format=%h", f"{READ_PREV}..HEAD", "--", TRACKER_REL).split()
(ok if sorted(mv_t) == sorted([F48, D_RECORD]) else bad)(f"tracker movers read [6f19eee, 8169e36] ({mv_t})")
for tag, a, b, exp_add, exp_rem in [
        ("v0.48 pins", D_PREV, F48, {"48": 1}, {"47": 1}),
        ("v0.49 re-keys", F48, D_RECORD, {"49": 1}, {"48": 1})]:
    ta, tb = Counter(TOK.findall(git_txt("show", f"{a}:{DRAFT_REL}"))), Counter(TOK.findall(git_txt("show", f"{b}:{DRAFT_REL}")))
    add = dict(tb - ta)
    rem = dict(ta - tb)
    (ok if add == exp_add and rem == exp_rem else bad)(
        f"{tag}: token delta reads add {dict(sorted(add.items()))} / rem {dict(sorted(rem.items()))}")

print("[2] the fold surfaces in the built copy")
(ok if dtext.count("Draft v0.49") == 1 else bad)("copy head line reads Draft v0.49 once")
for s in ("v0.37", "v0.38", "v0.39", "v0.40", "v0.41", "v0.42", "v0.43", "v0.44", "v0.45", "v0.46", "v0.47", "v0.48"):
    (ok if dtext.count(s) == 0 else bad)(f"copy reads zero '{s}' marks")
(ok if dn.count(CAPTION) == 1 else bad)("copy reads the F1 caption sentence once")
(ok if dtext.count("and down the lifting bridles to the main rotor") == 1 else bad)("copy reads the load-path sentence once")
(ok if dtext.count("Three bridles run") == 0 and dtext.count("down the bridles") == 0 else bad)("copy reads zero old label forms")
(ok if dtext.count("Machine winner") == 2 else bad)(f"copy reads 'Machine winner' twice ({dtext.count('Machine winner')})")
(ok if dtext.count("machine winner") == 0 else bad)("copy carries no lowercase marker form (the seat marker is consumed at build)")
(ok if dtext.count("Machine winner hero") == 0 and dtext.count("machine winner hero") == 0 else bad)("copy reads zero 'Machine winner hero'")
(ok if dtext.count("machine-winner-hero") == 3 else bad)(f"copy reads the slug three times ({dtext.count('machine-winner-hero')})")
(ok if dtext.count("hero") == 3 and dtext.count("Hero") == 0 and dtext.count("hero image") == 0
 else bad)("copy 'hero' reads three times, all in the slug")
for s, n, name in [("topmost ring", 9, "topmost ring"), ("topmost rotor ring", 2, "topmost rotor ring"),
                   ("Topmost ring radius", 1, "the table-row form (capital)"),
                   ("topmost ring radius", 3, "topmost ring radius"), ("topmost-ring", 1, "topmost-ring (hyphen)")]:
    c2 = dtext.count(s)
    (ok if c2 == n else bad)(f"copy count {name} reads {n} ({c2})")
c2 = len(re.findall(r"(?i)topmost", dtext))
(ok if c2 == 13 else bad)(f"copy count (?i)topmost reads 13 ({c2})")
(ok if dtext.count("The search found 508 feasible candidates in the searched space (NR-002).") == 1
 else bad)("copy reads the count sentence once")
(ok if dtext.count("The best performing one had a mean power of 5.309 kW.") == 1 else bad)("copy reads the founder winner sentence once")
(ok if dtext.count("Its airborne mass is 25.698 kilograms (NR-008, NR-018).") == 1 else bad)("copy reads the founder mass sentence once")
kg = dtext.count("25.698 kilograms")
(ok if kg == 4 else bad)(f"copy reads '25.698 kilograms' four times ({kg})")
(ok if dtext.count("The levers of Performance") == 1 else bad)("copy reads The levers of Performance once")
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

print("[3] the appendix pins, the stamps, the embeds and the token census")
region_draft = draft.split("## Appendix: Figure provenance", 1)[1]
n_vals = 0
for exhibit, slug, labels in EXHIBITS:
    heads = list(re.finditer(HEADS, region_draft, flags=re.M))
    body = ""
    for k, mm in enumerate(heads):
        if mm.group(1) == exhibit:
            start = mm.end()
            end = heads[k + 1].start() if k + 1 < len(heads) else len(region_draft)
            body = region_draft[start:end]
    for label in labels:
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
        else:
            bad(f"{slug}: {label} pin {pin[:12]} committed {got[:12]}")
(ok if n_vals == 28 else bad)(f"28 pinned values walked ({n_vals})")
app = region_draft
(ok if app.count("`1af63fc`") == 3 else bad)(f"appendix script cells: 1af63fc reads 3 ({app.count('`1af63fc`')})")
(ok if app.count("`9241b23`") == 1 else bad)(f"appendix script cells: 9241b23 reads 1 ({app.count('`9241b23`')})")
(ok if app.count("`74cfef9`") == 1 and app.count("`e23f226`") == 2 else bad)("appendix script cells: 74cfef9 x1, e23f226 x2")
exp_tok = Counter()
for exhibit, slug, labels in EXHIBITS:
    man = json.loads((ROOT / FIG_REL / slug / "manifest.json").read_text())
    stm = manifest_stamp(man)
    rowm = re.search(rf"\| {re.escape(exhibit)} .*?`([0-9a-f]{{7,40}})` \|", app)
    if rowm:
        exp_tok[rowm.group(1)] += 1
    sm = re.search(r"script ([0-9a-f]{7})", stm)
    if sm:
        exp_tok[sm.group(1)] += 1
for tok, n in sorted(exp_tok.items()):
    c2 = dtext.count(tok)
    (ok if c2 == n else bad)(f"copy token census {tok}: {c2} == expected {n}")
(ok if exp_tok.get("9241b23") == 2 and exp_tok.get("1af63fc") == 4 else bad)(
    f"token census reads 9241b23 x2 and 1af63fc x4 ({dict(exp_tok)})")
(ok if dtext.count("d243b37") == 0 and dtext.count("9cecee3") == 0 else bad)("copy reads zero d243b37/9cecee3 marks")
stamps_ok = 0
for exhibit, slug, labels in EXHIBITS:
    man = json.loads((ROOT / FIG_REL / slug / "manifest.json").read_text())
    stn = nrm("Source: " + manifest_stamp(man))
    valid = 0
    for m in re.finditer(re.escape(stn), dn):
        if dn[m.end():m.end() + 1] != ",":
            valid += 1
    if valid == 1:
        stamps_ok += 1
    else:
        bad(f"copy stamp missing or duplicated ({slug}): {stn[:80]} valid {valid}")
(ok if stamps_ok == 7 else bad)(f"seven stamps match their manifests ({stamps_ok})")
(ok if dtext.count("Source: ") == 7 else bad)(f"seven stamps read ({dtext.count('Source: ')})")
for f in FRAMES:
    (ok if dtext.count(f) == 1 else bad)(f"frame reads once: {f[:56]}")
(ok if dtext.count("Figure (") == 7 else bad)(f"seven figure frames read ({dtext.count('Figure (')})")
(ok if dtext.count("Figure seated") == 0 else bad)("raw markers read zero in the copy")
i33 = dtext.find("3.3 The winner")
i34 = dtext.find("3.4 The levers of Performance")
jf = dtext.find("machine-winner-hero Figure (roster row 10)")
(ok if i33 >= 0 and i33 < jf < i34 else bad)("the winner frame sits inside section 3.3 in the copy")
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
hub_word = [m for m in re.finditer(r"(?i)\bhub\b", dtext)]
hub_host = [m for m in hub_word if m.start() < i_reg or m.start() >= i_build]
(ok if len(hub_word) == 5 else bad)(f"the retired word reads 5 as a word ({len(hub_word)})")
(ok if not hub_host else bad)(f"the word reads zero outside the register appendix ({len(hub_host)})")
hub_ids = [m for m in re.finditer(r"(?i)(r_hub|blade_hub_radius)", dtext)]
(ok if len(hub_ids) == 2 else bad)(f"the two identifier holds read ({len(hub_ids)})")
(ok if dtext.count("Hub") == 0 else bad)(f"capitalised Hub reads zero ({dtext.count('Hub')})")
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

print("[5] the delta from the held copy, and the state anchors")
old_text, _oz = docx_text(OLD_ARCHIVE)
old_n = nrm(old_text)
(ok if "Three bridles run" in old_n and "Machine winner hero" in old_n else bad)("the v0.47 build reads the old forms")
old_pins = re.findall(r"`([0-9a-f]{64})`",
                      git_txt("show", f"{D_PREV}:{DRAFT_REL}").split("System anatomy plate:", 1)[1]
                      .split("Levers landscape:", 1)[0])
(ok if old_pins and all(p in old_n for p in old_pins) else bad)("the v0.47 build prints the old SA pins")
(ok if old_pins and all(p not in dtext for p in old_pins) else bad)("the v0.49 copy reads zero old SA pins")
for rel, needle, name in [
        ("docs/reporting/room-responses/author-2026-10-15-v049-rekeys.md", COPY_MD5, "author receipt names the copy md5"),
        ("docs/reporting/room-responses/figures-images-diagrams-2026-10-15-lifting-bridles-relabel.md",
         "lifting bridles (three)", "figures receipt names the drawn form"),
        ("docs/reporting/room-responses/science-validator-2026-10-15-lifting-bridles-term-gate.md",
         "24f98df6", "science-validator receipt names the copy"),
        ("docs/reporting/room-responses/science-writer-2026-10-15-sweep-31.md",
         "24f98df6", "sweep 31 receipt names the copy")]:
    body = (ROOT / rel).read_text()
    (ok if needle in body else bad)(name)
trk = git_txt("show", f"HEAD:{TRACKER_REL}")
(ok if "v0.49 pass by @author (2026-10-15)." in trk else bad)("tracker carries the v0.49 entry")
mp = git_txt("show", "HEAD:docs/reporting/figures/figure-map.md")
(ok if "v40" in mp else bad)("map carries delta v40")
(ok if tip == up else bad)("final: tip == origin")

print(f"\nchecks: {OK + FAIL}  ok: {OK}  fail: {FAIL}")
print("AV_V049_DONE" if FAIL == 0 else "AV_V049_FAIL")
sys.exit(1 if FAIL else 0)
