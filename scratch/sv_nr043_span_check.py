#!/usr/bin/env python3
# sv_nr043_span_check.py — science-validator seat, 2026-10-13.
# NR-043 signing gate: the winner blade span (island 3, main rotor).
# Reads committed bytes only. Checks, in order:
#   1. sha256 pins on the committed probe log and the figures decode log;
#   2. the probe log: span (built) = R_main - blade_hub_radius, bit-exact;
#      span (tip offset) = R_main - r_hub, bit-exact;
#   3. the 70/30 ring anchor closes both radii about r_hub;
#   4. the decode-variable derivation: span = 0.75 * r_rotor * blade_scale,
#      tip +0.7 * span, hub -0.3 * span; the line pin src/objective_v10.jl:374-376;
#   5. the quote forms: 3 dp 1.499, 2 dp 1.50, 4 dp 1.4994, 6 dp 1.499402;
#   6. cross-reads: the aero tip-reference receipt and the register NR-032 block
#      carry the same span and radii tokens; the figures decode log carries
#      the 6 dp radii;
#   7. the fresh re-run log equals the committed probe log, line for line.
# Exit 0 = every check passes. Log travels beside as sv_nr043_span_check.log.
import hashlib
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
FAILS = []


def chk(name, ok, detail=""):
    print(f"{'PASS' if ok else 'FAIL'}  {name}" + (f"  [{detail}]" if detail else ""))
    if not ok:
        FAILS.append(name)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def token(text, pattern, name):
    m = re.search(pattern, text)
    return float(m.group(1)) if m else None


probe_log = (REPO / "scratch/sv_probe_winner_areas.log").read_text()
decode_log = (REPO / "scratch/fig1_decode_winner.log").read_text()
receipt = (REPO / "docs/reporting/room-responses/aero-validator-2026-10-11-tipref-counterread.md").read_text()
register = (REPO / "docs/reporting/numbers-register.md").read_text()

# 1. pins
chk("pin: probe log sha256",
    sha256(REPO / "scratch/sv_probe_winner_areas.log") ==
    "a7c6e343b4cfba7f790fe0c2c3fd81638c06548c0d98d23407737c9ae0d9b0ab")
chk("pin: figures decode log sha256",
    sha256(REPO / "scratch/fig1_decode_winner.log") ==
    "0d18c091b8169475be9a7efa8e625de2a9aba8aac58438db4dc223222c50feee")

# 2. tokens from the committed probe log
R_main = token(probe_log, r"sys\.rotor\.radius \(R_main\)\s*=\s*(\S+)", "R_main")
r_in = token(probe_log, r"sys\.rotor\.blade_hub_radius\s*=\s*(\S+)", "r_in")
span_built = token(probe_log, r"span \(built\)\s*=\s*(\S+)", "span_built")
span_tip = token(probe_log, r"span \(tip offset\)\s*=\s*(\S+)", "span_tip")
r_hub = token(probe_log, r"r_hub=(\S+)", "r_hub")
r_rotor = token(probe_log, r"r_rotor=(\S+)", "r_rotor")
blade_scale = token(probe_log, r"blade_scale=(\S+)", "blade_scale")
blade_hub = token(probe_log, r"blade_hub=(\S+)", "blade_hub")

missing = [n for n, v in (("R_main", R_main), ("r_in", r_in), ("span_built", span_built),
                          ("span_tip", span_tip), ("r_hub", r_hub), ("r_rotor", r_rotor),
                          ("blade_scale", blade_scale), ("blade_hub", blade_hub)) if v is None]
if missing:
    print("FAIL  token extraction: " + ", ".join(missing))
    print("SV_NR043_DONE")
    sys.exit(1)

span_calc = R_main - r_in
chk("span (built) = R_main - r_in, bit-exact", span_calc == span_built,
    f"calc {span_calc!r} vs log {span_built!r}")
chk("span (tip offset) = R_main - r_hub, bit-exact", R_main - r_hub == span_tip,
    f"calc {(R_main - r_hub)!r} vs log {span_tip!r}")

# 3. the 70/30 ring anchor
outboard = R_main - r_hub
inboard = r_hub - r_in
e1 = abs(outboard / span_built - 0.7)
e2 = abs(inboard / span_built - 0.3)
chk("70/30 split ratios", e1 < 1e-12 and e2 < 1e-12, f"eps {e1:.2e} / {e2:.2e}")
e3 = abs(outboard - 0.7 * span_built)
e4 = abs(inboard - 0.3 * span_built)
chk("split closes on the span", e3 < 1e-15 and e4 < 1e-15, f"eps {e3:.2e} / {e4:.2e}")

# 4. the decode variable and the line pin
dec = 0.75 * r_rotor * blade_scale
e5 = abs(dec - span_built)
chk("span = 0.75 * r_rotor * blade_scale", e5 < 1e-15, f"eps {e5:.2e} dec {dec!r}")
e6 = abs(0.7 * dec - outboard)
e7 = abs(-0.3 * dec - blade_hub)
chk("decode tip/hub offsets", e6 < 1e-15 and e7 < 1e-15, f"eps {e6:.2e} / {e7:.2e}")

src_lines = (REPO / "src/objective_v10.jl").read_text().splitlines()
idx = next((i for i, s in enumerate(src_lines)
            if "span = 0.75 * r_rotor_i * blade_scale_i" in s), None)
pin_ok = (idx is not None and
          src_lines[idx].strip() == "span = 0.75 * r_rotor_i * blade_scale_i" and
          src_lines[idx + 1].strip() == "blade_tip = 0.7 * span" and
          src_lines[idx + 2].strip() == "blade_hub = -0.3 * span")
chk("line pin objective_v10.jl 374-376",
    pin_ok and idx + 1 == 374, f"found at line {idx + 1 if idx is not None else None}")

# 5. quote forms
chk("quote 3 dp", f"{span_built:.3f}" == "1.499", f"{span_built:.3f}")
chk("round 3 dp", round(span_built, 3) == 1.499)
chk("2 dp form", f"{span_built:.2f}" == "1.50")
chk("4 dp form", f"{span_built:.4f}" == "1.4994")
chk("6 dp form", f"{span_built:.6f}" == "1.499402")

# 6. cross-reads
chk("receipt carries span token", "1.4994019682084492" in receipt)
chk("receipt carries r_out", "5.629560432565964" in receipt)
chk("receipt carries r_in", "4.130158464357515" in receipt)
chk("receipt carries the split phrase", "0.7 / 0.3 split" in receipt)
chk("register NR-032 block carries span", "span reads 1.4994019682084492 m" in register)
chk("decode log carries 6 dp radii", "r_out = 5.629560  r_in = 4.130158" in decode_log)
chk("R_main 6 dp", f"{R_main:.6f}" == "5.629560")
chk("r_in 6 dp", f"{r_in:.6f}" == "4.130158")

# 7. the fresh re-run
rerun_path = REPO / "scratch/sv_nr043_span_rerun_2026-10-13.log"
if rerun_path.exists():
    rerun = rerun_path.read_text()
    chk("re-run equals committed log", rerun == probe_log)
    chk("re-run carries the span token",
        token(rerun, r"span \(built\)\s*=\s*(\S+)", "rerun span") == span_built)
else:
    chk("re-run log present", False)

print(f"\n{len(FAILS)} failures" if FAILS else "\nall checks pass")
print("SV_NR043_DONE")
sys.exit(1 if FAILS else 0)
