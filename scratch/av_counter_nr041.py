#!/usr/bin/env python3
# av_counter_nr041.py — aero counter-read of NR-041 (honest-window k sweep).
# Row under read: docs/reporting/numbers-register.md, "Derived row: NR-041".
# Reads only committed bytes: scripts/results/k_sweep_daisy_5kw.csv at blob
# d17d1377 (HEAD == adea1a3), plus src/ring_forces.jl at HEAD for the D4
# cap cross-read, plus the sweep script at adea1a3 for the span settings.
# Own arithmetic from the stored tokens, no receipt chains.
import subprocess, hashlib, sys

ok = True
def check(name, cond, detail=""):
    global ok
    print(f"[{'PASS' if cond else 'FAIL'}] {name}" + (f" | {detail}" if detail else ""))
    ok = ok and bool(cond)

def git(*a):
    return subprocess.run(["git", *a], capture_output=True, text=True, check=True).stdout.strip()

print("== av_counter_nr041 / aero counter-read of NR-041 ==")

# -- pins ------------------------------------------------------------------
blob = git("hash-object", "scripts/results/k_sweep_daisy_5kw.csv")
head = git("rev-parse", "HEAD:scripts/results/k_sweep_daisy_5kw.csv")
land = git("rev-parse", "adea1a3:scripts/results/k_sweep_daisy_5kw.csv")
check("blob pins (HEAD, adea1a3 = d17d1377)", blob == head == land == "d17d1377b191dde5b44df7f5534d0cdc4c48d0f3",
      f"head={blob[:8]} land={land[:8]}")

sha = hashlib.sha256(open("scripts/results/k_sweep_daisy_5kw.csv", "rb").read()).hexdigest()
check("sha256 vs draft manifest pin", sha == "95e37fd5afade812c9c7b5af031433a052daf70713bbb686ee3f4d0fc50beb4a", sha[:16])

date = git("log", "-1", "--format=%ci", "adea1a3")
check("landing date", date.startswith("2026-08-22 14:11:49 +0100"), date)

# -- the ten pairs ---------------------------------------------------------
rows = []
with open("scripts/results/k_sweep_daisy_5kw.csv") as fh:
    header = fh.readline().strip()
    for line in fh:
        if line.strip():
            rows.append([t.strip() for t in line.split(",")])
check("column line + ten data rows", header == "k,status,P_mean,P_end,omega_eq,omega_final,FoS_min,T_lift,wall_s" and len(rows) == 10,
      header)

ks = [0.5, 1.0, 1.5, 1.94, 2.24, 3.0, 4.0, 5.39, 7.0, 9.0]
quote2 = [3.49, 5.45, 6.78, 7.56, 8.00, 8.89, 8.95, 8.95, 8.95, 8.95]

print("\n== per-row read (full stored precision) ==")
for r, k_exp, q in zip(rows, ks, quote2):
    k, status, p_mean, p_end, w_eq, w_fin = float(r[0]), r[1], float(r[2]), float(r[3]), float(r[4]), float(r[5])
    print(f"k={k:>5} {status:>6}  P_mean={p_mean!r:>20}  P_end={p_end!r:>20}  q2={round(p_mean,2):.2f}")
    check(f"  k={k} key", k == k_exp)
    check(f"  k={k} quote at 2 dp = {q}", abs(round(p_mean, 2) - q) < 1e-9)

statuses = [r[1] for r in rows]
check("reject only at k=0.5", statuses == ["reject"] + ["ok"] * 9)
pm05 = float(rows[0][2])
check("k=0.5 under the 5.0 kW bar", pm05 < 5.0, f"P_mean={pm05!r} (4 dp {pm05:.4f})")

# -- plateau band ----------------------------------------------------------
plateau = [float(r[2]) for r in rows[6:10]]
band_lo, band_hi = min(plateau), max(plateau)
check("plateau band 8.9475 to 8.9511 at 4 dp", f"{band_lo:.4f}" == "8.9475" and f"{band_hi:.4f}" == "8.9511",
      f"{band_lo:.4f} .. {band_hi:.4f}")

# -- P_mean vs P_end agreement ---------------------------------------------
diffs = [abs(float(r[2]) - float(r[3])) / float(r[2]) * 100.0 for r in rows]
check("P_mean vs P_end below 0.5 per cent at every row", all(d < 0.5 for d in diffs),
      f"spread {min(diffs):.2f} to {max(diffs):.2f} per cent")

# -- clamp cross-reads -----------------------------------------------------
print("\n== clamp read, plateau rows ==")
taus = []
for r in rows[6:10]:
    tau = float(r[3]) * 1000.0 / float(r[5])
    taus.append(tau)
    print(f"k={float(r[0]):>5}  P_end*1000/omega_final = {tau!r} N.m")
check("plateau rows read about 625.0 (band 624.76 to 625.08)",
      all(abs(t - 625.0) < 0.3 for t in taus), f"band {min(taus):.2f} to {max(taus):.2f}")
era_form = 2500.0 * (5000.0 / 1e4) ** 2
check("era cap form 2500 x (P/1e4)^2 at 5 kW = 625.0", era_form == 625.0, f"{era_form!r}")
line54 = open("src/ring_forces.jl").read().splitlines()[53]
check("D4 law line reads as expected", "generator_torque_cap(p::SystemParams)" in line54
      and "(22.65 / 300.0^1.5) * p.p_rated_w^1.5" in line54, line54.strip())
d4 = (22.65 / 300.0 ** 1.5) * 5000.0 ** 1.5
check("D4 current tip law at 5 kW = 1541.137296501083 (printed form)", abs(d4 - 1541.137296501083) < 1e-9,
      f"{d4!r} (src/ring_forces.jl:54)")

# -- omega_eq column --------------------------------------------------------
check("omega_eq reads zero on all ten rows", all(float(r[4]) == 0.0 for r in rows))

# -- closed form in the sweep script header ---------------------------------
x = (5.0 / 1.5) ** 2.5
check("header closed form does not evaluate (3.550, 8.520 not 2.24, 5.39)",
      abs(0.175 * x - 3.550) < 5e-3 and abs(0.42 * x - 8.520) < 5e-3,
      f"0.175*x={0.175*x:.3f}  0.42*x={0.42*x:.3f}")

# -- span settings at adea1a3 ----------------------------------------------
script = git("show", "adea1a3:scripts/sweep_k_mppt_5kw.jl")
check("span settings at adea1a3 (relax 10 + window 40, tail5 35-40, LENGTH 18.8)",
      "relax 10 + window 40" in script and "tail5 at 35-40 s" in script
      and "const WINDOW_S = 40.0" in script and "const LENGTH = 18.8" in script)

print(f"\nVERDICT: {'no material discrepancy; NR-041 stands as signed' if ok else 'DISCREPANCY FOUND'}")
sys.exit(0 if ok else 1)
