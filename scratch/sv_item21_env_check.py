#!/usr/bin/env python3
"""sv_item21_env_check.py — the item-2.1 environment rows: source and arithmetic reads (science-validator seat, 2026-10-15).

The aero seat's receipt (aero-validator-2026-10-15-item21-environment-reads.md)
carries three rows for sign: the shear law and exponent, the shaft-elevation
angle, the steady-wind basis. This checker re-reads each claim at the tree tip:
every source line, the pinned test lines, the register notes and the
arithmetic. Read only; no runs.
"""
import math
import re
import sys

FAILS = []


def check(name, cond, detail=""):
    print(f"  [{'PASS' if cond else 'FAIL'}] {name}" + (f"  ({detail})" if detail else ""))
    if not cond:
        FAILS.append(name)


def rd(p):
    return open(p, encoding="utf-8").read()


def lineno(path, needle):
    for n, line in enumerate(rd(path).splitlines(), 1):
        if needle in line:
            return n
    return None


print("sv_item21_env_check — the item-2.1 environment rows, source and arithmetic reads")
print()

wp = "src/wind_profile.jl"
print("A. src/wind_profile.jl — the law, the anchor and the constructor:")
check("L50 SITE_DAISY carries the measured pair and 1/7",
      lineno(wp, 'const SITE_DAISY = WindSiteSpec("Tulloch, Daisy (measured)", 10.0, 4.8, 1.0 / 7.0)') == 50,
      f"line {lineno(wp, 'const SITE_DAISY')}")
check("L54 SITE_ANCHOR = SITE_DAISY", lineno(wp, "const SITE_ANCHOR = SITE_DAISY") == 54)
check("L110-112 site_shear carries the anchor exponent",
      "hellmann_exponent=SITE_ANCHOR.shear_exp" in rd(wp))
check("L130-137 wind_at_altitude: V(h) = v_ref * (h / h_ref)^alpha",
      "return v_ref * (h / h_ref)^hellmann_exponent" in rd(wp))
check("L164 steady_wind returns a constant",
      lineno(wp, "steady_wind(v_ref::Float64) = (t::Float64) -> v_ref") == 164)
print()

pp = "src/parameters.jl"
print("B. src/parameters.jl — the angle, model convention, no scaling:")
check("L294 factory reads 30 deg (DRR)", lineno(pp, "# elevation_angle = 30\u00b0 (DRR)") == 294)
check("L369 daisy reads 30 deg (model convention)",
      lineno(pp, "# elevation_angle = 30\u00b0 (model convention)") == 369)
check("L606 angles do not scale", "does not scale" in rd(pp).splitlines()[605])
print()

oe = "src/objective_evaluator.jl"
print("C. src/objective_evaluator.jl — the steady-wind closure:")
check("L792-795 wf reads altitude only",
      "return [wind_at_altitude(p.v_wind_ref, p.h_ref, z), 0.0, 0.0]" in rd(oe))
check("no time term in the closure", "wind_at_altitude(p.v_wind_ref, p.h_ref, z)" in rd(oe))
print()

ru = "scripts/run_v13_5kw_masslift.jl"
print("D. scripts/run_v13_5kw_masslift.jl — the campaign pins:")
check("L73 ELEV = pi/6", lineno(ru, "const ELEV = \u03c0 / 6") == 73)
check("fos_hard = 2.5 on the campaign record", "fos_hard = 2.5" in rd(ru))
check("runner maps :reject (twist -> reject_twist)",
      "status = r.twist_crossed ? :reject_twist : :reject" in rd(ru))
print()

print("E. Arithmetic (the four altitudes, the hub, the swing):")
sw = lambda h: 10.0 * (h / 4.8) ** (1.0 / 7.0)
for h, want in ((4.8, 10.000000), (9.400, 11.007738), (9.4117, 11.009694), (8.914, 10.924573)):
    got = sw(h)
    check(f"site_wind({h:.4g}) = {want:.6f}", abs(got - want) < 5e-7, f"got {got:.6f}")
check("1/7 = 0.14285714285714285", 1.0 / 7.0 == 0.14285714285714285)
check("hub 18.8 * sin(30 deg) = 9.4000 m", abs(18.8 * math.sin(math.pi / 6) - 9.4) < 1e-12)
check("rung gap 9.4117 - 9.4000 = 0.0117 m", abs((9.4117 - 9.4) - 0.0117) < 1e-12)
check("site_shear(9.4117, 4.8) = 0.908290428006",
      abs((4.8 / 9.4117) ** (1.0 / 7.0) - 0.908290428006) < 5e-11)
check("swing 0.029 / 5.309 = 0.5462 per cent", abs(0.029 / 5.309 * 100 - 0.5462) < 0.001)
print()

rg = "docs/reporting/numbers-register.md"
print("F. The register notes:")
reg = rd(rg)
check("boundary note 5: settled hub mean z 8.914 m", "mean z 8.914 m" in reg, f"line {lineno(rg, 'mean z 8.914 m')}")
check("boundary note 5: elevation 28.64 deg", "elevation 28.64" in reg, f"line {lineno(rg, 'elevation 28.64')}")
check("boundary note 5: site profile reads 10.924 m/s", "10.924 m/s there" in reg)
check("the swing reads 0.54 per cent", "swing 0.54 per cent" in reg, f"line {lineno(rg, 'swing 0.54 per cent')}")
print()

print("G. The pinned tests:")
tb = "test/test_bem_unified.jl"
check("test_bem_unified: site_wind(9.400) = 11.0077", "site_wind(9.400) \u2248 11.0077" in rd(tb),
      f"line {lineno(tb, 'site_wind(9.400) \u2248 11.0077')}")
tz = "test/test_betz_ceiling_projection.jl"
n = lineno(tz, "11.0097")
check("test_betz_ceiling_projection: 11.0097 pinned (near L205)", n is not None and 190 <= n <= 215, f"line {n}")
tw = "test/test_wind_authority.jl"
check("test_wind_authority: L49-54 shape pins",
      "site_shear(h_ref, h) \u2248 (h / h_ref)^(1 / 7)" in rd(tw) and
      "site_shear(9.4117, 9.4117) == 1.0" in rd(tw))
print()

print("RESULT: " + ("ALL CHECKS PASS" if not FAILS else f"{len(FAILS)} FAILURES: {FAILS}"))
sys.exit(0 if not FAILS else 1)
