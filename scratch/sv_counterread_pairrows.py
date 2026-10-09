#!/usr/bin/env python3
# sv_counterread_pairrows.py — science counter-read of NR-021 .. NR-026 against the
# pair-extract records (docs/reporting/figures/pair-extract/).
# This read works from committed records only. It runs no simulator and reads no
# telemetry. Writes: scratch/sv_counterread_pairrows.log
# Run: python3 scratch/sv_counterread_pairrows.py
import math
import os
import re
import subprocess
import hashlib

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSVP = os.path.join(REPO, "docs/reporting/figures/pair-extract/extract-winner-operating-point.csv")
LOGP = os.path.join(REPO, "docs/reporting/figures/pair-extract/extract-winner-operating-point.log")
OUTP = os.path.join(REPO, "scratch/sv_counterread_pairrows.log")

out = []


def say(s=""):
    out.append(s)
    print(s)


def git(*a):
    return subprocess.run(["git", "-C", REPO, *a], capture_output=True, text=True).stdout.strip()


def is_ancestor(rev):
    return subprocess.run(["git", "-C", REPO, "merge-base", "--is-ancestor", rev, "HEAD"]).returncode == 0


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(65536), b""):
            h.update(b)
    return h.hexdigest()


say("== science counter-read: NR-021 .. NR-026 (pair-extract) — science-validator, 2026-10-09 ==")
say("basis: register block a443e26 | computing commit f8114be (csv header)")
say("HEAD: " + git("rev-parse", "HEAD"))
say("f8114be ancestor of HEAD: " + ("yes" if is_ancestor("f8114be") else "NO"))
say("a09ecf6 (adaptive dt landing) ancestor of HEAD: " + ("yes" if is_ancestor("a09ecf6") else "NO"))
say("src/ diff f8114be..HEAD: " + (git("diff", "--stat", "f8114be..HEAD", "--", "src/") or "(empty)"))
say("plans doc 2026-08-24 build-geometry audit exists: " +
    str(os.path.exists(os.path.join(REPO, "docs/plans/2026-08-24-build-geometry-audit.md"))))
say("csv sha256: " + sha256(CSVP))
say("log sha256: " + sha256(LOGP))
say("")

raw = open(CSVP).read().splitlines()
data = [l.split(",") for l in raw if l.strip() and not l.startswith("#")]
S = {r[1]: r for r in data[1:] if r[0] == "segment"}
R = {r[1]: r for r in data[1:] if r[0] == "ring"}
logtxt = open(LOGP).read()

hdr_commit = next(l for l in raw if "computing commit" in l).split(":", 1)[1].strip()
say("csv computing commit: %s | equals f8114be full sha: %s" %
    (hdr_commit, hdr_commit == "f8114be60e6c1ff842b90d2267d588ddc40e0098"))
say("")

# ---------- NR-021 : ring block ----------
say("-- NR-021 ring block (register cross-read, A1 identity, FoS inverse) --")
C21 = {
    "R2": ("0.03323714455441065", "0.033223570205929", "1.3574348481652112e-5", "30.086820435580936"),
    "R3": ("0.033548608446737266", "0.03354237801917142", "6.230427565848155e-6", "29.80749563987516"),
    "R4": ("0.028380221733419368", "0.028374815022862057", "5.40671055731162e-6", "35.23580644975869"),
    "R5": ("3.058346201008972e-6", "0.0", "3.058346201008972e-6", "326974.1011237028"),
    "R6": ("0.06652238395895148", "0.06652164721153939", "7.36747412096439e-7", "15.032534020684876"),
}
for k, (mx, ua, ub, fos) in C21.items():
    r = R[k]
    xr = (r[12] == mx and r[13] == ua and r[14] == ub and r[15] == fos)
    a1 = float(r[13]) + float(r[14]) == float(r[12])
    finv = 1.0 / float(r[12]) == float(r[15])
    say("%s: cross-read %s | axial+bending = max_util bit-exact: %s | 1/max_util = fos bit-exact: %s" %
        (k, "OK" if xr else "MISMATCH", a1, finv))

stations = ["0.0", "2.3182841987165674", "4.636939712683201", "6.9559610374822345",
            "9.27534680414777", "18.600867750952748"]
stl = next(l for l in logtxt.splitlines() if l.startswith("ring stations"))
say("stations line carries all six register values: " + str(all(s in stl for s in stations)))
say("")

# ---------- NR-022 : twist block ----------
say("-- NR-022 segment twist block --")


def dcrit_deg(ra, rb, lt):
    disc = (lt * lt - (ra + rb) ** 2) * (lt * lt - (ra - rb) ** 2)
    if disc < 0:
        return None
    c = (ra * ra + rb * rb - lt * lt + math.sqrt(disc)) / (2.0 * ra * rb)
    c = max(-1.0, min(1.0, c))
    return math.degrees(math.acos(c))


C22_da = {"S1": "33.94561934829036", "S2": "33.811870056223555", "S3": "33.67952027817454",
          "S4": "33.54707806507812", "S5": "22.821871326820364"}
C22_dc = {"S1": "98.85908296054023", "S2": "98.85908296054023", "S3": "98.85908296054023",
          "S5": "92.64281134151318"}
for s in ("S1", "S2", "S3", "S4", "S5"):
    r = S[s]
    ra, rb, lt = float(r[3]), float(r[4]), float(r[5])
    da, dc, tw, hl = r[8], r[7], r[9], r[6]
    rec = dcrit_deg(ra, rb, lt)
    exact = (rec == float(dc))
    ulps = (rec - float(dc)) / math.ulp(float(dc)) if rec is not None else None
    say("%s: abs_dalpha cross %s | has_limit %s | emitted twist equals raw read: %s" %
        (s, "OK" if da == C22_da[s] else "MISMATCH", hl, tw == da))
    say("     dcrit stored %s | recompute %r | bit-exact: %s | ulp delta: %s" %
        (dc, rec, exact, ("%.2f" % ulps) if ulps is not None and not exact else "0" if exact else "n/a"))
    if s in C22_dc:
        say("     register group value %s vs stored %s: %s" %
            (C22_dc[s], dc, "match" if C22_dc[s] == dc else "DIFFERS"))
    else:
        note = float("98.85908296054023") - float(dc)
        say("     NR-022 note: stored S4 dcrit vs the row group value; delta = %r deg" % note)
say("")

# ---------- NR-023 : torque pair ----------
say("-- NR-023 segment torque pair --")
aux = {}
for m in re.finditer(r"S(\d) \| .*?T_sum=([0-9.eE+-]+), L_ax=([0-9.eE+-]+)", logtxt):
    aux["S" + m.group(1)] = (float(m.group(2)), float(m.group(3)))
C23_t = {"S1": "396.791634149159", "S2": "397.1554424859068", "S3": "397.45360112890063",
         "S4": "397.68800908436924", "S5": "397.1777954649229"}
C23_c = {"S1": "805.0097155967861", "S2": "808.6780945063998", "S3": "812.213802301376",
         "S4": "815.650844050359", "S5": "1069.9324759682652"}
for s in ("S1", "S2", "S3", "S4", "S5"):
    r = S[s]
    ra, rb, lt = float(r[3]), float(r[4]), float(r[5])
    ts, lax = aux[s]
    F = ts * lax / max(lt, 1e-9)
    P = lt * lt - (ra + rb) ** 2
    Q = lt * lt - (ra - rb) ** 2
    cap = F * (math.sqrt(Q) - math.sqrt(max(P, 0.0))) / 2.0
    say("%s: tau cross %s | capacity stored %s vs recompute %r bit-exact: %s | Case A (P>0): %s" %
        (s, "OK" if r[10] == C23_t[s] else "MISMATCH", r[11], cap, cap == float(r[11]), P > 0))
say("")

# ---------- NR-024 : step law ----------
say("-- NR-024 step law --")
rec_dt = 2.8987873697672758e-5
seen = []
for s in ("S1", "S2", "S3", "S4", "S5"):
    lt = float(S[s][5])
    if lt in seen:
        continue
    seen.append(lt)
    Lmin = lt / 4.0
    d = min(4e-5, 4e-5 * math.sqrt(Lmin / 0.5) / 1.5)
    say("candidate chord %r -> Lmin %r -> dt %r | equals recorded dt: %s" % (lt, Lmin, d, d == rec_dt))
x = 50.0 / rec_dt
nt = round(x)
say("50/dt = %r | round -> %d | recorded total_n 1724859 | match: %s" % (x, nt, nt == 1724859))
tf = 1724859 * rec_dt
say("naive s*dt product: %r (the runner clock is accumulated, not multiplied)" % tf)
acc = 0.0
for _ in range(1724859):
    acc += rec_dt
say("accumulated clock after 1724859 steps: %r | log t 49.99999483862295 | bit-exact: %s" %
    (acc, acc == 49.99999483862295))
say("settle horizon: 150000 x dt = %r s | nominal 150000 x 4e-5 = %r s" % (150000 * rec_dt, 150000 * 4e-5))
say("")

# ---------- NR-025 : cold-start protocol source reads ----------
say("-- NR-025 source-line reads (working tree = f8114be for src/) --")


def check_line(path, n, needle):
    lines = open(os.path.join(REPO, path)).read().splitlines()
    got = lines[n - 1] if 0 < n <= len(lines) else ""
    ok = needle in got
    say("%s:%d carries %r: %s" % (path, n, needle, "yes" if ok else ("NO >>> " + got.strip())))
    return ok


check_line("src/objective_evaluator.jl", 774, "dt = stable_dt_for_system(sys, pc)")
check_line("src/objective_evaluator.jl", 840, "settle_to_operational_state(")
check_line("src/objective_evaluator.jl", 861, "~115")
check_line("src/objective_evaluator.jl", 865, "-60.0")
check_line("src/objective_evaluator.jl", 892, "total_n = round(Int, total_s / dt)")
check_line("src/objective_evaluator.jl", 989, "breaks_enabled=true")
check_line("src/initialization.jl", 2190, "n_op::Int=150_000")
check_line("src/initialization.jl", 2390, "n_op_use = n_op")
check_line("src/initialization.jl", 2389, "dt_op = stable_dt_for_system(sys, p)")
check_line("scripts/run_v13_5kw_masslift.jl", 157, "kickstart_s = 0.0")
check_line("scripts/run_v13_5kw_masslift.jl", 111, "FLAT at all wind speeds")
check_line("src/lift_kite.jl", 214, "include_lifter=false")
check_line("src/lift_kite.jl", 215, "F_vert = margin * m_airborne * g")
check_line("src/lift_kite.jl", 216, "T_ref = F_vert / sind(elevation_deg)")
say("")

# ---------- parity certificate ----------
par = [l for l in logtxt.splitlines() if "expected=" in l]
say("parity certificate fields: %d | all EXACT: %s" % (len(par), all(l.rstrip().endswith("EXACT") for l in par)))
say(next(l for l in logtxt.splitlines() if l.startswith("parity:")))
say("")

# ---------- NR-026 : lift margin identity ----------
say("-- NR-026 lift margin identity (closes on NR-018 and NR-010) --")
T = 1.5 * (25.69846825623688 - 5.0) * 9.81 / math.sin(math.radians(70.0))
say("1.5 x (25.69846825623688 - 5.0) x 9.81 / sin(70 deg) = %r | recorded 324.1250954336462 | bit-exact: %s" %
    (T, T == 324.1250954336462))

with open(OUTP, "w") as f:
    f.write("\n".join(out) + "\n")
print()
print("wrote " + OUTP)
