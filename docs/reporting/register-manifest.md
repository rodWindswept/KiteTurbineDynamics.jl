# Register manifest: the full-precision readings behind the human-facing register

**Slug** `register-manifest`. **Status** LIVE, seed 2026-10-18. **Owner** @aero-validator. **Readers** the report-team room and Rod.

The reader-facing register prints each NR row at four significant
digits. This file carries the full-precision readings those cells
round. The display amend 2026-10-18 in
`docs/reporting/numbers-register.md` cites this file.

Rows NR-021 to NR-024 hold the aero seat. The science-validator rows
land here in the same pattern when that seat runs its half of the
register formatting.

## NR-021 Ring check at the winner operating point (island 3)

The register prints the interaction and the FoS per checked ring at
four significant digits. The full strings read:

```text
R2 0.03323714455441065 = 0.033223570205929 + 1.3574348481652112e-5, FoS 30.086820435580936
R3 0.033548608446737266 = 0.03354237801917142 + 6.230427565848155e-6, FoS 29.80749563987516
R4 0.028380221733419368 = 0.028374815022862057 + 5.40671055731162e-6, FoS 35.23580644975869
R5 3.058346201008972e-6 = 0.0 + 3.058346201008972e-6, FoS 326974.1011237028
R6 hub 0.06652238395895148 = 0.06652164721153939 + 7.36747412096439e-7, FoS 15.032534020684876
```

Source: `docs/reporting/figures/pair-extract/extract-winner-operating-point.csv`, ring block.

## NR-022 Segment twist and over-twist limit at the winner operating point

The register prints the angles at four significant digits. The full
strings read:

```text
abs(dalpha): S1 33.94561934829036°, S2 33.811870056223555°, S3 33.67952027817454°, S4 33.54707806507812°, S5 22.821871326820364°
dcrit: S1 to S4 98.85908296054023°, S5 92.64281134151318°
has_limit true on all five
```

Source: extract, segment block.

## NR-023 Segment torque pair at the winner operating point

The register prints the torques at four significant digits. The full
strings read:

```text
segment_torque: S1 396.791634149159, S2 397.1554424859068, S3 397.45360112890063, S4 397.68800908436924, S5 397.1777954649229
torque_capacity: S1 805.0097155967861, S2 808.6780945063998, S3 812.213802301376, S4 815.650844050359, S5 1069.9324759682652
```

Source: extract, segment block.

## NR-024 Evaluator step law

The register prints the winner derived step at four significant
digits. The full string reads:

```text
Winner derived step 2.8987873697672758e-5 s
```

Source: winner value from the extract log.

## Science-validator rows (science-validator, display amend 2026-10-18)

The reader-facing register prints these rows at four significant
digits. This section carries the full-precision strings.

Where a source cell also prints a long decimal, this section
carries that string too. A reading that a shipped plate already
labels keeps the shipped label form.

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

