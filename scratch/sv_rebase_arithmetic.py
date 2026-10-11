#!/usr/bin/env python3
# sv_rebase_arithmetic.py — science-validator seat, 2026-10-11.
#
# Independent arithmetic route for the register's re-base rows NR-032 to NR-036.
# Recomputes, from built radii and signed values only (no Julia):
#   NR-032  tip-referenced speed ratio and Cp pair
#   NR-033  swept-area set (A_raw, A_bank, A_zn, A_zy, A_hub_bot)
#   NR-034  wind-normal Betz ceiling, delivered share, re-based coefficients
#   NR-035  design-point specific power
#   NR-036  the seven strip milestone fitness values against raw telemetry
# Every check asserts; a clean run prints ALL CHECKS PASS and exits 0.
#
# Sources: winner genome scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_3/best_vector.csv
# (values inlined as constants below); telemetry island_3/telemetry.csv; the
# cp table parsed from src/aerodynamics.jl.

import csv
import math
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)

# ── built winner geometry (sv_probe_winner_areas.jl / av_probe_tipref_counter.jl) ──
R_OUT = 5.629560432565964      # sys.rotor.radius (tip)
R_IN = 4.130158464357515       # sys.rotor.blade_hub_radius
R_HUB = 4.57997905482005       # ring gene
R_BOT = 0.8036829846088207
BANK_DEG = 7.088131460323565
V_REF = 11.01                  # one-wind boundary
RHO = 1.225

checks = []
def chk(name, got, want, tol=1e-9):
    ok = (got == want) if want == 0 else abs(got - want) <= tol * max(1.0, abs(want))
    checks.append((name, ok, got, want))
    print(f"{'PASS' if ok else 'FAIL'} {name}: got {got!r} want {want!r}")

# ── NR-033 areas ──
span = R_OUT - R_IN
r_ring = 0.3 * R_OUT + 0.7 * R_IN
chk("span", span, 1.4994019682084492)
chk("r_ring unfold", r_ring, R_HUB)
cosb = math.cos(math.radians(BANK_DEG))
r_out_b = r_ring + 0.7 * span * cosb
r_in_b = max(r_ring - 0.3 * span * cosb, 0.0)
A_bank = math.pi * (r_out_b**2 - r_in_b**2)
A_raw = math.pi * (R_OUT**2 - R_IN**2)
A_zn = A_bank * math.cos(math.pi / 6)
A_zy = A_raw * math.cos(math.pi / 6)
A_hubbot = math.pi * (R_HUB**2 - R_BOT**2)
chk("A_raw", A_raw, 45.9732554921615)
chk("A_bank", A_bank, 45.60047944351075)
chk("A_zn", A_zn, 39.491173622830395)
chk("A_zy", A_zy, 39.81400715088433)
chk("A_hub_bot", A_hubbot, 63.86952678906739)

# ── NR-034 ceiling chain at v = 11.01 ──
v3 = V_REF**3
half_zn = 0.5 * RHO * A_zn * v3 / 1000.0
half_raw = 0.5 * RHO * A_raw * v3 / 1000.0
ceil_1627 = (16.0 / 27.0) * half_zn
ceil_0593 = 0.593 * half_zn
P_kw = 5.3087794439367935       # NR-008 full precision
share = P_kw / ceil_1627
coeff_raw = P_kw / half_raw
coeff_zn = P_kw / half_zn
chk("half rho A_zn v3 kW", half_zn, 32.282569190218894)
chk("half rho A_raw v3 kW", half_raw, 37.58143061282218)
chk("ceiling (16/27)", ceil_1627, 19.130411371981566)
chk("ceiling 0.593", ceil_0593, 19.143563529799803)
chk("delivered share", share, 0.27750471961685264)
chk("coeff on A_raw", coeff_raw, 0.1412607066141203)
chk("coeff on A_zn", coeff_zn, 0.1644472412544312)

# ── NR-032 tip pair + cp interpolation from the committed table ──
src = open(os.path.join(REPO, "src", "aerodynamics.jl")).read()
def parse_arr(name):
    m = re.search(rf"const {name} = \[(.*?)\]", src, re.S)
    body = re.sub(r"#.*", "", m.group(1))
    return [float(t) for t in body.replace("\n", " ").split(",") if t.strip()]
BEM_TSR, BEM_CP = parse_arr("BEM_TSR"), parse_arr("BEM_CP")
def cp_at(x):
    for j in range(len(BEM_TSR) - 1):
        if BEM_TSR[j] <= x <= BEM_TSR[j + 1]:
            w = (x - BEM_TSR[j]) / (BEM_TSR[j + 1] - BEM_TSR[j])
            return BEM_CP[j] * (1 - w) + BEM_CP[j + 1] * w
    return float("nan")
w_gnd, w_hub = 13.380259861740395, 13.380152462101652
lam_gnd = w_gnd * R_OUT / V_REF
lam_hub = w_hub * R_OUT / V_REF
lam_ring_gnd = w_gnd * R_HUB / V_REF
chk("lambda_tip gnd", lam_gnd, 6.8415060395190075)
chk("lambda_tip hub", lam_hub, 6.841451124645552)
chk("cp at hub lambda", cp_at(lam_hub), 0.22578839742146659)
chk("lambda_ring gnd (NR-031)", lam_ring_gnd, 5.565968202980965)
chk("cp at hub ring lambda (NR-031)", cp_at(5.56592352649632), 0.29437093178017804)

# ── NR-035 specific power ──
m_full = 25.69846825623688      # NR-018
m_net = 20.69846825623688       # net of the 5 kg lifter (NR-026 chain)
spec_full = P_kw / m_full
spec_net = P_kw / m_net
chk("specific power full mass", spec_full, 0.20657960587391747)
chk("specific power net mass", spec_net, 0.25648175402240925)

# ── NR-036 milestones vs raw telemetry ──
tel_path = os.path.join(REPO, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate2", "island_3", "telemetry.csv")
raw = open(tel_path).read().splitlines()
hdr = next(i for i, l in enumerate(raw) if l.startswith("island,"))
rows = list(csv.DictReader(raw[hdr:]))
picks = [(0, 1), (6, 2), (10, 7), (18, 4), (22, 10), (25, 8), (26, 9)]
targets = [36.109, 32.293, 31.661, 30.929, 29.854, 28.315, 27.364]
for (g, i2), tgt in zip(picks, targets):
    r = [x for x in rows if int(x["gen"]) == g and int(x["idx"]) == i2][0]
    ok = [float(x["fitness"]) for x in rows if x["status"] == "ok" and int(x["gen"]) <= g]
    chk(f"milestone gen {g} idx {i2} quote", float(r["fitness"]), tgt, tol=1e-9)
    chk(f"milestone gen {g} is-best-so-far", min(ok), float(r["fitness"]), tol=1e-12)
    print(f"      gen {g:2d} idx {i2:2d}: fitness {r['fitness']} status {r['status']}")

bad = [c for c in checks if not c[1]]
print(f"\nchecks: {len(checks)}  failed: {len(bad)}")
print("ALL CHECKS PASS" if not bad else "FAILURES PRESENT")
raise SystemExit(1 if bad else 0)
