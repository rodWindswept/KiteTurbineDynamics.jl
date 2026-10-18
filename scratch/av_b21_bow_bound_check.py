#!/usr/bin/env python3
# scratch/av_b21_bow_bound_check.py — aero-validator, 2026-10-18
#
# B-21 counter-read: does NR-059's evidence bound the shaft bow below the
# 1.5 m comparison line, and do the draft's section 3.3 digits quote the
# log forms correctly? Reads the PINNED committed bytes only:
#   scratch/av_bow_probe.log  (sha256 eacc0ce3…, register pin)
#   scratch/av_bow_probe.jl   (sha256 24a1601…, register pin)
import hashlib
import re

LOG = "scratch/av_bow_probe.log"
PROBE = "scratch/av_bow_probe.jl"

PIN_LOG = "eacc0ce3acbcdeb66b6dd9db975b177ceb401a2929bee2c40fd258e22f2bf987"
PIN_PROBE = "24a1601718dcb2d8536872ca975b6a823fed640e72686486c434fdc6216c73a4"

checks = []
def chk(name, ok, detail=""):
    checks.append((name, bool(ok), detail))
    print(f"  [{'PASS' if ok else 'FAIL'}] {name} {detail}")

def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()

text = open(LOG).read()

# ── 0. the pins ──────────────────────────────────────────────────────────
chk("probe pin holds", sha(PROBE) == PIN_PROBE)
chk("log pin holds", sha(LOG) == PIN_LOG)

# ── 1. parse the pinned log ──────────────────────────────────────────────
m = re.search(r"mid-span ring 5 \(s_axial [\d.]+\) perp = ([\d.]+)", text)
mid_settle = float(m.group(1))
m = re.search(r"SETTLE hub perp \(ring 6\) = ([\d.]+) m", text)
hub_settle = float(m.group(1))

hub_win = [float(x) for x in re.search(r"window ring6 series: \[([^\]]+)\]", text).group(1).split(",")]
mid_win = [float(x) for x in re.search(r"window ring5 series: \[([^\]]+)\]", text).group(1).split(",")]
chk("window series lengths", len(hub_win) == 40 and len(mid_win) == 40, f"hub={len(hub_win)} mid={len(mid_win)}")

ext_rows = re.findall(r"^\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\-\+][\d.]+)$", text, re.M)
chk("extension series parsed", len(ext_rows) == 29, f"rows={len(ext_rows)}")
hub_ext = [float(r[2]) for r in ext_rows]
mid_ext = [float(r[3]) for r in ext_rows]
omega_ext = [float(r[1]) for r in ext_rows]

m = re.search(r"raw: hub at t=200 = .*? perp = ([\d.]+)", text)
hub_t200_raw = float(m.group(1))
m = re.search(r"terminal: hub perp ([\d.]+) m at t=(\d+)", text)
hub_term, t_term = float(m.group(1)), int(m.group(2))
m = re.search(r"P_range = ([\d.e\-]+)", text)
p_range = float(m.group(1))
m = re.search(r"P_mean = ([\d.]+)", text)
p_mean = float(m.group(1))

relax_hub = [float(x) for x in re.findall(r"^\s+t=[\d.]+\s+([\d.]+)$", text, re.M)]
chk("relax phase parsed", len(relax_hub) == 6, f"samples={len(relax_hub)}")

# ── 2. the draft's section 3.3 digits, quoted at 3 decimals ──────────────
def q3(x):
    return f"{x:.3f}"

draft_pairs = [
    ("mid settle 0.002", q3(mid_settle), "0.002"),
    ("mid window 0.105", q3(min(mid_win)), "0.105"),
    ("mid window 0.310", q3(max(mid_win)), "0.310"),
    ("hub window 0.209", q3(min(hub_win)), "0.209"),
    ("hub window 0.613", q3(max(hub_win)), "0.613"),
    ("mid extension 0.422", q3(mid_ext[-1]), "0.422"),
    ("hub extension 0.833", q3(hub_term), "0.833"),
]
for name, got, want in draft_pairs:
    chk(f"draft digit {name}", got == want, f"log->{got} want {want}")

# ── 3. the 1.5 m bound, every recorded state ─────────────────────────────
all_hub = [hub_settle] + relax_hub + hub_win + hub_ext + [hub_t200_raw]
all_mid = [mid_settle] + mid_win + mid_ext
hub_max, mid_max = max(all_hub), max(all_mid)
chk("every hub state below 1.5 m", all(x < 1.5 for x in all_hub),
    f"max={hub_max:.6f} margin={1.5 - hub_max:.6f} n={len(all_hub)}")
chk("every midpoint state below 1.5 m", all(x < 1.5 for x in all_mid),
    f"max={mid_max:.6f} margin={1.5 - mid_max:.6f} n={len(all_mid)}")
chk("draft sentence scope (midpoint ring) holds", mid_max < 1.5,
    "the printed sentence covers the midpoint ring only")

# ── 4. operating-point steadiness vs bow drift (the B-21 "why") ──────────
w_spread = max(omega_ext) - min(omega_ext)
chk("extension omega steady", w_spread / omega_ext[0] < 1e-4,
    f"spread={w_spread:.5f} rad/s = {100*w_spread/omega_ext[0]:.4f}% of {omega_ext[0]}")
chk("window power swing (NR-014 scale)", p_range / p_mean < 0.01,
    f"{p_range:.5f} kW on {p_mean:.5f} kW = {100*p_range/p_mean:.3f}%")

inc = [hub_ext[i] - hub_ext[i-1] for i in range(1, len(hub_ext))]
mono = all(inc[i] < inc[i-1] for i in range(1, len(inc)))
chk("extension bow increments strictly decreasing", mono,
    f"first={inc[0]:.5f} last={inc[-1]:.5f} m per 5 s")

# ── 5. derived read (NOT a register claim): geometric tail ───────────────
ratios = [inc[i] / inc[i-1] for i in range(1, len(inc))]
r_mean = sum(ratios[-10:]) / 10
tail = inc[-1] * r_mean / (1 - r_mean)
asym = hub_t200_raw + tail
print(f"\n  [derived, unsigned] last-10 ratio mean={r_mean:.4f}; geometric tail "
      f"~{tail:.4f} m; asymptote ~{asym:.4f} m; margin to 1.5 m ~{1.5 - asym:.4f} m")

total = len(checks)
fails = sum(1 for _, ok, _ in checks if not ok)
print(f"\nAV_B21_BOUND_CHECK: {total - fails}/{total} checks pass")
exit(1 if fails else 0)
