#!/usr/bin/env python3
"""Science-validator register display round 2026-10-18.

Applies the 4-sig-fig display round to the science-validator rows in
numbers-register.md, the kg -> kg-equivalent unit fix, the NR-053
dastar -> δα* notation move, and appends the full-precision strings to
register-manifest.md. Every replacement is asserted to occur exactly
once; the pass fails loud on drift.
"""
import sys, io

REG = "docs/reporting/numbers-register.md"
MAN = "docs/reporting/register-manifest.md"
LOG = "scratch/sv_register_display_apply.log"

log = io.StringIO()

def p(*a):
    print(*a)
    print(*a, file=log)

txt = open(REG, encoding="utf-8").read()
n0 = len(txt)

# (old, new) pairs; each old must occur exactly once in the file.
PAIRS = [
    # --- unit fixes: fitness rows print kg-equivalent ---
    ("30.578 (found gen 30) | kg |",
     "30.578 (found gen 30) | kg-equivalent |"),
    ("30.637 (found gen 30) | kg |",
     "30.637 (found gen 30) | kg-equivalent |"),
    ("27.364 (found gen 26) | kg |",
     "27.364 (found gen 26) | kg-equivalent |"),
    ("36.109 (gen 1, common seed) | kg |",
     "36.109 (gen 1, common seed) | kg-equivalent |"),
    ("28.315 (gen 25), 27.364 (gen 26) | kg |",
     "28.315 (gen 25), 27.364 (gen 26) | kg-equivalent |"),
    # --- value-cell rounds ---
    ("| Winner airborne mass (island 3) | 25.69846825623688 | kg |",
     "| Winner airborne mass (island 3) | 25.70 | kg |"),
    ("13.380259861740395 (quote 13.38, 127.772 rpm)",
     "13.38 (quote 13.38, 127.772 rpm)"),
    ("396.76205834512626 (quote 396.76)",
     "396.8 (quote 396.76)"),
    ("S1 panel 396.791634149159 (0.0075 % above), S5 hub 397.1777954649229",
     "S1 panel 396.8 (0.0075 % above), S5 hub 397.2"),
    ("lambda_gnd 5.565968202980965 (quote 5.566, hub value 5.56592352649632 agrees inside 1.1e-4), Cp 0.29437093178017804 (quote 0.2944), system coeff 0.10163090072260127 (quote 0.1016)",
     "lambda_gnd 5.566 (quote 5.566, hub value 5.566 agrees inside 1.1e-4), Cp 0.2944 (quote 0.2944), system coeff 0.1016 (quote 0.1016)"),
    ("r_ring 4.57997905482005 m, v_ref 11.01 m/s",
     "r_ring 4.580 m, v_ref 11.01 m/s"),
    ("lambda_tip 6.8415060395190075 (quote 6.8415, hub value 6.841451124645552 agrees inside 5.5e-5), Cp 0.22578839742146659 (quote 0.2258)",
     "lambda_tip 6.842 (quote 6.8415, hub value 6.841 agrees inside 5.5e-5), Cp 0.2258 (quote 0.2258)"),
    ("r_out 5.629560432565964 m, v_ref 11.01 m/s",
     "r_out 5.630 m, v_ref 11.01 m/s"),
    ("A_raw 45.9732554921615 (quote 45.9733), A_bank 45.60047944351075, A_zn 39.491173622830395 (quote 39.4912), A_zy 39.81400715088433 (elevation-only cross-check), A_hub_bot 63.86952678906739 (retired basis)",
     "A_raw 45.97 (quote 45.9733), A_bank 45.60, A_zn 39.49 (quote 39.4912), A_zy 39.81 (elevation-only cross-check), A_hub_bot 63.87 (retired basis)"),
    ("ceiling (16/27) x 0.5 rho A_zn v^3 = 19.130411371981566 kW (quote 19.1304), delivered share 0.27750471961685264 (quote 27.75 %), system coeff 0.1412607066141203 on A_raw and 0.1644472412544312 on A_zn",
     "ceiling (16/27) x 0.5 rho A_zn v^3 = 19.13 kW (quote 19.1304), delivered share 0.2775 (quote 27.75 %), system coeff 0.1413 on A_raw and 0.1644 on A_zn"),
    ("The code gate charges the rounded 0.593 form: 19.143563529799803 kW",
     "The code gate charges the rounded 0.593 form: 19.14 kW"),
    ("0.20657960587391747 (quote 0.2066)",
     "0.2066 (quote 0.2066)"),
    ("Recipe: 5.3087794439367935 kW / 25.69846825623688 kg. On the mass net of the 5 kg lifter (20.69846825623688 kg) the read is 0.25648175402240925",
     "Recipe: 5.309 kW / 25.70 kg. On the mass net of the 5 kg lifter (20.70 kg) the read is 0.2565"),
    ("F_vert 304.5779603905257 (quote 304.6), sizing mass 20.69846825623688 (quote 20.70), weight 252.1019735936838 (quote 252.1), ratio 1.2081538119230202 (quote 1.21)",
     "F_vert 304.6 (quote 304.6), sizing mass 20.70 (quote 20.70), weight 252.1 (quote 252.1), ratio 1.208 (quote 1.21)"),
    ("gnd window min 13.361451740981568, max 13.384909253752044, last 13.384824668402052. Last relax sample, t = 9.990119900356282 s: gnd 13.35927880647099, hub 13.375919394174096",
     "gnd window min 13.36, max 13.38, last 13.38. Last relax sample, t = 9.990 s: gnd 13.36, hub 13.38"),
    ("fitness 27.3635412663488 = mass 25.69846825623688 + over-power 0.49333696413175443 + utilisation 0.5576509889014662 + twist 0.6140850570787014. Penalty total 1.6650730101119215 (quote 1.665) | kg |",
     "fitness 27.36 = mass 25.70 + over-power 0.4933 + utilisation 0.5577 + twist 0.6141. Penalty total 1.665 (quote 1.665) | kg-equivalent |"),
    ("S1 2.0287970973051634, S2 2.036175280501402, S3 2.0435436991749936, S4 2.0509817379918016, S5 2.6938375915900292. S1 governs (quote 2.03). The S1 to S4 band reads 2.03 to 2.05.",
     "S1 2.029, S2 2.036, S3 2.044, S4 2.051, S5 2.694. S1 governs (quote 2.03). The S1 to S4 band reads 2.029 to 2.051."),
    ("Recipe: 805.0097155967861 / 396.791634149159 = 2.0287970973051634",
     "Recipe: 805.0 / 396.8 = 2.029"),
    ("1.4994019682084492 (quote 1.499)",
     "1.499 (quote 1.499)"),
    ("sha256 `a7c6e343b4cfba7f790fe0c2c3fd81638c06548c0d98d23407737c9ae0d9b0ab`: R_main 5.629560432565964 minus blade_hub_radius 4.130158464357515",
     "sha256 in the manifest. R_main 5.630 minus blade_hub_radius 4.130"),
    ("Winner closure: 25.69846825623688 + 0.49333696413175443 + 0.5576509889014662 + 0.6140850570787014 = 27.3635412663488 (NR-039).",
     "Winner closure: 25.70 + 0.4933 + 0.5577 + 0.6141 = 27.36 (NR-039)."),
    ("`r_rotor` `2.4341173109692225`, base span `1.8255879832269168`, span `1.4994019682084492` (NR-043), chord `0.22590989654340632`",
     "`r_rotor` `2.434`, base span `1.826`, span `1.499` (NR-043), chord `0.2259`"),
    ("Worst crossing ratio 0.4393474253185575, margin 2.28",
     "Worst crossing ratio 0.4393, margin 2.28"),
    ("sin(dalpha) <= 1/1.05 = 0.9523809523809523 (quote 0.9524). The continuum floor angle reads 72.24720983805331 deg (quote 72.25). The discrete crossing limit reads dastar = 2*asin(L_seg / sqrt(2*(L_seg^2 + 2*r_seg^2))), r_seg = max(r_i, r_{i+1}). Winner cross-reads: S1 twist 33.94561934829036 deg, margin 2.13 to the floor and 2.91 to dcrit (NR-022)",
     "sin(Δα) <= 1/1.05 = 0.9524 (quote 0.9524). The continuum floor angle reads 72.25 deg (quote 72.25). The discrete crossing limit reads δα* = 2*asin(L_seg / sqrt(2*(L_seg^2 + 2*r_seg^2))), r_seg = max(r_i, r_{i+1}). Winner cross-reads: S1 twist 33.95 deg, margin 2.13 to the floor and 2.91 to δ_crit (NR-022)"),
    ("Hellmann power law, exponent 1/7 (0.14285714285714285). One authority: the measured Daisy pair, 10.0 m/s at 4.8 m. Reads: 11.0097 m/s at 9.4117 m (the table pair reads 11.01 at 9.41), 11.0077 m/s at the 9.400 m design hub, 10.9246 m/s at the settled hub 8.914 m",
     "Hellmann power law, exponent 1/7 (0.1429). One authority: the measured Daisy pair, 10.0 m/s at 4.8 m. Reads: 11.01 m/s at 9.412 m (the table pair reads 11.01 at 9.41), 11.01 m/s at the 9.400 m design hub, 10.92 m/s at the settled hub 8.914 m"),
    ("-157.62246416260894 to -142.7923499969138 (tension), three beams, N/Ncrit -0.09240481892804314 to -0.08371079157957116",
     "-157.6 to -142.8 (tension), three beams, N/Ncrit -0.09240 to -0.08371"),
]

# line-1420 basis block (NR-046): dastar notation
lines = txt.split("\n")
li = [i for i, l in enumerate(lines) if "Twist ratio basis. The ratio reads" in l]
assert len(li) == 1, f"basis line not unique: {li}"
idx = li[0]
assert "`abs(dalpha) / dastar`" in lines[idx]
assert "`dastar = 2 * asin(" in lines[idx]
lines[idx] = lines[idx].replace("`abs(dalpha) / dastar`", "`|Δα| / δα*`")
lines[idx] = lines[idx].replace("`dastar = 2 * asin(", "`δα* = 2 * asin(")
txt = "\n".join(lines)
p(f"basis line {idx+1}: notation moved (abs(dalpha)/dastar -> |Δα|/δα*)")

for old, new in PAIRS:
    c = txt.count(old)
    assert c == 1, f"count {c} for old string: {old[:80]}..."
    txt = txt.replace(old, new)
    p(f"ok ({c}): {old[:60]}... -> {new[:60]}...")

# basis-line replacements changed length; recompute the expected total:
n_expected = n0 + sum(len(n) - len(o) for o, n in PAIRS) + (len("`|Δα| / δα*`") - len("`abs(dalpha) / dastar`")) + (len("`δα* = 2 * asin(") - len("`dastar = 2 * asin("))
assert len(txt) == n_expected, f"length drift: {len(txt)} != {n_expected}"

AMEND = """

## Display amend 2026-10-18 (science-validator)

The science-validator rows now print at four significant digits.
A reading that a shipped plate already labels keeps the shipped
label form. The span (NR-043), the operating speed (NR-029) and
the realisability floor angle (NR-053) read the plate forms.

The manifest file `docs/reporting/register-manifest.md` carries
the full-precision readings. It also carries the NR-043 probe
sha256 and the long source strings.

The fitness rows NR-003 to NR-006, NR-036 and NR-039 now print
the unit `kg-equivalent`. A fitness score folds power and safety
penalties into mass units at the seam weights of NR-046. Real
masses keep `kg`.

The NR-053 notation moves from `dastar` to `δα*`. The NR-046
basis block adopts the same form.

No value changes. Each row keeps its sign-off basis. The
2026-10-18 feedback in `docs/reporting/feedback-on-report.md`
prompts this change.
"""
txt = txt.rstrip("\n") + AMEND + "\n"
open(REG, "w", encoding="utf-8").write(txt)
p(f"amend block appended to {REG}")

# --- manifest section ---
MANIFEST = """

## Science-validator rows (science-validator, display amend 2026-10-18)

The reader-facing register prints these rows at four significant
digits. This section carries the full-precision strings. Where a
source cell also prints a long decimal, this section carries that
string too. A reading that a shipped plate already labels keeps
the shipped label form.

### NR-018 Winner airborne mass (island 3)

```text
25.69846825623688 kg
```

### NR-029 Winner operating speed, window-mean ground ring

```text
13.380259861740395 rad/s
```

### NR-030 Winner delivered torque, window-mean basis

```text
396.76205834512626 N·m
S1 panel 396.791634149159 (0.0075 % above)
S5 hub 397.1777954649229
```

### NR-031 Winner operating coefficients

```text
lambda_gnd 5.565968202980965
hub value 5.56592352649632
Cp 0.29437093178017804
system coeff 0.10163090072260127
source extra: r_ring 4.57997905482005 m
```

### NR-032 Winner tip-speed ratio and rotor Cp, tip reference

```text
lambda_tip 6.8415060395190075
hub value 6.841451124645552
Cp 0.22578839742146659
source extra: r_out 5.629560432565964 m
```

### NR-033 Winner swept-area set

```text
A_raw 45.9732554921615
A_bank 45.60047944351075
A_zn 39.491173622830395
A_zy 39.81400715088433
A_hub_bot 63.86952678906739
```

### NR-034 Winner Betz ceiling and re-based coefficients

```text
ceiling (16/27) x 0.5 rho A_zn v^3 = 19.130411371981566 kW
delivered share 0.27750471961685264
system coeff 0.1412607066141203 on A_raw
system coeff 0.1644472412544312 on A_zn
source extra: the code gate charges 19.143563529799803 kW
```

### NR-035 Design-point specific power

```text
0.20657960587391747 kW/kg
recipe 5.3087794439367935 kW / 25.69846825623688 kg
net of the 5 kg lifter (20.69846825623688 kg) the read is 0.25648175402240925
```

### NR-037 Winner lift-line derived set

```text
F_vert 304.5779603905257 N
sizing mass 20.69846825623688 kg
weight 252.1019735936838 N
ratio 1.2081538119230202
```

### NR-038 Winner window trace endpoints

```text
gnd window min 13.361451740981568
gnd window max 13.384909253752044
gnd window last 13.384824668402052
last relax sample t = 9.990119900356282 s
gnd 13.35927880647099
hub 13.375919394174096
```

### NR-039 Island-3 fitness decomposition

```text
fitness 27.3635412663488 = mass 25.69846825623688
over-power 0.49333696413175443
utilisation 0.5576509889014662
twist 0.6140850570787014
penalty total 1.6650730101119215
```

### NR-040 Winner segment torque margin

```text
S1 2.0287970973051634
S2 2.036175280501402
S3 2.0435436991749936
S4 2.0509817379918016
S5 2.6938375915900292
recipe 805.0097155967861 / 396.791634149159 = 2.0287970973051634
```

### NR-043 Winner blade span

```text
1.4994019682084492 m
sha256 a7c6e343b4cfba7f790fe0c2c3fd81638c06548c0d98d23407737c9ae0d9b0ab
R_main 5.629560432565964 minus blade_hub_radius 4.130158464357515
```

### NR-046 Objective seam winner closure

```text
winner closure 25.69846825623688 + 0.49333696413175443 + 0.5576509889014662 + 0.6140850570787014 = 27.3635412663488
```

### NR-050 Blade-scale base decode

```text
r_rotor 2.4341173109692225
base span 1.8255879832269168
span 1.4994019682084492
chord 0.22590989654340632
```

### NR-052 Torsion criteria worst crossing ratio

```text
0.4393474253185575
```

### NR-053 Realisability floor

```text
1/1.05 = 0.9523809523809523
continuum floor angle 72.24720983805331 deg
S1 twist 33.94561934829036 deg
```

### NR-056 Shear law reads

```text
exponent 0.14285714285714285
11.0097 m/s at 9.4117 m
11.0077 m/s at the 9.400 m design hub
10.9246 m/s at the settled hub 8.914 m
```

### NR-060 R5 signed axial force

```text
-157.62246416260894 to -142.7923499969138 N
N/Ncrit -0.09240481892804314 to -0.08371079157957116
"""
man = open(MAN, encoding="utf-8").read()
open(MAN, "w", encoding="utf-8").write(man.rstrip("\n") + MANIFEST + "\n")
p(f"science-validator section appended to {MAN}")

open(LOG, "w", encoding="utf-8").write(log.getvalue())
p(f"audit log: {LOG}")
