#!/usr/bin/env python3
"""sv_cvr_read_check.py — the convergence register read, the seed-form answer and the v0.55 fold read.

The science-validator read set for the row-16 convergence kit (2026-10-15).
It answers three routed items in one pass:

  A. The register read the figures seat gates the kit on: the eight cited rows
     read signed, the drawn set answers to them, the kit note's claims hold,
     the cite sets agree across the four surfaces and the pins recompute.
  B. The aero F-VALUE query: NR-006 "(gen 1, common seed)" against the strip
     pick (gen 0, idx 1). This checker re-reads all three convergence files
     against the three telemetry files and pins the generation mapping.
  C. The author's v0.55 fold read: the folded lines, the cite set and the
     exact diff set between the v0.54 and v0.55 drafts.

Reads only; writes nothing. Run from the repo root:
  /usr/bin/python3 scratch/sv_cvr_read_check.py
Exit 0 and token SV_CVR_READ_DONE iff every check passes.
"""
import csv
import hashlib
import io
import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
KIT = REPO / "docs" / "reporting" / "figures" / "convergence"
RD = REPO / "scripts" / "results" / "v13_5kw_masslift_len18.8_rotorcount_bankderate2"
REG = REPO / "docs" / "reporting" / "numbers-register.md"
DRAFT = REPO / "docs" / "reporting" / "drafts" / "2026-10-08-report-first-draft.md"
TRACKER = REPO / "docs" / "reporting" / "draft-tracker.md"

n = 0
fails = []


def chk(name, good, detail=None):
    global n
    n += 1
    if good:
        print(f"  OK   {name}")
    else:
        fails.append(name)
        print(f"  FAIL {name}" + (f" :: {detail}" if detail is not None else ""))


def sha256(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def md5(p):
    return hashlib.md5(Path(p).read_bytes()).hexdigest()


def read(p):
    return Path(p).read_text(encoding="utf-8")


def squeeze(t):
    return re.sub(r"\s+", " ", t)


def git(*args):
    r = subprocess.run(["git", "-C", str(REPO), *args], capture_output=True, text=True)
    return r.returncode, r.stdout, r.stderr


def telemetry(isl):
    data = [l for l in read(RD / f"island_{isl}" / "telemetry.csv").splitlines() if not l.startswith("#")]
    return list(csv.DictReader(io.StringIO("\n".join(data))))


def convergence(isl):
    data = [l for l in read(RD / f"island_{isl}" / "convergence.csv").splitlines() if not l.startswith("#")]
    return list(csv.DictReader(io.StringIO("\n".join(data))))


reg = read(REG)
kit_note = read(KIT / "register-status.md")
ledger = [l for l in read(KIT / "label-ledger.txt").splitlines() if l.strip()]
captions = read(KIT / "captions-draft.md")
capt_norm = squeeze(captions)
manifest = json.loads(read(KIT / "manifest.json"))
draft = read(DRAFT)

print("A. The register rows (the tip read):")
for nr in ["NR-002", "NR-003", "NR-004", "NR-005", "NR-006", "NR-036", "NR-054", "NR-055",
           "NR-042", "NR-045", "NR-015", "NR-046", "NR-014"]:
    line = next((l for l in reg.splitlines() if l.startswith(f"| {nr} |")), "")
    chk(f"{nr} carries a signed status", "signed" in line, line[-60:] if line else "row not found")
print()

print("B. The kit note and the drawn set:")
kit_norm = squeeze(kit_note)
for s in [
    "| NR-002 | The status mix 508 / 301 / 110 / 11. The legend counts | Signed |",
    "| NR-003 | Island 1 final 30.578. The caption tier | Signed |",
    "| NR-004 | Island 2 final 30.637. The caption tier | Signed |",
    "| NR-005 | The campaign winner 27.364 at generation 26. The star and its label | Signed |",
    "| NR-006 | The common seed 36.109. The seed label | Signed |",
    "| NR-036 | The search-objective label form, and the milestones. The y-axis label | Signed |",
    "| NR-054 | The three running-best series. Panel 2 | Signed (science-validator, 2026-10-15) |",
    "| NR-055 | The reject split 96 / 4 / 201, and the label rules. The legend | Signed (science-validator, 2026-10-15) |",
    "The figure draws no other row.",
    "The seed prints 36.109 at 3 dp (NR-006).",
    "The winner prints 27.364 at 3 dp (NR-005).",
    "The subgroup-C label reads",
    "The split reads the power floor first: 34 of the 96 also read FoS below 2.5 (NR-055 basis).",
    "The foot note states the read order.",
]:
    chk(f"kit note: {s[:66]!r}", s in kit_note or s in kit_norm)
chk("kit note: 'cause not logged' carries NR-055", 'cause not logged' in kit_note and "(NR-055)" in kit_note)

chk("ledger: 34 drawn strings", len(ledger) == 34, f"got {len(ledger)}")
members = [
    "feasible (508)",
    "rejected: rotor below 1.5 m clearance (110)",
    "rejected: twist past the crossing limit (11)",
    "rejected: power below the 5 kW floor (96)",
    "rejected: FoS below 2.5 (4)",
    "rejected: cause not logged (201)",
    "the common seed \u00b7 36.109",
    "the campaign winner \u00b7 27.364",
    "search objective (kg)",
    "the reject split reads the power floor first",
    "the campaign across generations 0 to 30 \u00b7 era post-95c385d_wind-authority",
    "rows NR-002 \u00b7 NR-003 \u00b7 NR-004 \u00b7 NR-005 \u00b7 NR-006 \u00b7 NR-036 \u00b7 NR-054 \u00b7 NR-055 \u00b7 script commit 0db99ac",
    "the running-best search objective of each island",
    "the outcome mix of each generation \u00b7 pooled over the three islands",
    "islands 1 and 2 improve to their last generation \u00b7 the budget stops the search",
    "First feasibility, then mass",
]
for m in members:
    chk(f"ledger holds {m[:64]!r}", m in ledger)
counts = []
for l in ledger:
    m = re.search(r"\((\d+)\)$", l)
    if m:
        counts.append(int(m.group(1)))
chk("ledger counts sum to 930", sum(counts) == 930, f"got {sum(counts)}")
chk("no status codes and no Track names print",
    not any(l in ("ok", "reject", "clearance_reject", "reject_twist") for l in ledger)
    and not any("Track" in l for l in ledger))

for s in [
    "36.109 kg-equivalent (NR-006)",
    "27.364 kg-equivalent at generation 26 (NR-005)",
    "to 30.578 and 30.637 (NR-003, NR-004)",
    "The search objective is not a mass reading (NR-036).",
    "Values cite NR-002, NR-003, NR-004, NR-005, NR-006, NR-036, NR-054 and NR-055.",
]:
    chk(f"caption tier: {s[:64]!r}", s in capt_norm)

# cite-set agreement across the four surfaces
note_rows = re.findall(r"\| (NR-\d+) \|", kit_note)
note_set = [r for r in note_rows]
cap_set = re.findall(r"NR-\d+", next(m for m in re.findall(r"Values cite[^.]*\.", capt_norm)))
led_set = re.findall(r"NR-\d+", next(l for l in ledger if l.startswith("rows NR-")))
man_set = manifest["inputs"]["register_rows"]
expected8 = ["NR-002", "NR-003", "NR-004", "NR-005", "NR-006", "NR-036", "NR-054", "NR-055"]
chk("cite set: the kit note lists the eight", note_set == expected8, str(note_set))
chk("cite set: the captions list the eight", sorted(set(cap_set)) == expected8)
chk("cite set: the ledger rows string lists the eight", led_set == expected8)
chk("cite set: the manifest lists the eight", man_set == expected8)

pins = {
    "convergence.svg": "548102e9bdaf32866b52fd4ebb1da8b5",
    "convergence.pdf": "30e9b1487ae084a08850f934627c11fd",
    "convergence.png": "27d10ab8b6fd2e57af2e4a4d9664c372",
    "label-ledger.txt": "eeed92b3f544c6ff2c29719995408b6f",
    "manifest.json": "54275ed84115cf80f28b1c2e06414cc5",
}
for f, want in pins.items():
    got = md5(KIT / f)
    chk(f"md5 {f}", got == want, got)

chk("manifest: extract sha256", sha256(REPO / "scratch" / "av_conv_series.csv") ==
    manifest["inputs"]["extracts"][0]["sha256"])
for isl, want in ((1, "6f359c33"), (2, "54172ce5"), (3, "34d40e8e")):
    chk(f"manifest: island {isl} telemetry sha256", sha256(RD / f"island_{isl}" / "telemetry.csv").startswith(want))
chk("manifest: script sha256", sha256(KIT / "convergence.py") == manifest["script"]["sha256"])

# the delivered PDF text layer carries the key drawn strings
r = subprocess.run(["pdftotext", "-layout", str(KIT / "convergence.pdf"), "-"],
                   capture_output=True, text=True)
pdf = squeeze(r.stdout)
for s in ["feasible (508)", "36.109", "27.364", "rejected: cause not logged (201)",
          "search objective (kg)", "the reject split reads the power floor first"]:
    chk(f"pdf layer holds {s[:52]!r}", s in pdf)
print()

print("C. The split recompute (the NR-055 basis):")
mix = Counter()
sub = Counter()
nfa = 0
for isl in (1, 2, 3):
    for row in telemetry(isl):
        mix[row["status"]] += 1
        if row["status"] == "reject":
            P, F, TL = float(row["P_mean"]), float(row["FoS"]), float(row["T_lift"])
            if P == 0.0 and F == float("inf") and TL == 0.0:
                sub["C"] += 1
            elif P < 5.0:
                sub["A"] += 1
                if F < 2.5:
                    nfa += 1
            elif F < 2.5:
                sub["B"] += 1
chk("mix 508/301/110/11", [mix["ok"], mix["reject"], mix["clearance_reject"], mix["reject_twist"]] == [508, 301, 110, 11])
chk("split 96/4/201", [sub["A"], sub["B"], sub["C"]] == [96, 4, 201], str(dict(sub)))
chk("floor-first overlap 34 of 96", nfa == 34, f"got {nfa}")
conv_ok = True
for isl in (1, 2, 3):
    for row in convergence(isl):
        if not (1 <= int(row["iteration"]) <= 30):
            conv_ok = False
chk("convergence files: 30 rows, iterations 1 to 30 (no gen-0 row)", conv_ok)
print()

print("D. The NR-006 seed-form alignment:")
maxdev = 0.0
total = 0
mism = 0
cums = {}
for isl in (1, 2, 3):
    rows = telemetry(isl)
    cum = {}
    best = None
    for k in range(31):
        for r_ in rows:
            if r_["status"] == "ok" and int(r_["gen"]) == k:
                f = float(r_["fitness"])
                if best is None or f < best[0]:
                    best = (f, int(r_["gen"]), int(r_["idx"]))
        cum[k] = best
    cums[isl] = cum
    for cr in convergence(isl):
        k = int(cr["iteration"])
        dev = abs(round(float(cr["fitness"]), 3) - cum[k][0])
        maxdev = max(maxdev, dev)
        total += 1
        if dev > 1e-9:
            mism += 1
    print(f"    island {isl}: gen-0 cum {cum[0][0]} src ({cum[0][1]},{cum[0][2]}) | gen 29 {cum[29][0]} | gen 30 {cum[30][0]}")
chk("iteration k = running-best at generation k, 90 of 90", total == 90 and mism == 0, f"total {total} mism {mism}")
chk("max deviation 0.0", maxdev == 0.0, f"got {maxdev}")
# the mapping pin: iteration 30 reads generation 30, not generation 29 (islands 1 and 2 move at gen 30)
chk("islands 1 and 2 move at generation 30 (pins k to k)",
    cums[1][29][0] != cums[1][30][0] and cums[2][29][0] != cums[2][30][0])
c3 = [r_ for r_ in convergence(3)]
chk("island 3 final reads NR-005 full precision", abs(float(c3[-1]["fitness"]) - 27.3635412663488) < 1e-12)
c1 = [r_ for r_ in convergence(1)]
chk("convergence first read rounds to the NR-006 form 36.109", round(float(c1[0]["fitness"]), 3) == 36.109)
print()

print("E. The v0.55 fold read:")
chk("draft pin reads v0.55 once", draft.count("Internal engineering report. Draft v0.55. Date 2026-10-15.") == 1)
chk("no v0.53/v0.54 mark reads", "v0.54" not in draft and "v0.53" not in draft)
chk("section 3.1 block reads once", draft.count("The reject class splits three ways (NR-055).") == 1)
chk("section 5 opener reads once", draft.count("The 301 rejects split three ways (NR-055).") == 1)
chk("the split lines read twice each", draft.count("96 ran below the 5 kW power floor.") == 2
    and draft.count("Four ran at or above 5 kW with a factor of safety below 2.5.") == 2
    and draft.count("The cause is not logged for the remaining 201.") == 2)
chk("shear-law row reads", "| Shear law | Hellmann power law, exponent 1/7, from the measured Daisy pair 10.0 m/s at 4.8 m | NR-056 |" in draft)
chk("shaft-elevation row reads", "| Shaft elevation | 30 deg, hub at 9.4000 m | NR-057 |" in draft)
chk("swing basis note reads", "The reported trace runs steady wind, so the swing reads as a steady-wind response, not a stability property (NR-058)." in draft)

r = subprocess.run([sys.executable, str(REPO / "scratch" / "sv_check_draft_citations.py"),
                    str(DRAFT), str(REG)], capture_output=True, text=True)
chk("citation checker rc=0", r.returncode == 0, f"rc {r.returncode}")
chk("citation checker reads 52 cited", "cited rows in 2026-10-08-report-first-draft.md: 52" in r.stdout)
chk("citation checker: every cited row signed (58 total)",
    "every cited row present and signed (58 signed rows total)" in r.stdout)

rc, out, _ = git("diff", "d453530", "2e930a8", "--", "docs/reporting/drafts/2026-10-08-report-first-draft.md")
adds = [l[1:] for l in out.splitlines() if l.startswith("+") and not l.startswith("+++")]
dels = [l[1:] for l in out.splitlines() if l.startswith("-") and not l.startswith("---")]
chk("draft fold: 16 added lines, 1 removed line", len(adds) == 16 and len(dels) == 1, f"adds {len(adds)} dels {len(dels)}")
want_add = Counter([
    "Internal engineering report. Draft v0.55. Date 2026-10-15.",
    "The reject class splits three ways (NR-055).",
    "96 ran below the 5 kW power floor.", "96 ran below the 5 kW power floor.",
    "Four ran at or above 5 kW with a factor of safety below 2.5.", "Four ran at or above 5 kW with a factor of safety below 2.5.",
    "The cause is not logged for the remaining 201.", "The cause is not logged for the remaining 201.",
    "| Shear law | Hellmann power law, exponent 1/7, from the measured Daisy pair 10.0 m/s at 4.8 m | NR-056 |",
    "| Shaft elevation | 30 deg, hub at 9.4000 m | NR-057 |",
    "The reported trace runs steady wind, so the swing reads as a steady-wind response, not a stability property (NR-058).",
    "The 301 rejects split three ways (NR-055).",
])
chk("draft fold: the added set reads exactly the declared fold", Counter([l for l in adds if l.strip()]) == want_add)
chk("draft fold: the removed line reads the v0.54 pin",
    dels == ["Internal engineering report. Draft v0.54. Date 2026-10-15."], str(dels))

rc, out, _ = git("diff", "d453530", "2e930a8", "--", "docs/reporting/draft-tracker.md")
adds_t = [l[1:] for l in out.splitlines() if l.startswith("+") and not l.startswith("+++")]
dels_t = [l[1:] for l in out.splitlines() if l.startswith("-") and not l.startswith("---")]
chk("tracker fold: 7 added lines, none removed", len(adds_t) == 7 and len(dels_t) == 0, f"adds {len(adds_t)} dels {len(dels_t)}")
chk("tracker fold: the v0.55 entry reads",
    "v0.55 pass by @author (2026-10-15)." in adds_t and "The swing sentence takes its steady-wind basis note (NR-058)." in adds_t)
print()

print(f"RESULT: {n} checks, {len(fails)} fail" + ("" if not fails else ": " + "; ".join(fails)))
if not fails:
    print("SV_CVR_READ_DONE")
sys.exit(0 if not fails else 1)
