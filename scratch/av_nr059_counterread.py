#!/usr/bin/env python3
"""av_nr059_counterread.py — the aero-seat counter-read of the signed NR-059 block.

Verifies, from the raw evidence at the tip:
  A. The row values: every figure re-derives from the committed read log
     (5-decimal log forms and the row's 3-decimal quote forms).
  B. The block claims: the sign-off basis lines, the reading rules, the request line.
  C. The cross-seat reproduction: the science seat's re-run log against the
     committed log (masked line-for-line; raw diffs on the header and wall times).
  D. The register mechanics: append-only, the census deltas, no signed row changed.
  E. The pins: sha256 pins, the first-landing commit.
  F. Supplementary: the draft read (digit forms and the cite count).
  G. The direction scope: the window and relax sideways-share series from
     scratch/av_nr059_window_yshare.log (the counter-read instrument run).

Run from the repo root:  python3 scratch/av_nr059_counterread.py
Exit non-zero on any fail.
"""
import hashlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(".")
AV = ROOT / "scratch" / "av_bow_probe.log"
SV = ROOT / "scratch" / "sv_bow_probe_recheck.log"
PROBE = ROOT / "scratch" / "av_bow_probe.jl"
SUPPLY = ROOT / "scratch" / "av_bow_read_supply.md"
REG = ROOT / "docs" / "reporting" / "numbers-register.md"
DRAFT = ROOT / "docs" / "reporting" / "drafts" / "2026-10-08-report-first-draft.md"
WYS = ROOT / "scratch" / "av_nr059_window_yshare.log"

PROBE_SHA = "24a1601718dcb2d8536872ca975b6a823fed640e72686486c434fdc6216c73a4"
LOG_SHA = "eacc0ce3acbcdeb66b6dd9db975b177ceb401a2929bee2c40fd258e22f2bf987"
ROW_VALUE = ("midpoint ring settle 0.002 m, window 0.105 to 0.310 m. "
             "Hub max settle 0.002 m, window 0.209 to 0.613 m. "
             "Extension end midpoint 0.422 m, hub 0.833 m. "
             "Settle and run do not agree on the bowed shape")

fails = 0
n = 0


def chk(name, cond, detail=""):
    global fails, n
    n += 1
    if cond:
        print(f"PASS  {name}")
    else:
        fails += 1
        print(f"FAIL  {name}  [{detail}]")


def sha256(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout


def section(text, start, end):
    return text.split(start, 1)[1].split(end, 1)[0]


# ---------- load ----------
av = AV.read_text()
av_l = av.splitlines()
sv_all = SV.read_text().splitlines()
reg = REG.read_text()
sup = SUPPLY.read_text()
draft = DRAFT.read_text()

# ---------- A. the values from the committed log ----------
settle_sec = section(av, "── SETTLE-STATE bow profile", "── phase 3")
window_sec = section(av, "── WINDOW bow profile", "── phase 4")
ext_sec = section(av, "── phase 4: extension run", "raw: hub at t=200")

settle_rows = {}
for m in re.finditer(r"^\s+(\d)\s+([0-9.]+)\s+([0-9.]+)\s+([+-]?[0-9.]+)\s+([+-][0-9.]+)\s+([0-9.]+)",
                     settle_sec, re.M):
    settle_rows[int(m.group(1))] = m.groups()
chk("settle table reads six rings", sorted(settle_rows) == [1, 2, 3, 4, 5, 6], str(sorted(settle_rows)))
chk("midpoint ring 5 settle perp reads 0.00160", settle_rows.get(5, ("",) * 6)[2] == "0.00160")
chk("hub ring 6 settle perp reads 0.00241", settle_rows.get(6, ("",) * 6)[2] == "0.00241")
mid = (float(settle_rows[1][1]) + float(settle_rows[6][1])) / 2
chk("ring 5 is nearest to the axial midpoint",
    abs(float(settle_rows[5][1]) - mid) < abs(float(settle_rows[4][1]) - mid))

win_rows = {}
for m in re.finditer(r"^\s+(\d)\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s+([+-][0-9.]+)",
                     window_sec, re.M):
    win_rows[int(m.group(1))] = m.groups()
chk("window table ring 5: settle .00160 mean .22288 min .10531 max .31005",
    win_rows.get(5, ("",) * 6)[1:5] == ("0.00160", "0.22288", "0.10531", "0.31005"),
    str(win_rows.get(5)))
chk("window table ring 6: settle .00241 mean .44098 min .20862 max .61302",
    win_rows.get(6, ("",) * 6)[1:5] == ("0.00241", "0.44098", "0.20862", "0.61302"),
    str(win_rows.get(6)))

g = re.search(r"window hub perp \(ring 6\): min ([0-9.]+)  mean ([0-9.]+)  max ([0-9.]+) m", av)
chk("window hub line min/mean/max", g is not None and g.groups() == ("0.20862", "0.44098", "0.61302"), str(g))
g = re.search(r"window mid-span ring 5 perp: min ([0-9.]+)  mean ([0-9.]+)  max ([0-9.]+) m", av)
chk("window mid-span line min/mean/max", g is not None and g.groups() == ("0.10531", "0.22288", "0.31005"), str(g))

ext_rows = {}
for m in re.finditer(r"^\s+(\d+)\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s+([+-][0-9.]+)", ext_sec, re.M):
    ext_rows[int(m.group(1))] = m.groups()
chk("extension table reads 29 rows", len(ext_rows) == 29, str(len(ext_rows)))
chk("ext t=195: hub 0.83331 mid 0.42202",
    ext_rows.get(195, ("",) * 5)[2:4] == ("0.83331", "0.42202"), str(ext_rows.get(195)))
g = re.search(r"terminal: hub perp ([0-9.]+) m at t=195 \(last 5 s increment ([+-][0-9.]+) m\); mid-span ([0-9.]+) m", av)
chk("terminal line: hub .83331, increment +.00053, mid .42202",
    g is not None and g.groups() == ("0.83331", "+0.00053", "0.42202"), str(g))
g = re.search(r"raw: hub at t=200 = \[[^\]]+\]  perp = ([0-9.]+)", av)
chk("raw hub read at t=200 = 0.833774", g is not None and g.groups() == ("0.833774",), str(g))

g = re.search(r"max \|settle - window_mean\| = ([0-9.]+) m at ring (\d+)", av)
chk("largest deviation 0.43857 m at ring 6", g is not None and g.groups() == ("0.43857", "6"), str(g))
dev = abs(0.00241 - 0.44098)
chk("deviation recomputes: |0.00241 - 0.44098| -> 0.43857", f"{dev:.5f}" == "0.43857", f"{dev!r}")

g = re.search(r"direction   : settle down_frac ([0-9.]+) \(y ([+-][0-9.]+)\); t=200 down_frac ([0-9.]+) \(y ([+-][0-9.]+)\)", av)
chk("direction: settle down_frac .9999, t=200 down_frac 1.0000",
    g is not None and g.group(1) == "0.9999" and g.group(3) == "1.0000", str(g))

ys = [float(m) for m in re.findall(r"^\s+\d+\s+[0-9.]+\s+[0-9.]+\s+[0-9.]+\s+([+-][0-9.]+)$", ext_sec, re.M)]
chk("extension series carries 29 y-shares", len(ys) == 29, str(len(ys)))
ymax_ext = max(abs(v) for v in ys)
chk("extension sideways share max reads 0.00217", f"{ymax_ext:.5f}" == "0.00217", f"{ymax_ext:.5f}")
print(f"  extension max |y share| = {ymax_ext:.5f} over {len(ys)} samples")

chk("bench gates all true", "bench gates vs recorded: fitness true (27.3635412663488)  omega_eq true  P_end true  twist true  FoS true" in av)
chk("protocol gates all true", "protocol gates vs phase 1: settle-omega true  P_end true  twist true  FoS true" in av)
chk("integrity line true", "integrity: settle arrays unchanged after both runs = true" in av)
m = re.search(r"omega_settle = ([0-9.]+)   \(recorded ([0-9.]+)\)", av)
chk("settle omega reads the recorded value",
    m is not None and m.groups() == ("10.169820334285198", "10.169820334285198"))
chk("any_broken false in both runs", av.count("any_broken = false") == 2)
chk("window 40 / extension 29 samples", "samples = 40" in av and "samples = 29" in av)
chk("max-bow ring is the hub in all 40 samples", "max-bow ring across samples: Dict(6 => 40)" in av)

r_50 = 0.31005 / 0.61302
r_195 = 0.42202 / 0.83331
chk("mid/hub ratio reads 0.5058 at t=50 s", f"{r_50:.4f}" == "0.5058", f"{r_50!r}")
chk("mid/hub ratio reads 0.5064 at t=195 s", f"{r_195:.4f}" == "0.5064", f"{r_195!r}")
chk("founder line met: midpoint below 0.5 m in every state", 0.00160 < 0.5 and 0.31005 < 0.5 and 0.42202 < 0.5)

forms = [("0.00160", "0.002"), ("0.10531", "0.105"), ("0.31005", "0.310"),
         ("0.00241", "0.002"), ("0.20862", "0.209"), ("0.61302", "0.613"),
         ("0.42202", "0.422"), ("0.83331", "0.833")]
bad = [(v, q, f"{float(v):.3f}") for v, q in forms if f"{float(v):.3f}" != q]
chk("every row quote form re-derives at 3 decimals from the 5-decimal log form", not bad, str(bad))

# ---------- B. the block claims ----------
block = reg.split("## Derived row: NR-059", 1)[1]
BLOCK_STRS = [
    "This block appends only, under the amend pattern. No signed row changed.",
    "The founder word \"up\" (2026-10-15) sent the winner bow probe at the aero seat.",
    "This seat reproduced the read at the tree tip and signs the row.",
    "The reproduction. This seat re-ran the committed probe in a detached worktree at `650fa49`. The two logs match line for line. Only the git header and the four wall-time lines differ.",
    "The settle speed reads 10.169820334285198 rad/s.",
    "Settle 0.00160 m. Window 0.10531 to 0.31005 m, mean 0.22288 m. Extension end 0.42202 m.",
    "Settle 0.00241 m. Window 0.20862 to 0.61302 m, mean 0.44098 m. Extension end 0.83331 m, raw 0.833774 m.",
    "down fraction 0.9999 at settle and 1.0000 at t=200 s",
    "The sideways share stays under 0.003.",
    "The ratio reads 0.5058 at t=50 s and 0.5064 at t=195 s.",
    "The largest deviation reads 0.43857 m at ring 6.",
    "Every midpoint state reads below 0.5 m against the 1.5 m bar.",
    "The row quotes 3 decimals from the 5-decimal log forms.",
    "The source cell. The cell takes the two evidence pins and the landing commit at the sign. No value changed.",
    "Every bow number quotes with its station and its state.",
    "The founder station reads the midpoint ring (ring 5). The max station reads the hub (ring 6).",
    "The settle and run disagreement reads as an instrument finding. It never reads as a design verdict.",
    "The barred September estimate prints no result. The 1.5 m line is a comparison bar only.",
    "The glossary entry (v20) carries no value. The value reads from this row.",
    "Counter-read requested from the aero seat.",
]
for i, s in enumerate(BLOCK_STRS):
    chk(f"block string {i + 1} reads verbatim", s in block, s[:60])

# ---------- C. the cross-seat reproduction ----------
sent = sv_all.index("AV_BOW_PROBE_DONE")
idx0 = next(i for i, l in enumerate(sv_all) if l.startswith("=== av_bow_probe.jl"))
sv = sv_all[idx0:sent + 1]
print(f"  re-run section start at line {idx0 + 1} ({idx0} prefix lines before it)")
chk("re-run probe section reads 127 lines", len(sv) == 127, f"{len(sv)}")


def mask(line):
    line = re.sub(r"wall = [0-9.]+ s", "wall = X s", line)
    line = re.sub(r"git=[0-9a-f]+", "git=X", line)
    return line


raw = [i + 1 for i, (a, b) in enumerate(zip(av_l, sv)) if a != b]
norm = [i + 1 for i, (a, b) in enumerate(zip(av_l, sv)) if mask(a) != mask(b)]
chk("masked line-for-line equality over the whole probe section", not norm, f"first diffs at {norm[:5]}")
chk("raw diffs sit only on the git header and the four wall-time lines",
    set(raw) <= {1, 7, 27, 45, 75}, str(raw))
print(f"  raw differing lines: {raw}  ({len(av_l) - len(norm)} of {len(av_l)} identical after masking)")
chk("line 1 is the git header", av_l[0].startswith("=== av_bow_probe.jl"))
for ln in (7, 27, 45, 75):
    chk(f"line {ln} carries a wall time", "wall = " in av_l[ln - 1] and "wall = " in sv[ln - 1])

foot = "\n".join(sv_all[sent + 1:])
chk("footer: worktree HEAD = 650fa49...", "worktree HEAD = 650fa49cdfd2e4736d3dd05577e9a9fcbdc7908f" in foot)
chk("footer: src drift 4e9c6bd..HEAD = 0", "src drift 4e9c6bd..HEAD = 0" in foot)
chk("footer: PROBE_RC=0", "PROBE_RC=0" in foot)
chk("footer: probe sha pin present", PROBE_SHA in foot)

# ---------- D. the register mechanics ----------
base_reg = git("show", "650fa49:docs/reporting/numbers-register.md")
tip_row_lines = len(re.findall(r"^\| NR-[0-9]{3}", reg, re.M))
base_row_lines = len(re.findall(r"^\| NR-[0-9]{3}", base_reg, re.M))
chk("row lines census reads +1", tip_row_lines == base_row_lines + 1, f"{base_row_lines} -> {tip_row_lines}")
tip_ids = sorted(set(re.findall(r"NR-[0-9]{3}", reg)))
base_ids = sorted(set(re.findall(r"NR-[0-9]{3}", base_reg)))
chk("distinct identifier census reads +1", len(tip_ids) == len(base_ids) + 1, f"{len(base_ids)} -> {len(tip_ids)}")
chk("the new identifier is NR-059", "NR-059" in tip_ids and "NR-059" not in base_ids)
tip_signed = reg.count("signed (")
base_signed = base_reg.count("signed (")
chk("signed-validator cells read +1", tip_signed == base_signed + 1, f"{base_signed} -> {tip_signed}")
dnum = git("diff", "--numstat", "650fa49", "7aaf2ea", "--", "docs/reporting/numbers-register.md").strip()
chk("register diff reads 52 added / 0 removed", dnum == "52\t0\tdocs/reporting/numbers-register.md", dnum)
ddiff = git("diff", "650fa49", "7aaf2ea", "--", "docs/reporting/numbers-register.md")
removed = [l for l in ddiff.splitlines() if l.startswith("-") and not l.startswith("---")]
chk("no line removed or modified (append-only)", not removed, str(removed[:5]))
chk("base register reads a strict prefix of the tip register",
    reg.splitlines()[:len(base_reg.splitlines())] == base_reg.splitlines())
later = git("diff", "--numstat", "7aaf2ea", "HEAD", "--", "docs/reporting/numbers-register.md").strip()
chk("register byte-held from 7aaf2ea to the tip", later == "", later)

# ---------- E. pins and landing ----------
chk("probe sha256 equals the pin", sha256(PROBE) == PROBE_SHA, sha256(PROBE))
chk("committed log sha256 equals the pin", sha256(AV) == LOG_SHA, sha256(AV))
land_probe = git("log", "--diff-filter=A", "--format=%h", "--", "scratch/av_bow_probe.jl").strip()
land_log = git("log", "--diff-filter=A", "--format=%h", "--", "scratch/av_bow_probe.log").strip()
chk("probe first-landing = c6d2885", land_probe == "c6d2885", land_probe)
chk("log first-landing = c6d2885", land_log == "c6d2885", land_log)


def cells(line):
    return [c.strip() for c in line.split("|")]


row = cells(next(l for l in reg.splitlines() if l.startswith("| NR-059 |")))
chk("row value cell equals the aero proposal text", row[3] == ROW_VALUE, row[3][:90])
sup_row = cells(next(l for l in sup.splitlines() if l.startswith("| NR-059 |")))
chk("supply proposal value cell reads the same text", sup_row[3] == ROW_VALUE, sup_row[3][:90])
nums = re.findall(r"[0-9]+\.[0-9]+", row[3])
chk("row value cell carries exactly the eight quoted forms",
    nums == ["0.002", "0.105", "0.310", "0.002", "0.209", "0.613", "0.422", "0.833"], str(nums))
chk("row unit cell reads m", row[4] == "m", row[4])
chk("row status cell reads signed (science-validator, 2026-10-16)",
    row[6] == "signed (science-validator, 2026-10-16)", row[6])
chk("source cell carries the probe pin", PROBE_SHA in row[5])
chk("source cell carries the log pin", LOG_SHA in row[5])
chk("source cell names the landing commit", "c6d2885" in row[5])
chk("source cell names the re-run log and the checker",
    "sv_bow_probe_recheck.log" in row[5] and "sv_bow_sign_check.py" in row[5])

# ---------- F. supplementary: the draft read ----------
cites = draft.count("NR-059")
chk("draft cites NR-059 five times", cites == 5, f"{cites}")
for form in ("0.002 m", "0.105", "0.310", "0.209", "0.613", "0.422", "0.833"):
    chk(f"draft carries {form}", form in draft)
chk("draft carries the 1.5 m line", "1.5 m" in draft)

# ---------- G. the direction scope (window y-share, the counter-read instrument) ----------
WYS1 = ROOT / "scratch" / "av_nr059_window_yshare_run1_refused.log"
if WYS.exists():
    wys = WYS.read_text()
    chk("instrument self-check passed (exact anchors)", "ANCHORS_OK = true" in wys)
    chk("instrument sentinel", "WINDOW_YSHARE_DONE" in wys)
    chk("instrument omega_end matches the committed value exactly", "exact match = true" in wys)
    hg = re.search(r"hub_y: \[([^\]]+)\]", wys)
    mg = re.search(r"mid_y: \[([^\]]+)\]", wys)
    hub_y = [float(v) for v in hg.group(1).split(",")] if hg else []
    mid_y = [float(v) for v in mg.group(1).split(",")] if mg else []
    chk("window hub y-series reads 40 samples", len(hub_y) == 40, str(len(hub_y)))
    chk("window mid y-series reads 40 samples", len(mid_y) == 40, str(len(mid_y)))
    wh = max((abs(v) for v in hub_y), default=float("nan"))
    wm = max((abs(v) for v in mid_y), default=float("nan"))
    chk("window |y| max hub reads 0.03740", f"{wh:.5f}" == "0.03740", f"{wh:.5f}")
    chk("window |y| max mid reads 0.03734", f"{wm:.5f}" == "0.03734", f"{wm:.5f}")
    hub_under = next((11 + i for i, v in enumerate(hub_y) if abs(v) < 0.003), None)
    mid_under = next((11 + i for i, v in enumerate(mid_y) if abs(v) < 0.003), None)
    chk("hub reads under 0.003 from t=37 s", hub_under == 37, str(hub_under))
    chk("mid reads under 0.003 from t=38 s", mid_under == 38, str(mid_under))
    relax = [float(m) for m in re.findall(r"y_frac=([+-][0-9.]+)", wys)]
    r_peak = max((abs(v) for v in relax), default=float("nan"))
    chk("relax sampled peak |y| reads 0.23586", f"{r_peak:.5f}" == "0.23586", f"{r_peak:.5f}")
    chk("run-1 refusal log kept (self-check refused the first form)",
        WYS1.exists() and "refusing to report" in WYS1.read_text())
    print(f"  window max |y share|: hub {wh:.5f} (t=11 s); mid {wm:.5f} (t=11 s)")
    print(f"  hub reads under 0.003 from t={hub_under} s; mid from t={mid_under} s")
    print(f"  relax sampled peak |y| = {r_peak:.5f} (t=2 s); extension max 0.00217; t=200 reads 0.0002")
    print("  SCOPE FINDING: the unqualified bound does not hold over the window (max 0.0374).")
    print("  The bound holds over the extension series and from t=38 s onward.")
else:
    print("NOTE: instrument log not present at check time")

# ---------- verdict ----------
print()
if fails:
    print(f"{n} checks, {fails} FAIL")
    sys.exit(1)
print(f"{n} checks, 0 fail")
print("ALL_CHECKS_PASS")
