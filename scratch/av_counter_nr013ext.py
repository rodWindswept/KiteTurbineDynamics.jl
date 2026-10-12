#!/usr/bin/env python3
# av_counter_nr013ext.py — aero counter-read of the NR-013 extension block.
# Row under read: docs/reporting/numbers-register.md, "NR-013 extension:
# lane-3 strain annotations". Reads only committed bytes: the two extracts
# at blobs ff1ca1b2 / bb0a4720 (21e941d == HEAD), the F3 draft manifests in
# scratch/, and the local diag log for the per-step cross-read. Own
# arithmetic from the stored tokens, no receipt chains.
import subprocess, hashlib, statistics, json, sys, os

ok = True
def check(name, cond, detail=""):
    global ok
    print(f"[{'PASS' if cond else 'FAIL'}] {name}" + (f" | {detail}" if detail else ""))
    ok = ok and bool(cond)

def git(*a):
    return subprocess.run(["git", *a], capture_output=True, text=True, check=True).stdout.strip()

EXT = "docs/reporting/figures/eval-timeline-extract"
print("== av_counter_nr013ext / aero counter-read of the NR-013 extension ==")

# -- pins ------------------------------------------------------------------
warm_blob = git("rev-parse", "21e941d:" + EXT + "/extract-eval-timeline-warm.csv")
warm_head = git("rev-parse", "HEAD:" + EXT + "/extract-eval-timeline-warm.csv")
rul_blob = git("rev-parse", "21e941d:" + EXT + "/extract-eval-timeline-warm-rulingmode.csv")
rul_head = git("rev-parse", "HEAD:" + EXT + "/extract-eval-timeline-warm-rulingmode.csv")
check("blob pins (21e941d == HEAD)",
      warm_blob == warm_head == "ff1ca1b2a809b2d4231d5947765d48ee5aed0496"
      and rul_blob == rul_head == "bb0a47202d7e1086000ef494c721c53c782fea23",
      f"warm {warm_blob[:8]} ruling {rul_blob[:8]}")

def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()

warm_sha = sha(EXT + "/extract-eval-timeline-warm.csv")
rul_sha = sha(EXT + "/extract-eval-timeline-warm-rulingmode.csv")
cold_sha = sha(EXT + "/extract-eval-timeline-cold.csv")
for mf in ("scratch/fig_f3_draft/manifest.json", "scratch/fig_f3_draft_b/manifest.json"):
    pins = json.load(open(mf))["inputs"]
    check(f"manifest pins ({os.path.basename(os.path.dirname(mf))})",
          pins.get("extract-eval-timeline-warm.csv") == warm_sha
          and pins.get("extract-eval-timeline-warm-rulingmode.csv") == rul_sha
          and pins.get("extract-eval-timeline-cold.csv") == cold_sha)

# -- warm leg ---------------------------------------------------------------
rows = [l.split(",") for l in open(EXT + "/extract-eval-timeline-warm.csv").read().splitlines()
        if l and not l.startswith("#") and not l.startswith("t,")]
check("warm: 98 data rows", len(rows) == 98, str(len(rows)))
last = rows[-1]
check("warm: last row t = 2.841 ms, strain 1.00081, latch 1",
      last[0] == "0.002841" and float(last[5]) == 1.000810120 and last[6] == "1",
      f"t={last[0]} strain={last[5]} latch={last[6]}")
first_over = next((i for i, r in enumerate(rows) if float(r[5]) > 1.0), None)
check("warm: first crossing at step 97, strain 1.00028",
      first_over is not None and first_over + 1 == 97 and float(rows[first_over][5]) == 1.000277041,
      f"step {None if first_over is None else first_over + 1} strain {None if first_over is None else rows[first_over][5]}")
check("warm: latch only on the last row", [r[6] for r in rows].count("1") == 1)

# -- ruling leg -------------------------------------------------------------
rrows = [l.split(",") for l in open(EXT + "/extract-eval-timeline-warm-rulingmode.csv").read().splitlines()
         if l and not l.startswith("#") and not l.startswith("t,")]
check("ruling: 1823 data rows", len(rrows) == 1823, str(len(rrows)))
last_t = float(rrows[-1][0])
check("ruling: completes 50 s", abs(last_t - 50.0) < 0.01, f"last t = {last_t!r}")
check("ruling: any_broken false throughout", all(r[5] == "0" for r in rrows))

grid = [(float(r[0]), float(r[4])) for r in rrows]
t_gmax, s_gmax = max(grid, key=lambda p: p[1])
check("ruling: grid max 1.44798 at t = 5.798 ms",
      round(s_gmax, 5) == 1.44798 and abs(t_gmax - 0.005798) < 5e-6,
      f"{s_gmax!r} at t={t_gmax!r}")
past60 = [s for t, s in grid if t > 0.06]
check("ruling: past 60 ms nothing exceeds 0.677081", abs(max(past60) - 0.677081) < 1e-6, f"max = {max(past60)!r}")

win = [r for r in rrows if float(r[0]) >= 10.0]
mw_gnd = statistics.fmean(float(r[1]) for r in win)
mw_p = statistics.fmean(float(r[3]) for r in win)
mw_st = max(float(r[4]) for r in win)
check("ruling: window mean omega_gnd = 12.639282", abs(mw_gnd - 12.639282) < 1e-6, f"{mw_gnd!r}")
check("ruling: window mean P = 4.958894 kW", abs(mw_p - 4.958894) < 1e-6, f"{mw_p!r}")
check("ruling: window strain max 0.449417", abs(mw_st - 0.449417) < 1e-6, f"{mw_st!r}")

stamp = open(EXT + "/extract-eval-timeline-warm-rulingmode.csv").read().splitlines()[:8]
check("ruling: stamp carries the gate placement (off <10, on >=10) and the condition note",
      any("gate OFF for t < 10 s, ON for t >= 10 s" in l for l in stamp)
      and any("not the as-coded machine" in l for l in stamp))

# -- per-step cross-read and trip-segment note ------------------------------
log = open(".julia_depot/logs/av_f3_warm_diag2.log").read()
check("diag log: per-step peak 1.44819 at 5.740 ms",
      "true early per-step peak (s<=2000) = 1.44819 at t=0.005740" in log)
readme = open(EXT + "/README.md").read()
check("README: trip segment note (S4 line 3)", "S4 line 3" in readme)

print(f"\nVERDICT: {'no material discrepancy; the block stands as signed' if ok else 'DISCREPANCY FOUND'}")
sys.exit(0 if ok else 1)
