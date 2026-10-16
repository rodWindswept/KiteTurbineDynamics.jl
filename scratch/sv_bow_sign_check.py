#!/usr/bin/env python3
"""sv_bow_sign_check.py — the register-sign check for NR-059 (the winner bow read).

Seat: science-validator. Companion to the sign of the aero seat's proposed
NR-059 row (receipt: docs/reporting/room-responses/aero-validator-2026-10-16-winner-bow-probe.md).

Verifies, from the committed log and this seat's re-run log:
  A. The repro: the re-run log reproduces the committed log line for line,
     apart from the run wall times and the git header (masked compare).
  B. The values: every figure the row and the receipt carry, at the log's
     5-decimal forms and at the row's 3-decimal quote forms.
  C. The bench gates, the direction, the September check and the surplus facts.
  D. The evidence pins (sha256) and the run-state footer of the re-run.

Run from the repo root:  python3 scratch/sv_bow_sign_check.py
Exit non-zero on any fail. Log: scratch/sv_bow_sign_check.log
"""

import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(".")
AV = ROOT / "scratch" / "av_bow_probe.log"          # committed read (aero seat, at 4e9c6bd)
SV = ROOT / "scratch" / "sv_bow_probe_recheck.log"  # this seat's re-run (at 650fa49)
PROBE = ROOT / "scratch" / "av_bow_probe.jl"

PROBE_SHA = "24a1601718dcb2d8536872ca975b6a823fed640e72686486c434fdc6216c73a4"
LOG_SHA = "eacc0ce3acbcdeb66b6dd9db975b177ceb401a2929bee2c40fd258e22f2bf987"

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


def grab(pat, text, flags=re.M):
    m = re.search(pat, text, flags)
    return m.groups() if m else None


# ---------- load ----------
av = AV.read_text().splitlines()
sv_all = SV.read_text().splitlines()

chk("committed log carries the sentinel", "AV_BOW_PROBE_DONE" in av, "sentinel missing")
chk("re-run log carries the sentinel", "AV_BOW_PROBE_DONE" in sv_all, "sentinel missing")
if "AV_BOW_PROBE_DONE" not in sv_all:
    print("\nSTOP: no re-run sentinel")
    sys.exit(1)
cut = sv_all.index("AV_BOW_PROBE_DONE") + 1
footer = sv_all[cut:]

# locate the probe section start in the re-run (precompile noise goes to a prefix note)
idx0 = next((i for i, l in enumerate(sv_all) if l.startswith("=== av_bow_probe.jl")), None)
chk("re-run section start found", idx0 is not None, "header line missing")
if idx0 is None:
    print("\nSTOP: no re-run header")
    sys.exit(1)
if idx0:
    print(f"  NOTE: {idx0} prefix lines before the probe section (load noise)")
sv = sv_all[idx0:cut]

chk("committed log reads 127 lines", len(av) == 127, f"reads {len(av)}")
chk("re-run probe section matches the committed length", len(sv) == len(av), f"{len(sv)} vs {len(av)}")

# ---------- A. masked line-for-line equality ----------
def mask(line):
    line = re.sub(r"wall = [0-9.]+ s", "wall = X s", line)
    line = re.sub(r"git=[0-9a-f]+", "git=X", line)
    return line


raw_diff = [i + 1 for i, (a, b) in enumerate(zip(av, sv)) if a != b]
norm_diff = [i + 1 for i, (a, b) in enumerate(zip(av, sv)) if mask(a) != mask(b)]
chk("masked line-for-line equality over the whole probe section", not norm_diff,
    f"first diffs at lines {norm_diff[:5]}")
chk("raw diffs sit only on the git header and the four wall-time lines",
    set(raw_diff) <= {1, 7, 27, 45, 75}, f"raw diffs {raw_diff}")
print(f"  raw differing lines: {raw_diff}")
print(f"  lines compared: {len(av)}; identical after masking: {len(av) - len(norm_diff)}")

text = "\n".join(sv)

# ---------- B. the values (log 5-dp forms) ----------
g = grab(r"SETTLE profile max = ([0-9.]+) m at ring (\d+) \(s_axial ([0-9.]+)\)", text)
chk("settle profile max = 0.00241 at ring 6", g == ("0.00241", "6", "18.714"), str(g))

g = grab(r"SETTLE hub perp \(ring (\d+)\) = ([0-9.]+) m ; mid-span ring (\d+) \(s_axial ([0-9.]+)\) perp = ([0-9.]+) m", text)
chk("settle hub (ring 6) 0.00241 / mid-span (ring 5, s_axial 9.376) 0.00160",
    g == ("6", "0.00241", "5", "9.376", "0.00160"), str(g))

g5 = grab(r"^\s+5\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s+([+-][0-9.]+)$", text)
g6 = grab(r"^\s+6\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s+([+-][0-9.]+)\s+<- MAIN ROTOR$", text)
chk("window table ring 5: settle .00160 mean .22288 min .10531 max .31005",
    g5 == ("0.00160", "0.22288", "0.10531", "0.31005", "-0.22127"), str(g5))
chk("window table ring 6: settle .00241 mean .44098 min .20862 max .61302",
    g6 == ("0.00241", "0.44098", "0.20862", "0.61302", "-0.43857"), str(g6))

g = grab(r"window hub perp \(ring 6\): min ([0-9.]+)  mean ([0-9.]+)  max ([0-9.]+) m", text)
chk("window hub line min/mean/max", g == ("0.20862", "0.44098", "0.61302"), str(g))
g = grab(r"window mid-span ring 5 perp: min ([0-9.]+)  mean ([0-9.]+)  max ([0-9.]+) m", text)
chk("window mid-span line min/mean/max", g == ("0.10531", "0.22288", "0.31005"), str(g))
g = grab(r"window profile max: min ([0-9.]+) m, mean ([0-9.]+) m, max ([0-9.]+) m \(at t=([0-9.]+) s\)", text)
chk("window profile max envelope (max at t=50 s)", g == ("0.20862", "0.44098", "0.61302", "50"), str(g))

g = grab(r"^\s+195\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s+([+-][0-9.]+)$", text)
chk("ext table t=195: hub 0.83331 mid 0.42202", g is not None and g[:3] == ("13.3864", "0.83331", "0.42202"), str(g))
g = grab(r"terminal: hub perp ([0-9.]+) m at t=195 \(last 5 s increment ([+-][0-9.]+) m\); mid-span ([0-9.]+) m", text)
chk("terminal line: hub .83331, increment +.00053, mid .42202",
    g == ("0.83331", "+0.00053", "0.42202"), str(g))
g = grab(r"raw: hub at t=200 = \[[^\]]+\]  perp = ([0-9.]+)", text)
chk("raw hub read at t=200 = 0.833774", g == ("0.833774",), str(g))

g = grab(r"max \|settle - window_mean\| = ([0-9.]+) m at ring (\d+)", text)
chk("largest deviation 0.43857 m at ring 6", g == ("0.43857", "6"), str(g))
dev_re = abs(0.00241 - 0.44098)
chk("deviation recomputes: |0.00241 - 0.44098| -> 0.43857", f"{dev_re:.5f}" == "0.43857", f"{dev_re!r}")

# ---------- C. direction, bench, integrity, census ----------
g = grab(r"direction   : settle down_frac ([0-9.]+) \(y ([+-][0-9.]+)\); t=200 down_frac ([0-9.]+) \(y ([+-][0-9.]+)\)", text)
chk("direction: settle down_frac .9999, t=200 down_frac 1.0000",
    g is not None and g[0] == "0.9999" and g[2] == "1.0000", str(g))

ext_block = text.split("── phase 4: extension run", 1)[1].split("raw: hub at t=200", 1)[0]
yshares = [float(m) for m in re.findall(r"^\s+\d+\s+[0-9.]+\s+[0-9.]+\s+[0-9.]+\s+([+-][0-9.]+)$", ext_block, re.M)]
chk("extension series carries 29 rows", len(yshares) == 29, f"{len(yshares)}")
chk("sideways share under 0.003 over the extension series", bool(yshares) and max(abs(v) for v in yshares) < 0.003,
    f"max |y| {max(abs(v) for v in yshares) if yshares else None}")
if yshares:
    print(f"  extension max |y share| = {max(abs(v) for v in yshares):.5f} over {len(yshares)} samples")

g = grab(r"bench gates vs recorded: fitness (true) \(([0-9.]+)\)  omega_eq (true)  P_end (true)  twist (true)  FoS (true)", text)
chk("bench gates all true (fitness 27.3635412663488)",
    g == ("true", "27.3635412663488", "true", "true", "true", "true"), str(g))
g = grab(r"protocol gates vs phase 1: settle-omega (true)  P_end (true)  twist (true)  FoS (true)", text)
chk("protocol gates all true", g == ("true", "true", "true", "true"), str(g))
chk("integrity line true", "integrity: settle arrays unchanged after both runs = true" in text)
chk("settle omega reads the recorded value",
    grab(r"omega_settle = ([0-9.]+)   \(recorded ([0-9.]+)\)", text) == ("10.169820334285198", "10.169820334285198"))
chk("any_broken false in both runs", text.count("any_broken = false") == 2)
chk("window samples 40 / extension samples 29",
    "samples = 40" in text and "samples = 29" in text)
chk("max-bow ring is the hub in all 40 samples", "max-bow ring across samples: Dict(6 => 40)" in text)
ts = re.search(r"window sample t \(s\): \[([^\]]+)\]", text)
ts_n = len(ts.group(1).split(",")) if ts else 0
chk("window sample times read 40 entries", ts_n == 40, f"{ts_n}")

# mid-span identity: ring 5 is the nearest ring to the axial midpoint
rows = re.findall(r"^\s+(\d)\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s+([+-][0-9.]+)\s+([0-9.]+)(?:\s+<- MAIN ROTOR)?\s*$", text, re.M)
sax = {int(r[0]): float(r[1]) for r in rows if int(r[0]) <= 6}
perp = {int(r[0]): float(r[2]) for r in rows if int(r[0]) <= 6}
if len(sax) == 6:
    mid = (sax[1] + sax[6]) / 2
    imid = min(sax, key=lambda k: abs(sax[k] - mid))
    chk("mid-span ring is ring 5 (nearest to the axial midpoint)", imid == 5 and abs(sax[5] - mid) < abs(sax[4] - mid),
        f"mid {mid:.4f} ring5 {sax[5]} ring4 {sax[4]}")
else:
    chk("settle table carries six rings", False, f"parsed {sorted(sax)}")

# ratio forms the supply and receipt carry
r_50 = 0.31005 / 0.61302
r_195 = 0.42202 / 0.83331
chk("mid/hub ratio reads 0.5058 at t=50 s", f"{r_50:.4f}" == "0.5058", f"{r_50!r}")
chk("mid/hub ratio reads 0.5064 at t=195 s", f"{r_195:.4f}" == "0.5064", f"{r_195!r}")

# founder line: every midpoint state below 0.5 m
chk("founder line met: midpoint below 0.5 m in every state", 0.00160 < 0.5 and 0.31005 < 0.5 and 0.42202 < 0.5)

# ---------- the row's 3-dp quote forms ----------
forms = [(0.00160, "0.002"), (0.10531, "0.105"), (0.31005, "0.310"),
         (0.00241, "0.002"), (0.20862, "0.209"), (0.61302, "0.613"),
         (0.42202, "0.422"), (0.83331, "0.833")]
bad = [(v, q, f"{v:.3f}") for v, q in forms if f"{v:.3f}" != q]
chk("every row quote form re-derives at 3 decimals from the 5-decimal log form", not bad, str(bad))

# ---------- D. pins and footer ----------
chk("probe sha256 equals the supply pin", sha256(PROBE) == PROBE_SHA, sha256(PROBE))
chk("committed log sha256 equals the supply pin", sha256(AV) == LOG_SHA, sha256(AV))
foot = "\n".join(footer)
chk("footer: worktree HEAD = 650fa49…", "worktree HEAD = 650fa49cdfd2e4736d3dd05577e9a9fcbdc7908f" in foot, foot[:200])
chk("footer: src drift 4e9c6bd..HEAD = 0", "src drift 4e9c6bd..HEAD = 0" in foot)
chk("footer: PROBE_RC=0", "PROBE_RC=0" in foot)
chk("footer: probe sha256 line present", PROBE_SHA in foot)

# ---------- verdict ----------
print()
if fails:
    print(f"{n} checks, {fails} FAIL")
    sys.exit(1)
print(f"{n} checks, 0 fail")
print("ALL_CHECKS_PASS")
