#!/usr/bin/env python3
"""sv_nr059_scope_check.py — the scope-amend check for NR-059 (the direction bound).

Seat: science-validator. Companion to the amend that scopes the NR-059 direction
bullet, on the aero counter-read (receipt:
docs/reporting/room-responses/aero-validator-2026-10-16-nr059-counterread.md).

Verifies, from the committed counter-read log and the committed probe log:
  A. The instrument state: gates, anchors, the omega match, the sentinel.
  B. The reproduction: both window perp series match the committed log byte for byte.
  C. The scope numbers: the relax peak, the window t=11 reads, the crossing points,
     the extension peak and the t=200 read.
  D. The finding: the whole-run bound reads false, so the amend's scope is the true one.

Run from the repo root:  python3 scratch/sv_nr059_scope_check.py
Exit non-zero on any fail. Log: scratch/sv_nr059_scope_check.log
"""

import re
import sys
from pathlib import Path

ROOT = Path(".")
AVLOG = ROOT / "scratch" / "av_bow_probe.log"          # the committed read
YSLOG = ROOT / "scratch" / "av_nr059_window_yshare.log"  # the counter-read instrument

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


ys = YSLOG.read_text()
av = AVLOG.read_text()

# ---------- A. instrument state ----------
chk("sentinel WINDOW_YSHARE_DONE present", "WINDOW_YSHARE_DONE" in ys)
chk("bench gates read true",
    bool(re.search(r"bench gates vs recorded: fitness true \(27\.3635412663488\)  omega_eq true  P_end true  twist true  FoS true", ys)))
chk("protocol gates read true", "protocol gates vs phase 1: settle-omega true  P_end true  twist true  FoS true" in ys)
m = re.search(r"omega_end vs committed: \|delta\| = ([0-9.e+-]+)   exact match = (true|false)", ys)
chk("omega_end matches the committed read to 8.882e-15",
    m is not None and float(m.group(1)) < 1e-12 and m.group(2) == "true", str(m.groups() if m else None))
chk("ANCHORS_OK = true", "ANCHORS_OK = true" in ys)

# ---------- B. series reproduction (instrument vs committed log) ----------
def series(text, label):
    mm = re.search(re.escape(label) + r"\n?\s*\[([^\]]+)\]", text)
    if not mm:
        mm = re.search(re.escape(label) + r": \[([^\]]+)\]", text)
    return mm.group(1) if mm else None

for label in ("window ring6 series:", "window ring5 series:"):
    a = series(av, label)
    b = series(ys, label)
    chk(f"{label} reproduces byte for byte", a is not None and a == b, "mismatch")

# ---------- C. the scope numbers ----------
relax = [(float(t), float(y)) for t, p, y in re.findall(r"t=\s*([0-9.]+)\s+perp=([0-9.]+)\s+y_frac=([+-][0-9.]+)", ys)]
pk = max(relax, key=lambda r: abs(r[1]))
chk("relax sampled peak reads 0.23586 at t=2 s", pk[0] == 2.0 and f"{abs(pk[1]):.5f}" == "0.23586", str(pk))

mh = re.search(r"hub_y: \[([^\]]+)\]", ys)
mm = re.search(r"mid_y: \[([^\]]+)\]", ys)
hub = [float(v) for v in mh.group(1).split(",")] if mh else []
mid = [float(v) for v in mm.group(1).split(",")] if mm else []
chk("window series carry 40 samples each", len(hub) == 40 and len(mid) == 40, f"{len(hub)}/{len(mid)}")
chk("window reads 0.0374 (hub) and 0.03734 (mid) at t=11 s",
    f"{hub[0]:.5f}" == "0.03740" and f"{mid[0]:.5f}" == "0.03734", f"{hub[0]}/{mid[0]}")

hub_t = {11 + i: v for i, v in enumerate(hub)}
mid_t = {11 + i: v for i, v in enumerate(mid)}
chk("hub reads under 0.003 for every sample from t=37 s onward",
    all(abs(v) < 0.003 for t, v in hub_t.items() if t >= 37))
chk("hub reads not under 0.003 at t=36 s (the crossing)", abs(hub_t[36]) >= 0.003, str(hub_t[36]))
chk("midpoint reads under 0.003 for every sample from t=38 s onward",
    all(abs(v) < 0.003 for t, v in mid_t.items() if t >= 38))
chk("midpoint reads not under 0.003 at t=37 s (the crossing)", abs(mid_t[37]) >= 0.003, str(mid_t[37]))
print(f"  crossing: hub first <0.003 at t=37 s ({hub_t[37]:.5f}); mid first <0.003 at t=38 s ({mid_t[38]:.5f})")

m = re.search(r"WINDOW \|y_frac\| max: hub ([0-9.]+) ; mid ([0-9.]+)  \(n=(\d+)\)", ys)
chk("instrument summary: hub 0.03740 / mid 0.03734 over n=40",
    m is not None and m.groups() == ("0.03740", "0.03734", "40"), str(m.groups() if m else None))

# extension peak and the t=200 read, from the committed log
ext = [float(m) for m in re.findall(r"^\s+\d+\s+[0-9.]+\s+[0-9.]+\s+[0-9.]+\s+([+-][0-9.]+)$", av, re.M)]
chk("extension series carries 29 rows", len(ext) == 29, str(len(ext)))
chk("extension peak reads 0.00217", f"{max(abs(v) for v in ext):.5f}" == "0.00217", f"{max(abs(v) for v in ext)!r}")
m = re.search(r"t=200 down_frac [0-9.]+ \(y ([+-][0-9.]+)\)", av)
chk("t=200 sideways read is 0.0002", m is not None and m.group(1) == "+0.0002", str(m.group(1) if m else None))

# ---------- D. the finding ----------
chk("the whole-run bound reads false (the amend's scope is the true one)",
    "WHOLE-RUN direction bound: window max 0.03740 plus extension max 0.00217 (committed log) under 0.003 = false" in ys)

# ---------- verdict ----------
print()
if fails:
    print(f"{n} checks, {fails} FAIL")
    sys.exit(1)
print(f"{n} checks, 0 fail")
print("ALL_CHECKS_PASS")
