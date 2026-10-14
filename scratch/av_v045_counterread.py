#!/usr/bin/env python3
"""The v0.45 copy counter-read (aero-validator, 2026-10-14).

Queue routing: the seat page and the queue list "the v0.45 copy walk" open
at this desk. This pass proves the delivered copy at md5 c88d1901 on its
own bytes, and re-keys the v5 system-anatomy re-cut from origin's bytes:

  [0] identity and freshness: copy md5, archived builds, build record,
      moved blobs, post-build register move (append-only, NR-051);
  [1] the census (v0.43 to v0.45): exactly two movers, the frozen diffs
      line for line, the token deltas per commit;
  [2] the v0.44 re-pin: the appendix cells, the four delivered hashes,
      the v5 re-cut re-key (label, ledger, PDF text layer, run records);
  [3] the v0.45 folds: the era map and the failure-ledger table, frozen
      from their supplies byte for byte;
  [4] holds: markers, the freeze block, guards, STE recounts;
  [5] the copy: pins, frames, stamps, the register appendix, guards;
  [6] state anchors: receipts, the queue, the fb5 flip, NR-051.

Reads committed bytes (git objects) and the delivered copy only.
Runs no simulator. Nothing rewrites a committed file.
"""
import hashlib
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
DRAFT_REL = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER_REL = "docs/reporting/draft-tracker.md"
REG_REL = "docs/reporting/numbers-register.md"
DOCX = ROOT / "scratch/report-pdf-build/draft-live.docx"
ARCHIVE = ROOT / "scratch/report-pdf-build/draft-34e3f81-20261014-204106.docx"
PREV_ARCHIVE = ROOT / "scratch/report-pdf-build/draft-e5541e9-20261014-200839.docx"
BUILD_RECORD = ROOT / "scratch/report-pdf-build/build-record-docx.txt"
BLOCK = ROOT / "scratch/sw_levers_reading_block.md"
FIG = ROOT / "docs/reporting/figures"
FIG_REL = "docs/reporting/figures"
D_PREV = "e5541e9"   # draft v0.43 pin (last read state)
D_A = "2f79aae"      # the v0.44 re-pin
D_B = "34e3f81"      # draft v0.45 (the copy's record draft)
REG_BUILD = "94aa219"  # register ref named in the build record
REG_HEAD_ADD = "cb862df"  # the post-build register append (NR-051)
COPY_MD5 = "c88d19015e5d755f347f30d0e456634d"
BLOCK_MD5 = "7bbd964db09d2b33269ce5cb8c334054"
ERA_MD5 = "d268d253b37d5388f8db36554d7ba3fa"      # 681 bytes, no trailing NL
LEDGER_MD5 = "f2e9df2399d89224300e11ea5038c7e8"   # 1569 bytes, no trailing NL
PIN = "e4ff3c1"
LEVERS_PIN = "d6d4db9"
HERO_ANCHOR = "e8159b0"

A_DRAFT_ADDED = [
    'Internal engineering report. Draft v0.44. Date 2026-10-14.',
    '| System anatomy plate | `scratch/fig1_decode_winner.jl` · `best_vector.csv` | NR-011, NR-017, NR-043 | `d243b37` | `post-95c385d_wind-authority` |',
    '- `png` `b78eb5cbe8f77074f04f9264e409f3de7f5aa97096a4f4f824c3bdf8271ecc9a`',
    '- `pdf` `b8fd60364168d70200f2f7122f7f9a957ea1590aa84c6197a19c79e811c444b6`',
    '- `ledger` `3adec59c7bd19b232584de4e6cb703b44d4e48bb820c68f1ed78f5086971dc8d`',
    '- `checks` `5255033809928282a348d525b6a7553df3ba64b267fcabb1499ecfaa75331810`',
]
A_DRAFT_REMOVED = [
    'Internal engineering report. Draft v0.43. Date 2026-10-14.',
    '| System anatomy plate | `scratch/fig1_decode_winner.jl` · `best_vector.csv` | NR-011, NR-017, NR-043 | `9cecee3` | `post-95c385d_wind-authority` |',
    '- `png` `f1c322bc20068299651bea7978bde254991b4037bf02fe689a15e1e3297a09ea`',
    '- `pdf` `9beffb6bf8463d39a5808164630d04d8c286184a4990a083296e7fc6d512f2cf`',
    '- `ledger` `b250c1a187132f68c37747b70f3d6081eb89e677ba378b12e6eb14b8a05a2389`',
    '- `checks` `0e857cbfb288ff7110aafec99c11211bae1c46e4d3b2a5594d5949f318d9f279`',
]
B_DRAFT_ADDED = [
    'Internal engineering report. Draft v0.45. Date 2026-10-14.',
    'The three movers carry their records. The bank derate is a',
    'calculated depowering of the main-rotor disc (NR-019, NR-020).',
    'The window basis sits at section 2.2.2, and the gate set at',
    'section 2.4.',
    '',
    '| Era | Effect on the search space | Data status |',
    '|---|---|---|',
    '| Before the bank derate | Earlier winners read different bank-angle physics, so they are not directly comparable. | Superseded as era record. |',
    '| The bank-derate basis | The measured bank derate applies to main-rotor disc power throughout (NR-019, NR-020). | Current campaign basis. |',
    '| The cp fix and the folded class | The span shrink and the cp fix moved the screen readings. The pre-fold rows failed the floor (NR-027). | Recorded: the folded class passes at 18.8 metres (NR-028). |',
    '| The wind-authority era (`post-95c385d_wind-authority`) | One wind authority reads the scored results. | Current physics era. |',
    '',
    '| Date / event | Class | What happened | Detection | Correction / lesson | Status |',
    '|---|---|---|---|---|---|',
    '| 2026-08-14 inverted-taper divergence | Geometry/decoder failure | An invalid genome diverged within seconds. The ground instruments still read normal power. | Divergence review | The decoder must refuse what the builder cannot make. The refusal lands at gate time. | Lesson applied. |',
    '| 2026-08-26 rotor-to-ring off-by-one | Decoder mapping error | The middle rotor landed on the hub. Every expansion rotor shifted one ring. | Visual geometry check (`preview_genome_geometry.jl`) | Validate the rotor-to-ring map against the built geometry. | Corrected. |',
    '| 2026-08-22 blade-mass-law correction | Model correction | The correction voided prior campaign winners. | Physics review | Void the affected data. Keep the record. | Data voided, record kept. |',
    '| 2026-08-13 k-alignment fault | Gain misalignment | The evaluator ran 5-kilowatt designs at the 50-kilowatt default gain. The scaled system gain sat near 1.94. | Acceptance test | One constant, one source file. | Caught and corrected. |',
    '| 2026-08-24 stale-gain re-gate | Stale configuration | The winner re-gate ran at a superseded gain. The check caught it. | Pre-push review | The re-gate at the campaign gain returned 5.18 kilowatts. | Corrected. |',
    '| 2026-08-22 FoS=Inf guard gap | Gate near-miss | The guard never reached several scoring paths. The re-gate screens winners. | Telemetry review | A gate must pin a measured number. Drift must fail the suite. | Near-miss, no corrupted survivor found. |',
    '',
]
B_DRAFT_REMOVED = ['Internal engineering report. Draft v0.44. Date 2026-10-14.']
A_TRACKER_ADDED = [
    'v0.44 pass by @fig-img-diagrams (2026-10-14).',
    'This pass re-pins the figure-provenance appendix to the delivered v5 system-anatomy re-cut.',
    'The plate script-commit cell and its four output-hash cells take the delivered values.',
    'The re-cut adds the cone-ring label (figure-map row 2; round-5 comment 3).',
    'No value moves.',
    '',
]
B_TRACKER_ADDED = [
    'v0.45 pass by @author (2026-10-14).',
    'This pass folds AU7: the era map at section 3.3 and the failure-ledger table at section 4.2.',
    'The era map takes the short pointer block and the four-row table.',
    'The failure-ledger table lands with the narrative after it.',
    'The two tables add the accepted table class.',
    'No value moves.',
    '',
]
TOK_DELTAS = [
    ("A draft", D_PREV, D_A, DRAFT_REL, {"44": 1}, {"43": 1}),
    ("B draft", D_A, D_B, DRAFT_REL,
     {"1.94": 1, "18.8": 1, "2": 1, "2.2": 1, "2.4": 1, "45": 1, "5.18": 1},
     {"44": 1}),
    ("A tracker", D_PREV, D_A, TRACKER_REL, {"2": 1, "3": 1, "44": 1}, {}),
    ("B tracker", D_A, D_B, TRACKER_REL, {"3.3": 1, "4.2": 1, "45": 1}, {}),
]
MARKERS = [
    "[Figure seated: figure-map row 2 (system anatomy plate, slug `system-anatomy`). Values cite NR-011, NR-017 and NR-043.]",
    "[Figure seated: figure-map row 10 (machine winner hero, slug `machine-winner-hero`). Values cite NR-011, NR-017, NR-021, NR-022 and NR-043.]",
    "[Figure seated: figure-map row 6 (ring utilisation plate, slug `ring-utilisation`). Values cite NR-021.]",
    "[Figure seated: figure-map row 7 (twist limit plate, slug `twist-limit`). Values cite NR-022 and NR-023.]",
    "[Figure seated: figure-map row 20 (the levers landscape, slug `pca-landscape`). Values cite NR-001, NR-005, NR-006, NR-044 and NR-045.]",
    "[Figure seated: figure-map row 21 (the parameter atlas, slug `pca-atlas`). Values cite NR-001, NR-005, NR-006 and NR-044.]",
    "[Figure seated: figure-map row 9 (machine evolution strip, slug `machine-evolution-strip`). Values cite NR-005, NR-006, NR-011 and NR-036.]",
]
FRAMES = [
    "system-anatomy Figure (roster row 2) · system-anatomy",
    "machine-winner-hero Figure (roster row 10) · machine-winner-hero",
    "ring-utilisation Figure (roster row 6) · ring-utilisation",
    "twist-limit Figure (roster row 7) · twist-limit",
    "pca-landscape Figure (roster row 20) · pca-landscape",
    "pca-atlas Figure (roster row 21) · pca-atlas",
    "machine-evolution-strip Figure (roster row 9) · machine-evolution-strip",
]
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
    "machine-evolution-strip": ["machine-evolution-strip.png",
                                "machine-evolution-strip.svg",
                                "machine-evolution-strip.pdf", "checks.log"],
    "system-anatomy": ["system-anatomy.png", "system-anatomy.pdf",
                       "label-ledger.txt", "checks.log"],
    "pca-landscape": ["pca-landscape.png", "pca-landscape.svg",
                      "pca-landscape.pdf", "label-ledger.txt"],
    "pca-atlas": ["pca-atlas.png", "pca-atlas.svg",
                  "pca-atlas.pdf", "label-ledger.txt"],
    "machine-winner-hero": ["machine-winner-hero.png",
                            "machine-winner-hero.svg",
                            "machine-winner-hero.pdf", "checks.log"],
}
KIT_PNGS = ["ring-utilisation/ring-utilisation.png",
            "twist-limit/twist-limit.png",
            "machine-evolution-strip/machine-evolution-strip.png",
            "system-anatomy/system-anatomy.png",
            "pca-landscape/pca-landscape.png",
            "pca-atlas/pca-atlas.png",
            "machine-winner-hero/machine-winner-hero.png"]
UNC8 = ["NR-024", "NR-031", "NR-033", "NR-034", "NR-035", "NR-037",
        "NR-038", "NR-041"]
SA_NEW = {
    "png": "b78eb5cbe8f77074f04f9264e409f3de7f5aa97096a4f4f824c3bdf8271ecc9a",
    "pdf": "b8fd60364168d70200f2f7122f7f9a957ea1590aa84c6197a19c79e811c444b6",
    "ledger": "3adec59c7bd19b232584de4e6cb703b44d4e48bb820c68f1ed78f5086971dc8d",
    "checks": "5255033809928282a348d525b6a7553df3ba64b267fcabb1499ecfaa75331810",
}
SA_MD5 = {"system-anatomy.tex": "8a6d82b74dde69965e224d2ce3293ccf",
          "prototype.html": "8225ea742dd25566e8c79c41ae57bfdf",
          "label-ledger.txt": "9832c94065d2d817303c40ec19ccb350",
          "system-anatomy.pdf": "77701b4024b957af21e54ca06ecdbebc",
          "system-anatomy.png": "9be129933420343205aa8f2592905b51"}
SA_SCRIPT_SHA = "ba9ae1d34106d9e5e2a790b49554c516136694dfb179e2221577c2b210bbaad3"
TOK = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")

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
    return subprocess.run(["git", "-C", str(ROOT), *args],
                          capture_output=True).stdout


def git_txt(*args):
    return git_bytes(*args).decode("utf-8")


def gitc(*args):
    return git_txt(*args).strip()


def gshow(rev_path):
    return git_bytes("show", rev_path)


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
    add = [l[1:] for l in out.splitlines()
           if l.startswith("+") and not l.startswith("+++")]
    rem = [l[1:] for l in out.splitlines()
           if l.startswith("-") and not l.startswith("---")]
    return add, rem


def manifest_stamp(manifest):
    """Replication of scripts/build_draft_pdf.manifest_stamp."""
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


z = zipfile.ZipFile(DOCX)
xml = z.read("word/document.xml").decode("utf-8")
dtext = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", xml))
dn = nrm(dtext)
rec = BUILD_RECORD.read_text(encoding="utf-8")
draft = git_txt("show", f"HEAD:{DRAFT_REL}")
draft_b = git_txt("show", f"{D_B}:{DRAFT_REL}")
tracker = git_txt("show", f"HEAD:{TRACKER_REL}")
reg_head = git_txt("show", f"HEAD:{REG_REL}")
reg_md = re.sub(r"\s+", " ", reg_head)
tip = gitc("rev-parse", "--short", "HEAD")
up = gitc("rev-parse", "--short", "origin/bank-derate-cos2p65")
md5 = md5_bytes(DOCX.read_bytes())
print(f"[0] v0.45 counter-read   tip {tip}   origin {up}   "
      f"record {D_B}   copy md5 {md5}")

print("[0] identity and freshness")
(ok if md5 == COPY_MD5 else bad)("copy md5 reads the declared value")
(ok if md5 == md5_bytes(ARCHIVE.read_bytes()) else bad)(
    "copy byte-identical to its archived build")
for s, name in [("Draft: `34e3f81`", "build record names draft 34e3f81"),
                ("Seats resolved: 7 of 7", "build record: seven seats"),
                ("checker exit 0", "build record: checker exit 0"),
                ("Built: 2026-10-14T20:41:06Z", "docx build stamp 20:41:06Z"),
                ("file at `94aa219`", "build record refs register 94aa219"),
                ("42 cited, every one signed (50 signed rows total)",
                 "build record: 42 cited of 50 signed"),
                ("uncited: NR-024, NR-031, NR-033, NR-034, NR-035, NR-037, NR-038, NR-041",
                 "build record uncited list reads the 8 ids")]:
    (ok if s in rec else bad)(name)
for rev in [D_B]:
    a = gitc("rev-parse", f"{rev}:{DRAFT_REL}")
    b = gitc("rev-parse", f"HEAD:{DRAFT_REL}")
    c = gitc("rev-parse", f"origin/bank-derate-cos2p65:{DRAFT_REL}")
    (ok if a and a == b == c else bad)("draft blob reads 34e3f81 == HEAD == origin")
    a = gitc("rev-parse", f"{rev}:{TRACKER_REL}")
    b = gitc("rev-parse", f"HEAD:{TRACKER_REL}")
    c = gitc("rev-parse", f"origin/bank-derate-cos2p65:{TRACKER_REL}")
    (ok if a and a == b == c else bad)("tracker blob reads 34e3f81 == HEAD == origin")
a = gitc("rev-parse", f"{REG_BUILD}:{REG_REL}")
b = gitc("rev-parse", f"{D_B}:{REG_REL}")
(ok if a and a == b else bad)(
    "the build-record register ref 94aa219 reads the register at 34e3f81")
d = gitc("diff", "--name-only", D_B, "HEAD", "--",
         "docs/reporting/drafts", "docs/reporting/draft-tracker.md",
         "docs/reporting/figures")
(ok if d == "" else bad)(
    f"copy inputs carry zero diff from {D_B} to the tip ({d!r})")
moved = gitc("diff", "--name-only", D_B, "HEAD").splitlines()
(ok if "docs/reporting/numbers-register.md" in moved else bad)(
    "the register is among the post-build moves")
(ok if "docs/agents/physics-topology.md" in moved else bad)(
    "the physics-topology amend is among the post-build moves")
new_reg = git_bytes("show", f"HEAD:{REG_REL}")
old_reg = git_bytes("show", f"{REG_BUILD}:{REG_REL}")
(ok if new_reg.startswith(old_reg) else bad)(
    "the register reads a strict prefix-extend (append-only, strongest form)")
r = gitc("diff", "--numstat", REG_BUILD, "HEAD", "--", REG_REL)
(ok if r.split()[:2] == ["62", "0"] else bad)(
    f"register additions since 94aa219 read 62/0 ({r})")
(ok if abs(len(new_reg) - len(old_reg)) == 3092 else bad)(
    "the append reads 3092 bytes")
(ok if "| NR-051 |" in reg_head else bad)("NR-051 row present")
ids_old = sorted({m.group(1) for m in re.finditer(r"^\| (NR-\d{3})", git_txt("show", f"{REG_BUILD}:{REG_REL}"), flags=re.M)})
ids_new = sorted({m.group(1) for m in re.finditer(r"^\| (NR-\d{3})", reg_head, flags=re.M)})
(ok if len(ids_old) == 50 else bad)(f"register at the build ref reads 50 ids ({len(ids_old)})")
(ok if len(ids_new) == 51 else bad)(f"register at HEAD reads 51 ids ({len(ids_new)})")
(ok if ids_new == sorted(ids_old + ["NR-051"]) else bad)(
    "the appended id reads NR-051 alone")
(ok if tip == up else bad)("the read tip reads the same as origin")

print("[1] the census (v0.43 to v0.45): two movers, frozen diffs, tokens")
movers = gitc("log", "--format=%h", f"{D_PREV}..HEAD", "--",
              "docs/reporting/drafts", "docs/reporting/draft-tracker.md")
(ok if sorted(movers.split()) == sorted([D_A, D_B]) else bad)(
    f"the draft and tracker move at exactly two commits ({movers.split()})")
for tag, (a, b, rel, exp_a, exp_r) in {
        "A draft": (D_PREV, D_A, DRAFT_REL, A_DRAFT_ADDED, A_DRAFT_REMOVED),
        "B draft": (D_A, D_B, DRAFT_REL, B_DRAFT_ADDED, B_DRAFT_REMOVED),
        "A tracker": (D_PREV, D_A, TRACKER_REL, A_TRACKER_ADDED, []),
        "B tracker": (D_A, D_B, TRACKER_REL, B_TRACKER_ADDED, [])}.items():
    add, rem = diff_lines(a, b, rel)
    (ok if add == exp_a else bad)(
        f"{tag}: added lines read the frozen set, line for line ({len(add)})")
    (ok if rem == exp_r else bad)(
        f"{tag}: removed lines read the frozen set ({len(rem)})")
n = gitc("diff", "--numstat", D_PREV, D_A, "--", DRAFT_REL).split()[:2]
(ok if n == ["6", "6"] else bad)(f"A draft numstat reads 6/6 ({n})")
n = gitc("diff", "--numstat", D_A, D_B, "--", DRAFT_REL).split()[:2]
(ok if n == ["22", "1"] else bad)(f"B draft numstat reads 22/1 ({n})")
for tag, a, b, rel, exp_add, exp_rem in TOK_DELTAS:
    base = git_txt("show", f"{a}:{rel}")
    cand = git_txt("show", f"{b}:{rel}")
    from collections import Counter as C
    ta, tb = C(TOK.findall(base)), C(TOK.findall(cand))
    add = {k: v for k, v in (tb - ta).items()}
    rem = {k: v for k, v in (ta - tb).items()}
    (ok if add == exp_add and rem == exp_rem else bad)(
        f"{tag}: token delta reads add {dict(sorted(add.items()))} / "
        f"rem {dict(sorted(rem.items()))}")
(ok if draft == draft_b else bad)("the draft at the pin reads the draft at the tip")

print("[2] the v0.44 re-pin and the v5 re-cut re-key")
(ok if draft.count("Draft v0.45") == 1 else bad)("draft head line reads Draft v0.45 once")
(ok if draft.count("Draft v0.44") == 0 and draft.count("Draft v0.43") == 0 else bad)(
    "old draft head lines read zero")
(ok if draft.count("d243b37") == 1 else bad)("draft reads d243b37 once (the cell)")
for s in ("9cecee3", "f1c322bc", "9beffb6b", "b250c1a1", "0e857cbf"):
    (ok if draft.count(s) == 0 else bad)(f"draft zero: old v4 form {s}")
for lbl, h in SA_NEW.items():
    (ok if draft.count(h) == 1 else bad)(f"draft reads the delivered {lbl} hash once")
# the ledger: 34 strings, two added lines exactly, PDF text layer
led = git_txt("show", f"HEAD:{FIG_REL}/system-anatomy/label-ledger.txt")
(ok if len(led.splitlines()) == 34 else bad)(
    f"label ledger reads 34 strings ({len(led.splitlines())})")
(ok if led.count("R5, the cone ring") == 1 else bad)("ledger reads the cone-ring label once")
(ok if led.count("the shaft cone starts here") == 1 else bad)("ledger reads the strip line once")
ladd, lrem = diff_lines(D_PREV, D_A, f"{FIG}/system-anatomy/label-ledger.txt")
(ok if ladd == ["R5, the cone ring", "the shaft cone starts here"] and lrem == [] else bad)(
    f"ledger delta reads the two lines alone ({len(ladd)} add, {len(lrem)} rem)")
pdf_txt = subprocess.run(["pdftotext", str(FIG / "system-anatomy/system-anatomy.pdf"), "-"],
                         capture_output=True).stdout.decode("utf-8")
(ok if pdf_txt.count("R5, the cone ring") == 1 else bad)("PDF text layer reads the cone-ring label once")
(ok if pdf_txt.count("the shaft cone starts here") == 1 else bad)("PDF text layer reads the strip line once")
# the run records: two runs, same five hashes, and they read the delivered bytes
run1 = (ROOT / "scratch/fig_sa_v5_run1.md5").read_text()
run2 = (ROOT / "scratch/fig_sa_v5_run2.md5").read_text()
(ok if run1 == run2 else bad)("the two run records read identical")
for fn, want in SA_MD5.items():
    got = md5_bytes((FIG / "system-anatomy" / fn).read_bytes())
    (ok if got == want else bad)(f"delivered {fn} md5 reads its run record")
    (ok if f"{want}  {fn}" in run1 else bad)(f"run record carries {fn}")
man = json.loads((FIG / "system-anatomy/manifest.json").read_text())
(ok if man.get("script_commit") == "d243b37" else bad)("manifest script_commit reads d243b37")
for key, lbl in [("system-anatomy.png", "png"), ("system-anatomy.pdf", "pdf"),
                 ("label-ledger.txt", "ledger"), ("checks.log", "checks"),
                 ("system-anatomy.tex", "tex")]:
    got = sha256_bytes((FIG / "system-anatomy" / key).read_bytes())
    (ok if man["outputs"].get(key) == got else bad)(f"manifest output {lbl} pins the delivered bytes")
(ok if sha256_bytes((FIG / "system-anatomy/system-anatomy.py").read_bytes()) == SA_SCRIPT_SHA else bad)(
    "the generator file reads the manifest script sha")
clog = git_txt("show", f"HEAD:{FIG_REL}/system-anatomy/checks.log")
(ok if "cone-ring leader clear" in clog else bad)("checks log reads the cone-ring leader clear")
(ok if "self-checks ok" in clog else bad)("checks log reads the self-check line")
spec = git_txt("show", f"HEAD:{FIG_REL}/system-anatomy/SPEC.md")
(ok if "Thirteen labels." in spec else bad)("SPEC reads Thirteen labels")
(ok if "cone-ring leader clearance holds" in re.sub(r"\s+", " ", spec) else bad)(
    "SPEC reads the leader clearance line")
figmap = git_txt("show", f"HEAD:{FIG_REL}/figure-map.md")
(ok if "v35 (2026-10-14)" in figmap and "v36 (2026-10-14)" in figmap else bad)(
    "map carries deltas v35 and v36")
(ok if "The v5 re-cut landed (`d243b37`)" in figmap else bad)("map row 2 cell reads the v5 pin")
# desk notes: the kit captions provenance token; the ring/twist stamp form
captions = git_txt("show", f"HEAD:{FIG_REL}/system-anatomy/captions.md")
prov = captions.split("## Provenance line", 1)[1].split("##", 1)[0]
if "9cecee3" in prov and "d243b37" not in prov:
    note("captions kit provenance section still carries 9cecee3 (v4); "
         "manifest/draft/copy carry d243b37 -- form note for the figures seat")

print("[3] the v0.45 folds: byte-frozen tables")
era_supply = (ROOT / "scratch/sw_sw3b_era_table.md").read_bytes()
led_supply = (ROOT / "scratch/sw_ws3a_ledger_table.md").read_bytes()
era_chunk = era_supply[:-1] if era_supply.endswith(b"\n") else era_supply
led_chunk = led_supply[:-1] if led_supply.endswith(b"\n") else led_supply
(ok if len(era_chunk) == 681 and md5_bytes(era_chunk) == ERA_MD5 else bad)(
    f"era supply chunk reads 681 bytes / d268d253 ({len(era_chunk)})")
(ok if len(led_chunk) == 1569 and md5_bytes(led_chunk) == LEDGER_MD5 else bad)(
    f"ledger supply chunk reads 1569 bytes / f2e9df23 ({len(led_chunk)})")
db = draft.encode()
(ok if db.count(era_chunk) == 1 else bad)("draft carries the era table bytes once")
(ok if db.count(led_chunk) == 1 else bad)("draft carries the ledger table bytes once")
i = db.find(era_chunk)
j = db.find(led_chunk)
(ok if 0 < i < j else bad)("the era table precedes the ledger table")
(ok if db.count(era_chunk + b"\n\n") == 1 and db.count(led_chunk + b"\n\n") == 1 else bad)(
    "both tables ride their blank-line closers as folded")
for s, n, name in [
        ("The three movers carry their records.", 1, "pointer line one"),
        ("The window basis sits at section 2.2.2, and the gate set at", 1, "pointer line two"),
        ("| Before the bank derate |", 1, "era row 1"),
        ("| The bank-derate basis |", 1, "era row 2"),
        ("| The cp fix and the folded class |", 1, "era row 3"),
        ("| The wind-authority era (`post-95c385d_wind-authority`) |", 1, "era row 4"),
        ("| 2026-08-14 inverted-taper divergence |", 1, "ledger entry 1"),
        ("| 2026-08-22 FoS=Inf guard gap |", 1, "ledger entry 6"),
        ("(NR-019, NR-020)", 2, "NR-019/NR-020 pair"),
        ("failed the floor (NR-027)", 1, "NR-027"),
        ("passes at 18.8 metres (NR-028)", 2, "NR-028"),
        ("The folded class passes at 18.8 metres (NR-028).", 1, "NR-028 era narrative")]:
    c = draft.count(s)
    (ok if c == n else bad)(f"draft count {name} reads {n} ({c})")
(ok if git_txt("show", f"{D_PREV}:{DRAFT_REL}").count("passes at 18.8 metres (NR-028)") == 1 else bad)(
    "the NR-028 phrase count grows by exactly one at B (narrative -> narrative + table)")

print("[4] holds: markers, freeze block, guards, STE")
ms = re.findall(r"\[Figure seated:[^\]]*\]", draft)
(ok if len(ms) == 7 else bad)(f"draft carries seven seated markers ({len(ms)})")
for m in MARKERS:
    (ok if draft.count(m) == 1 else bad)(f"marker reads once: {m[:58]}")
lines = draft.splitlines()
lo = lines.index("### 3.3 The winner")
hi = lines.index("### 3.4 The levers")
midx = lines.index(MARKERS[1])
(ok if lo < midx < hi else bad)("the hero marker sits inside section 3.3")
blk = BLOCK.read_bytes()
(ok if md5_bytes(blk) == BLOCK_MD5 else bad)("the freeze block file md5 reads 7bbd964d")
(ok if draft.count(blk.decode()) == 1 else bad)("the frozen levers block reads carried once")
btail = draft[draft.find(blk.decode()):][:len(blk.decode())].encode()
(ok if btail == blk else bad)("the draft-carried block bytes equal the file bytes")
for name, s, n in [("22 degrees sites", "22 degrees", 3),
                   ("shaft transition cone", "shaft transition cone", 2),
                   ("bank_bottom", "bank_bottom", 1),
                   ("0.75", "0.75", 1), ("0.113", "0.113", 1),
                   ("Tulloch", "Tulloch", 1), ("Jensen", "Jensen", 0)]:
    c = draft.count(s)
    (ok if c == n else bad)(f"draft count {name} reads {n} ({c})")
for name, s in [("old slot label", "Slot 1"), ("old pin 41", "Draft v0.41"),
                ("old pin 42", "Draft v0.42"), ("old pin 43", "Draft v0.43"),
                ("old pin 44", "Draft v0.44")]:
    c = draft.count(s)
    (ok if c == 0 else bad)(f"draft zero: {name} ({c})")
r = subprocess.run(["python3", "ste-lint.py", "--fail-above", "2.0",
                    str(ROOT / DRAFT_REL), str(ROOT / TRACKER_REL)],
                   capture_output=True, cwd=ROOT)
ste_out = r.stdout.decode()
(ok if r.returncode == 0 else bad)("STE reads rc=0 on the draft and tracker")
m = re.search(r"2026-10-08-report-first-draft\.md words=\s*(\d+) total=\s*(\d+)", ste_out)
(ok if m and (int(m.group(1)), int(m.group(2))) == (6876, 8) else bad)(
    f"STE draft recount reads 6876 / 8 ({m.groups() if m else None})")
m = re.search(r"draft-tracker\.md\s+words=\s*(\d+) total=\s*(\d+)", ste_out)
(ok if m and (int(m.group(1)), int(m.group(2))) == (2817, 11) else bad)(
    f"STE tracker recount reads 2817 / 11 ({m.groups() if m else None})")
wd = gitc("diff", "HEAD", "--", DRAFT_REL, TRACKER_REL)
(ok if wd == "" else bad)("the working tree draft and tracker read HEAD clean")

print("[5] the copy: pins, frames, stamps, register appendix, guards")
pins = []
pins_by = {}
n_vals = 0
region = draft.split("## Appendix: Figure provenance", 1)[1]
blocks = {}
heads = list(re.finditer(
    r"^(Ring utilisation plate|Twist limit plate|Machine evolution strip"
    r"|System anatomy plate|Levers landscape|Parameter atlas"
    r"|Machine winner hero):$", region, flags=re.M))
for k, m in enumerate(heads):
    start = m.end()
    end = heads[k + 1].start() if k + 1 < len(heads) else len(region)
    blocks[m.group(1)] = region[start:end]
(ok if len(blocks) == 7 else bad)(f"appendix carries seven blocks ({len(blocks)})")
for exhibit, slug, labels in EXHIBITS:
    body = blocks.get(exhibit, "")
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
        got = sha256_bytes(gshow(f"HEAD:docs/reporting/figures/{slug}/{fn}"))
        head_blob = gitc("rev-parse", f"HEAD:docs/reporting/figures/{slug}/{fn}")
        orig_blob = gitc("rev-parse",
                         f"origin/bank-derate-cos2p65:docs/reporting/figures/{slug}/{fn}")
        same_blob = head_blob == orig_blob and head_blob != ""
        if got == pin and same_blob:
            ok(f"{slug}: {label} pinned == committed == HEAD == origin")
            pins.append((fn, pin))
            pins_by[(slug, label)] = pin
        else:
            bad(f"{slug}: {label} pin {pin[:12]} committed {got[:12]}")
(ok if n_vals == 28 else bad)(f"28 pinned values walked ({n_vals})")
for lbl, want in SA_NEW.items():
    (ok if pins_by.get(("system-anatomy", lbl)) == want else bad)(
        f"system-anatomy {lbl} pin reads the delivered v5 value")
for slug, anchor, files in [
        ("system-anatomy", D_A, EXHIBIT_FILES["system-anatomy"]),
        ("ring-utilisation", PIN, EXHIBIT_FILES["ring-utilisation"]),
        ("twist-limit", PIN, EXHIBIT_FILES["twist-limit"]),
        ("pca-landscape", LEVERS_PIN, EXHIBIT_FILES["pca-landscape"]),
        ("pca-atlas", LEVERS_PIN, EXHIBIT_FILES["pca-atlas"]),
        ("machine-winner-hero", HERO_ANCHOR, EXHIBIT_FILES["machine-winner-hero"])]:
    for fn in files:
        a = gitc("rev-parse", f"{anchor}:docs/reporting/figures/{slug}/{fn}")
        b = gitc("rev-parse", f"HEAD:docs/reporting/figures/{slug}/{fn}")
        (ok if a == b and a != "" else bad)(f"{slug}: {fn} byte-stable from {anchor}")
for fn, pin in pins:
    (ok if pin in dtext else bad)(f"copy prints the {fn} pin")
for f in FRAMES:
    (ok if dtext.count(f) == 1 else bad)(f"frame reads once: {f[:56]}")
(ok if dtext.count("Figure (") == 7 else bad)(f"seven figure frames read ({dtext.count('Figure (')})")
(ok if dtext.count("Figure seated") == 0 else bad)("raw markers read zero in the copy")
(ok if dtext.count("Draft v0.45") == 1 else bad)("copy head line reads Draft v0.45")
for s in ("v0.37", "v0.38", "v0.39", "v0.40", "v0.41", "v0.42", "v0.43", "v0.44"):
    (ok if dtext.count(s) == 0 else bad)(f"copy reads zero '{s}' marks")
(ok if dtext.count("9cecee3") == 0 else bad)("copy reads zero v4 script marks")
(ok if dtext.count("d243b37") == 2 else bad)(
    f"copy reads d243b37 twice (figure stamp + appendix cell) ({dtext.count('d243b37')})")
# stamps == manifest-derived stamps, all seven
stamps_ok = 0
for exhibit, slug, labels in EXHIBITS:
    man_p = FIG / slug / "manifest.json"
    manifest = json.loads(man_p.read_text())
    st = manifest_stamp(manifest)
    stn = nrm("Source: " + st)
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
# desk note: the ring/twist stamps print sha-fallbacks; confirm pre-existing
old_txt = ""
if PREV_ARCHIVE.exists():
    oz = zipfile.ZipFile(PREV_ARCHIVE)
    oxt = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", oz.read("word/document.xml").decode("utf-8")))
    same_old = "data dd5a9dd \u00b7 script 224e916" in oxt and "data dd5a9dd \u00b7 script 75d82de" in oxt
    same_new = "data dd5a9dd \u00b7 script 224e916" in dtext and "data dd5a9dd \u00b7 script 75d82de" in dtext
    (ok if same_old == same_new else bad)(
        "the ring/twist sha-fallback stamps read identical across the two copies")
    if same_new:
        note("ring/twist stamps print the sha-fallback form (old manifests, no commit keys) -- pre-existing, flagged")
# the folds read in the copy
copy_bits = [
    ("pointer line one", "The three movers carry their records. The bank derate is a calculated depowering of the main-rotor disc (NR-019, NR-020)."),
    ("pointer line two", "The window basis sits at section 2.2.2, and the gate set at section 2.4."),
    ("era row 1", "Before the bank derate Earlier winners read different bank-angle physics, so they are not directly comparable. Superseded as era record."),
    ("era row 2", "The bank-derate basis The measured bank derate applies to main-rotor disc power throughout (NR-019, NR-020). Current campaign basis."),
    ("era row 3a", "The pre-fold rows failed the floor (NR-027)."),
    ("era row 3b", "the folded class passes at 18.8 metres (NR-028)."),
    ("era row 4a", "The wind-authority era"),
    ("era row 4b", "One wind authority reads the scored results. Current physics era."),
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
for name, s, n in [("22 degrees sites", "22 degrees", 3),
                   ("shaft transition cone", "shaft transition cone", 3),
                   ("0.75", "0.75", 2),
                   ("Tulloch", "Tulloch", 1),
                   ("Jensen", "Jensen", 0),
                   ("lower-number key", "A lower number is better", 0)]:
    c = dtext.count(s)
    (ok if c == n else bad)(f"copy count {name} reads {n} ({c})")
i_reg = dtext.find("Data register (cited rows)")
i_build = dtext.find("Build record (builder output)")
region_ids = sorted(set(re.findall(r"NR-\d{3}", dtext[i_reg:i_build])))
cited = sorted(set(ids_old) - set(UNC8))
(ok if len(cited) == 42 else bad)(f"cited set reads 42 ({len(cited)})")
(ok if region_ids == cited else bad)(
    f"copy register appendix == cited set ({len(region_ids)} ids)")
for u in UNC8:
    (ok if u not in region_ids else bad)(f"uncited {u} stays out")
(ok if "NR-019" in region_ids and "NR-020" in region_ids else bad)(
    "NR-019 and NR-020 enter the appendix set")
hits = [m.start() for m in re.finditer(re.escape("14.97"), dtext)]
(ok if len(hits) == 1 and all(i_reg <= h < i_build for h in hits) else bad)(
    f"14.97-class prints once, inside the register appendix ({len(hits)})")
for name, s, n in [("full-precision 14.971...", "14.971791422208508", 0),
                   ("guarded 3.816", "3.816", 0),
                   ("15.0", "15.0", 14), ("15.033", "15.033", 3),
                   ("14.972", "14.972", 1),
                   ("27.3635412663488", "27.3635412663488", 2),
                   ("27.364", "27.364", 11)]:
    c = dtext.count(s)
    (ok if c == n else bad)(f"copy display form {name} reads {n} ({c})")
(ok if not re.findall(r"27\.363(?!\d)", dtext) else bad)("guarded rounded 27.363 reads zero")
(ok if dtext.count("unresolved") == 0 else bad)("no unresolved notice")
(ok if dtext.count("All seven read dataset commit") == 1 else bad)(
    "copy count sentence reads 'All seven' once")
i33 = dtext.find("3.3 The winner")
i34 = dtext.find("3.4 The levers")
jf = dtext.find("machine-winner-hero Figure (roster row 10)")
(ok if i33 >= 0 and i33 < jf < i34 else bad)("the hero frame sits inside section 3.3 in the copy")
media = sorted(sha256_bytes(gshow(f"HEAD:docs/reporting/figures/{p}"))[:24] for p in KIT_PNGS)
embedded = sorted(hashlib.sha256(z.read(n)).hexdigest()[:24]
                  for n in z.namelist() if "media/" in n and n.endswith(".png"))
(ok if media == embedded else bad)(
    f"copy embeds the delivered bytes on all seven exhibits ({len(embedded)})")
for s, name in [("14.972", "NR-009 row form"),
                ("27.364 (found gen 26)", "NR-005 value"),
                ("1.4994019682084492 (quote 1.499)", "NR-043 span"),
                ("2.4341173109692225", "NR-050 r_rotor"),
                ("cone_slope_deg 22.0", "NR-049 cone value"),
                ("bank_bot 22°", "NR-011 bank form")]:
    (ok if s in dtext[i_reg:i_build] else bad)(f"register appendix: {name}")

print("[6] state anchors")
for rel, needle, name in [
        (f"{FIG}/system-anatomy/register-status.md", "v5 (2026-10-14)", "register status reads the v5 block"),
        (f"{FIG}/system-anatomy/register-status.md", "Script commit `d243b37`", "register status reads the v5 script commit"),
        ("docs/reporting/room-responses/figures-images-diagrams-2026-10-14-v5-cone-ring-recut.md",
         "the re-cut re-keys at your desk", "figures receipt routes the re-key"),
        ("docs/reporting/room-responses/author-2026-10-14-v045-au7-discussion.md",
         "f2e9df2399d89224300e11ea5038c7e8", "author receipt names the ledger supply md5"),
        ("docs/reporting/room-responses/science-validator-2026-10-14-round6-signs.md",
         "NR-051", "science-validator receipt signs NR-051"),
        ("docs/reporting/room-responses/figures-images-diagrams-2026-10-14-corner-grid-mint-and-picks.md",
         "i1-g13-i1", "corner mint receipt reads the picks"),
        ("docs/reporting/room-responses/hermes-2026-10-14-feedback5-routing.md",
         "v2 (2026-10-14): the comment 2 parenthetical flips", "the fb5 flip reads closed with its dated delta"),
        ("handovers/handover-2026-10-14-reporting-room-queue.md",
         "The v0.45 copy walk reads open.", "queue lists the v0.45 walk open"),
        ("docs/agents/physics-topology.md", "topmost rotor ring", "physics-topology reads the retirement form")]:
    body = Path(ROOT / rel).read_text() if (ROOT / rel).exists() else git_txt("show", f"HEAD:{rel}")
    (ok if needle in body else bad)(name)
for s in ("60.646", "58.864", "33.704", "33.812"):
    (ok if s in reg_head else bad)(f"NR-051 carries pick value {s}")
(ok if "corner-grid picks" in reg_head else bad)("register carries the NR-051 heading")
(ok if "v0.44 pass by @fig-img-diagrams (2026-10-14)." in tracker else bad)(
    "tracker carries the v0.44 entry")
(ok if "v0.45 pass by @author (2026-10-14)." in tracker else bad)(
    "tracker carries the v0.45 entry")
(ok if tip == up else bad)("final: tip == origin")

print(f"\nchecks: {OK + FAIL}  ok: {OK}  fail: {FAIL}")
print("AV_V045_DONE" if FAIL == 0 else "AV_V045_FAIL")
sys.exit(1 if FAIL else 0)
