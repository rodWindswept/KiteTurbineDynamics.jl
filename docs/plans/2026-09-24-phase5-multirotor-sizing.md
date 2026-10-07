# Phase 5: multi-rotor BEM sizing remediation

**Status:** plan. Three rulings from Rod are needed before code. No code in this document has landed.
**Date:** 2026-09-24.
**Source:** `handovers/handover-2026-09-23-multirotor-bem-sizing.md` Phase 5 panel
(2026-09-24), the verified-correction banner in the same file, `DECISIONS.md`
[2026-09-23] and [2026-09-24], and `docs/agents/physics-topology.md` sections 4.1
and 5.
**Probe:** `scratch/probe_phase5_inflow_sizing.jl`. Sizing only, no ODE. Every
number below comes from it. It carries three assertions.

## Goal

Make the rotor sizing follow the ring annulus, make every rotor take an equal
share, and anchor the inflow. Then re-baseline the measured fixtures and re-gate
the three islands on the corrected machine.

## 1. Verified state of the five tasks

| Task | State at 2026-09-24 | Site |
|---|---|---|
| 5.1 `annulus_span_for_power` | **DONE**. Landed `0fb5b04`. Exact quadratic, `bank_deg` parameter, 5 cm floor, exported. | `src/bem.jl:175`, export at `:200` |
| 5.2 decode loop | **OPEN**. Disc-radius span and the `n_active == 1` branch are both live. | `src/objective_v10.jl:354`, `:369` |
| 5.3 shear reference | **OPEN**. The function never reads `hub_altitude`. `h_ref` stays at 50.0 m. | `src/objective_v10.jl:92-97`, call at `:349` |
| 5.4 guards | **OPEN**. The guard text in the handover is WRONG. See section 4. | `test/test_bem_unified.jl:91-149` |
| 5.5 wake factor | **OPEN**. A campaign knob in `scripts/`, not in `src/`. No measurement. | `scripts/compute_seeds.jl:41` |

Two reporting defects travel with the work. `scripts/run_v13_5kw_masslift.jl:115`
writes `blocking_factor=1.0` into every campaign provenance file, while line 174
passes `BLOCKING_WIND_FACTOR_5KW`. `src/objective_evaluator.jl:144` states
"top-heavy wins" in a comment, which contradicts the equal-share ruling of
2026-09-24.

## 2. What the probe measured

**The reference height.** At 5 kW and 18.8 m, the design hub altitude is
`tether_length·sin(30°) = 9.4000 m`. The rung value `p.h_ref` is 9.4117 m. The gap
is 0.0117 m, or 0.124 per cent. It comes from `mass_scale` carrying `h_ref` by
`geom_scale`, while `params_at_length` restores `tether_length` to 18.8 m. The gap
moves the top-rotor span from 0.339776 m to 0.339952 m. So the choice of reference
is immaterial to the sizing. Prefer the design-derived hub altitude, because it
is self-consistent by construction.

**Island 1 (3 rotors, r_hub 2.6096 m, 3 lines, 10 rings).** Rotor altitudes are
9.400 m, 7.261 m and 5.123 m for the top, middle and lowest rotor.

| sizing law | top span | middle span | lowest span | total blade mass |
|---|---|---|---|---|
| as coded: disc span, `power_split` 0.6, `h_ref` 50 m | 1.9584 m | 1.2753 m | 1.2645 m | **14.6253 kg** |
| wired inflow, `power_split` 0.6 | 0.7890 m | 0.3044 m | 0.2659 m | 0.6781 kg |
| wired inflow, equal share | 0.4494 m | 0.5000 m | 0.4375 m | **0.3774 kg** |
| wired inflow, equal share, 15 per cent blocking | 0.3980 m | 0.4431 m | 0.4375 m | 0.2946 kg |
| wired inflow, equal share, no wake de-rate | 0.3398 m | 0.3784 m | 0.4375 m | 0.2232 kg |

The fully corrected total is **0.3774 kg against 14.6253 kg as coded**, a factor
of 38.8. The hub mass that drove the whip of island 1 falls from 9.4645 kg to
0.1143 kg.

**The single-rotor islands.** The `n_active == 1` fix sizes the rotor at the full
5 kW. Its span is 0.7379 m and its total blade mass is 0.5063 kg, against
2.9735 kg as coded.

**The wake factor is not dominant, but it decides the ranking.** It is worth at
most 1.7 times on the total blade mass of island 1 (0.2232 kg to 0.3774 kg). The
inflow reference is worth 17.3 times and the equal share 5.10 times.

The recorded factor inverts which rotor takes the largest span. Blocking of
0.75 times power is a 0.9086 inflow multiplier. Over one ring spacing the shear
step is about 5 per cent. So the de-rate is nearly twice the shear gain. The
lowest rotor is then the only unblocked rotor, and it reads the fastest net
inflow at 10.0864 m/s. The **middle** rotor reads the slowest at 9.6323 m/s, and
it takes the largest span.

| rotor | altitude | shear | net inflow | span at equal share |
|---|---|---|---|---|
| top | 9.400 m | 11.0000 m/s | 9.9942 m/s | 0.4494 m |
| middle | 7.261 m | 10.6018 m/s | 9.6323 m/s | 0.5000 m |
| lowest | 5.123 m | 10.0864 m/s | 10.0864 m/s | 0.4375 m |

A 15 per cent blocking gives the same ordering, by 1.3 per cent: 0.4431 m for the
middle against 0.4375 m for the lowest.

This contradicts ruling 1 of `DECISIONS.md` [2026-09-24]. That ruling expects the
lowest rotor to need the largest annulus. Its premise holds only when the wake
de-rate is smaller than the shear step over one ring spacing, which is about
9 per cent of power.

**The chord basis retires with the disc radius.** The decoder sets
`blade_chord = 0.113·r_rotor_i·blade_scale_i`, and `r_rotor_i` is the disc radius
that Task 5.2 removes. The ODE does not use that value for the main rotor. It
uses `0.113·sys.rotor.radius` (`src/ring_forces.jl:226`), and `sys.rotor.radius`
is `r_hub + 0.7·span`, the annulus OUTER radius. The two already disagree, at
0.336 m in the decoder against 0.449 m in the ODE, before any Phase 5 change.
Task 5.2 must state the chord basis, or the rotor solidity moves silently with
the span.

## 3. Rulings

**D1. RULED (Rod, 2026-09-24): the reference is the measured pair, 10.0 m/s at
4.8 m.** The Daisy rating is 1.5 kW at 10 m/s, measured at a height of 4.8 m. The
5 kW system uses that same wind, through the same shear model. So the reference
height is 4.8 m, the height of the measured mast. It is neither the 10 m
meteorological standard nor the rotor centre. The exponent is 1/7, the value the
ODE already uses.

The result is that the ODE barely moves, because the two anchors nearly coincide
at the 5 kW hub altitude.

| node | z (m) | inflow now | ODE today | change |
|---|---|---|---|---|
| Daisy rotor centre | 5.155 | 10.1025 m/s | 10.0936 m/s | +0.09 % |
| 5 kW lowest rotor | 5.123 | 10.0936 m/s | 10.0847 m/s | +0.09 % |
| 5 kW middle rotor | 7.261 | 10.6091 m/s | 10.5998 m/s | +0.09 % |
| 5 kW hub, top rotor | 9.400 | 11.0077 m/s | 10.9980 m/s | +0.09 % |

The two profiles differ by one constant offset of 0.07 per cent, so the ODE gains
0.09 per cent in speed and 0.26 per cent in power at the hub. The 5 kW rung is
preserved, and the number 11 m/s in `params_5kw_188` was already the hub
translation of the measured 10 m/s at 4.8 m. The defect was never the ODE. It was
the decoder, which references 50 m and reads 8.6637 m/s at the hub. That is 1.2706
times low in speed, and 2.051 times low in power.

Two consequences go to the re-baseline.

1. The Daisy rotor centre now reads 10.1025 m/s. `params_daisy` asserts 11.0 m/s
   at that height, a power ratio of 0.7746. At the recorded system Cp of 0.15 to
   0.18 and the recorded annulus of 10.8 to 11.2 m², 10.1025 m/s yields 1023 to
   1273 W. The published rating is 1.5 kW at 10 m/s. The two do not reconcile.
   The rating needs about 10.9 m/s at 4.8 m for 1.5 kW at the recorded Cp and
   area. So either the rated wind was nearer 11 m/s, or the rated power was
   nearer 1.27 kW, or the rated rotor was larger or cleaner than the record
   states. This is a Daisy-anchor question for the record, and it is not in the
   critical path of T1 to T5.
2. The ladder's absolute scale follows the anchor power. A move from 1.5 kW to
   1.27 kW grows every rung's length by `(1.5/1.27)^(1/2) = 1.0868` (+8.7 per
   cent; rung mass ×1.252) — the ladder's own law is P^(1/2) on length
   (`mass_scale`, `src/parameters.jl:601`; AeroDyn-confirmed), not the P^(1/3)
   form the earlier `1.0571` figure assumed. Corrected 2026-10-07 at the tip
   `c657c76`: aero-validator's read, software-worker/software-validator
   receipts; nothing in code read `1.0571`. Measure it at T7, do not assert it
   now.

Pin the reference to 4.8 m AFTER `mass_scale`, in the same way as the rest of the
wind block. See T1.

**D2. RULED (Rod, 2026-09-24): equal share, and de-rate only a rotor that has a
rotor below it.** The code already does the second half. `wind_factor_i = i < n_active ? blocking_factor : 1.0` at `src/objective_v10.jl:350`, with the rotors
ordered top to bottom, gives the top two of three the de-rate and the lowest
none. `test/test_wind_blocking.jl:45` pins it as `[BF, BF, 1.0]`. So D2 changes
one thing only: the default power share.

One consequence needs recording. With equal share and the accepted de-rate, the
**middle** rotor takes the largest span, at 0.5000 m. The lowest takes the
smallest, at 0.4375 m. With NO de-rate the order is the one Rod expects: lowest
0.4375 m, middle 0.3784 m, top 0.3398 m. So the ruling of 2026-09-24 survives in
its structural half, because the lowest rotor still carries the column above it
and its ring still needs the stiffness. Its blade-size half does not survive.
The de-rate is what inverts the order, and the record now says so.

**D3. RULED (Rod, 2026-09-24): the chord is constant along the span.** Straight
leading and trailing edges, one chord per rotor. The code already assumes this,
because `RotorSpecV10` carries a single `blade_chord` value.

Rod then asked whether a law is needed at all, and whether the BEM can price a
solidity change and a span/chord change. The code answers that. `cp_bem(n_lines,
tsr)` (`src/bem.jl:61`) takes no chord and no solidity argument. Solidity enters
only as a proxy for blade count, `(5.0/n_lines)^0.7` (`src/bem.jl:75`), and
`src/bem.jl:18` flags that exponent as a PLACEHOLDER. So the modelled power does
not change with the chord, at any blade count. The BEM surface cannot price
solidity. Rod's suspicion is correct, and the ledger now records it as C8.

The chord therefore settles three things, and none of them is the power claim:

1. the banked expansion rotors' lift and drag, through `er.blade_chord`;
2. the reverse-rotation drag at `src/ring_forces.jl:226`;
3. the geometry the record reports, and the solidity a builder would measure.

Decision: set the chord from the measured Daisy blade, at `c = 0.2702 · span`.
The record holds solidity 7.5 per cent, 3 blades, span 1.000 m and annulus
10.8071 m² (config 8). Those give 0.2702 m at the anchor. It is the only law
consistent with the measured mass law, 0.420 kg at span 1.0 m rising as span
cubed, because a cube law needs the blade cross-section to shrink with the span.

| law | anchor, span 1.0 m | island 1 top rotor, span 0.4494 m | solidity there |
|---|---|---|---|
| chord proportional to span, chosen | 0.2702 m | 0.1214 m | 2.15 per cent |
| chord near constant, the code today | 0.2509 m | 0.3304 m | 5.84 per cent |
| chord from held solidity, 7.5 per cent | 0.2702 m | 0.4224 m | 7.50 per cent |

The last row holds the rotor's solidity and makes the chord nearly independent of
the span. The first row holds the measured blade's shape. Only the first row
agrees with the mass model.

Consequence to report honestly: the corrected sizing lands the machine at 2.15 per
cent solidity, with a 0.4494 m span and a 0.1214 m chord. Nothing in the present
model confirms or refutes that number, because the Cp surface cannot see solidity.
The remedy is an AeroDyn BEM sweep over solidity. It is task T10, and it is not in
the critical path.

**D4. EXPLAINED, then RULED (Rod, 2026-09-24): the retirement needs its own long
work plan, and it lands after this workstream.** Until 2026-08-22 the code
refused to let the topmost rotor carry banked blades, because one bug modelled the
same annulus twice, as a `cp`/`ct` disc and as an expansion rotor. The recorded
fix is "replace, not exclude": when the topmost rotor carries banked blades, the
banked model replaces the disc model at that ring. Rod ruled the exclusion retired
on 2026-09-24, in `DECISIONS.md` and in `docs/agents/physics-topology.md` section
4. The code still enforces it in three places, and all three are silent no-ops:
`src/builders_util.jl:91` and `:297` (`rotor.ring_idx == n_rings && continue`),
and `src/ring_forces.jl:261` (`er.ring_idx == hub_ri && continue`). A fourth site,
`expansion_airborne_mass`, books the main rotor plus the expansion assemblies, so
a banked top rotor would be charged twice. The effect today is that the optimiser
cannot express a machine whose topmost rotor is banked.

The plan is `docs/plans/2026-09-24-banked-topmost-rotor.md`. It lands after the
re-baseline of this workstream, because it is a physics change with its own tests
and its own acceptance run, and it touches the same decode path.

## 4. The guard text in the handover is wrong

Task 5.4 of the handover asks for a test that total blade mass satisfies Peter
Jamieson scaling, `M_multi < M_single`. A guard on `1/√N` pins the wrong law. A
guard on `1/N²` pins a limit that the real machine does not reach. Measured:

| fixture | condition | ratio |
|---|---|---|
| fixed ring, freestream 11 m/s | N=1 1.1616 kg to N=3 0.1483 kg | 0.128, the small-span limit |
| same ring, N=3 at real altitudes and de-rate | 0.3774 kg to N=1 1.1616 kg | 0.325 |
| the disc law of Jamieson, for comparison | `1/√3` | 0.577 |

The guard must hold two statements. First, total swept area is invariant in N.
Second, total blade mass falls faster than `1/√N` on a fixed fixture. The `1/N²`
figure is a small-span limit and belongs in a comment, not in an assertion.
Island 1 against island 3 is not evidence. The two machines differ in ring
radius, ring count and altitude placement, and the record already retires that
comparison.

## 5. Tasks

Order is dependency order. Tasks T1 and T3 are one commit each. T2 is a test
consequence of T3. T4 uses the chord law that D3 settles. T5 guards T1 to T4. T10
is a follow-on and not in the critical path.

**T1. Adopt the measured Daisy reference, 10.0 m/s at 4.8 m (D1). LANDED.**

*As built, and why the design differs from the plan's first draft.* The draft said
pin `h_ref` to 4.8 m. That breaks fifteen consumers: `p.v_wind_ref` means "the wind
at this machine's rotor" at `src/initialization.jl:172`, `:914`, `:976`, `:1279`,
`:1300`, `:1568`, `:1846`, `:2215`, `:2517`, and in the dashboard and the
visualiser. Pinning the height would have made every steady estimate read 10.0
where the model runs 11.0, a silent 9 per cent change.

The as-built design keeps ONE standard and changes no consumer's meaning:

    p.v_wind_ref == site_wind(p.h_ref)

`p.h_ref` stays the machine's rotor altitude, and `p.v_wind_ref` becomes the SITE
profile at that altitude. The pair is the standard re-expressed, the ODE's wind
function reads the standard exactly, and `test/test_bem_unified.jl` pins the
identity for every params factory. That test is the anti-drift guard: a factory
that keeps its own reference wind fails it.

What landed:

- `src/wind_profile.jl` gains the standard: `WIND_REF_MS = 10.0`,
  `WIND_REF_HEIGHT_M = 4.8`, `WIND_SHEAR_EXP = 1/7`, and `site_wind(h)`.
  The file already owned `wind_at_altitude`, with the correct 1/7 default, so the
  SHAPE did not need a new home.
- The decoder's private profile, `wind_speed_at_ring` (h_ref 50 m, exponent 0.14),
  is RETIRED. The decoder calls `wind_at_altitude(v_rated, p.h_ref, ring_altitude)`,
  the same function the ODE calls. Its export is removed.
- `wind_at_altitude` replaces the two inline ODE profiles,
  `src/objective_evaluator.jl:587` and `src/objective_evaluator_ramp.jl:79`.
  `const WIND_MS = 11.0` is retired.
- The `v_rated` kwarg default is `p.v_wind_ref`, in all three sites of
  `src/objective_v10.jl`. The dead `hub_altitude` local in the decode loop is deleted.
- Four params sites derive from the standard: `params_10kw` and `params_daisy`
  (their literal hub altitudes), plus the two scaling paths, `params_v6_50kw` and
  `mass_scale`. The remaining factories copy from those, so the guard covers them.

Measured movement, from the test run:

| params | declared before | now | hub, rotor altitude |
|---|---|---|---|
| `params_daisy` | 11.0 | 10.1025 | 5.155 m |
| 5 kW rung, `mass_scale(daisy,1.5,5.0)` | 11.0 | 11.0097 | 9.4117 m |
| `params_10kw` | 11.0 | 11.7677 | 15.0 m |
| `params_50kw` | 11.0 | 13.2014 | 27.4 m |
| `params_v6_50kw` | 11.0 | 12.7051 | 24.2 m |
| decoder at the 5 kW hub | 8.6637 | 11.0077 | 9.400 m |

The 5 kW campaign rung moves 0.09 per cent. The Daisy moves 8.9 per cent, which is
the anchor conflict D1 records. The taller rungs gain wind, which is the ruling's
intent: length is a power axis now. T7 measures the real effect on each rung.

Remainders, both recorded and neither in T1's critical path:

1. About 35 callers pass `v_rated=11.0` explicitly, 30 of them historical study
   scripts. Under D1 the value should be `p.v_wind_ref`. The live campaign path is
   `test/settle_case_builders.jl:51`. T3 touches the same files, so fold it in there.
2. Four files still write the profile inline: `src/sim_runner.jl:115-143`,
   `src/visualization.jl:675-690`, `src/control_map_hunt.jl:93,153,284`, and the
   study scripts, which declare a local `WIND_MS`. They keep their own reference
   speed on purpose, so they only need the shared function for the exponent.

- Verify: `scripts/ktd-test-one test_bem_unified`.

**T2. Cover the single-rotor case with a test. LANDED** (with T3 — the law and its guard are one change).

**T3. Retire the power split. LANDED.**

*As built, and where it departs from the plan.* The plan said "keep `power_split`
as a knob for declared departures only". That leaves a retired knob as an accepted
argument, and an accepted argument that changes nothing is a **silent no-op** — the
`physics-topology.md` section 6 pattern the trust log calls the worst form, because
the caller reads as connected. So the knob is REMOVED, not re-defaulted: the field,
the kwarg on all three decoder entries, and the legacy `x[15]` probe.

Equal share is now the only law, `P_i = power_W / n_active`, in the decode loop.

The `x[15]` probe was also a **duplicate representation**: `x[15]` is the legacy
`log10(k_mppt)` slot everywhere else in the repo (`src/objective_v11.jl:13`), so a
legacy 15-D genome had its `k_mppt` slot silently reinterpreted as a top-rotor
power fraction, clamped to 0.2-0.8. The retirement closes that as well.

Call sites updated: 17 in `test/`, 13 in `scripts/`. `scripts/sweep_power_split.jl`
is DELETED — its whole subject is the retired knob, and its header told the operator
to pick a value and write it into four other files. Git history keeps it.
`scripts/run_v13_5kw_masslift.jl` prints equal share in its provenance block now.

The de-rate rule is untouched (D2), and the decoder's comment for it still says
"wind flows UP the shaft (hub is downwind)" as `:341-348` did. Correcting that
wording is not this task's; it is a separate claim about the flow direction.

- Test: `test/test_builders_v10.jl`, testset "equal power share per rotor (D2)".
  It observes the share as `(r_rotor · v_wind^1.5)²`, which is proportional to the
  rotor's power with one machine-wide constant, so equality of that quantity IS
  equality of the share. The retired 0.6 law reads ×3 on the top rotor, so the test
  fails loudly on it. It also pins the separation: less wind means a LARGER rotor at
  the same power, the de-rate lands on `[BF, BF, 1.0]`, and a 15-D genome's `x[15]`
  no longer reaches the rotor specs.
- Verify: `scripts/ktd-test-one test_builders_v10` — PASS.

**T4. Solve the span from the ring annulus, and set the chord from D3. LANDED.**

*As built.* `BEM.annulus_span_for_power` already existed (`src/bem.jl`), so the task
was to USE it rather than write it. The decoder now solves the swept annulus of the
rotor's OWN ring for that rotor's own power at its own post-blocking wind:

    r_ring_i = radii[pos]
    span = BEM.annulus_span_for_power(P_i, v_i, r_ring_i, design.n_lines; bank_deg=bank_i) * blade_scale_i

`blade_scale_i` stays as a declared departure from the power-required span, which is
what a blade-size gene means. The comment block that defended the disc magnitude is
DELETED and the annulus law is recorded in its place.

The chord now has ONE home, `BEM.blade_chord_for_span(span) = 0.2702 · span`, called
by the decoder AND by `src/ring_forces.jl`'s reverse-drag branch (was
`0.113·sys.rotor.radius`). The two had drifted: the decoder's `0.113·r_disc` gave
0.336 m on the 5 kW seed where the ODE's gave 0.449 m.

A naming fault found while pinning the test, recorded not fixed: the field
`RotorSpecV10.blade_tip_radius` holds the OFFSET `0.7·span`, not an absolute radius,
and `blade_hub_radius` is the NEGATIVE inboard offset. `lowest_rotor_clearance` adds
the ring radius back, which is why its docstring says "the tip is the ABSOLUTE radius
(r_ring + tip)". Reading the offset as absolute over-counts clearance by the ring
radius — the 2026-08-24 settle-ω-scan fault class. A rename to `blade_tip_offset` is
a follow-on, because it touches every construction site.

- Test: `test/test_builders_v10.jl`, testset "annulus span and the one chord law".
  Pins the area identity to 1e-6 relative per rotor, the 70/30 offsets, the chord
  law, and the hand-off: `sys.rotor.radius == r_ring + 0.7·span` and
  `main_rotor_swept_area(sys)` EQUALS the decoder's annulus, so no disc/annulus
  mismatch survives the build.
- Verify: `scripts/ktd-test-one test_builders_v10` — PASS.

**T5. Land the guards. LANDED.**

The testset is renamed to "Ring annulus BEM sizing — the recorded law, not 1/√N".
Jamieson's `1/√N` is the DISC law; the recorded law for ring-anchored blades is
nearer `1/N²`. Three guards added:

- **Area invariance in N**, on ONE ring radius so the geometry cannot confound it.
  N rotors at P/N sweep the same total area as one rotor at P, to within the 70/30
  quadratic term (asserted < 2 %).
- **The mass-law CHOICE**, not a rounded constant. Measured on this ring:
  0.27690 at N=2, 0.12764 at N=3, 0.07315 at N=4, which is +11 %, +15 % and +17 %
  over `1/N²`. N=3 reproduces the recorded island-1 figure of 0.128. The assertion
  is that the ratio lies nearer `1/N²` than `1/√N` and strictly below the disc bound.
- **A STATIC guard**: no decode path may size a span from the disc radius. It scans
  the three decode sources for a non-comment line that names both `span` and
  `rotor_radius_for_power`, and asserts the annulus solve and the chord helper are
  present. A reintroduction of `span = 0.75·r_rotor_i` fails at the change, not
  three tasks later.
- **The single-rotor full-power rule**: one rotor takes the WHOLE power. The decode
  of a 1-rotor genome is asserted against `A = P/(Cp·½ρ·v³)` and the chord law.
- Verify: `scripts/ktd-test-one test_bem_unified` — PASS.

**T6. Repair the two reporting defects. LANDED.**

The provenance named `blocking_factor=1.0` while the cfg used `0.9086` — the
co-axial de-rate. The same line named `cone_slope_deg=22.0` and
`rotor_spacing_frac=0.8` as literals, and the cfg held its own copies, so the
record and the run could drift apart in silence.

*As built.* The two knobs became consts (`CONE_SLOPE_DEG`, `ROTOR_SPACING_FRAC`)
that BOTH the cfg and the provenance read, and the line interpolates
`BLOCKING_WIND_FACTOR_5KW` and `V_RATED` rather than naming a value. One home per
knob, and the record cannot name a number the run did not use.

**T7. Re-baseline and verify. OPENED 2026-09-25 — first finding was a DEFECT, not
a moved number.**

The first red examined was `test_beam_sizing_closed_form.jl:161`,
`N_comp_per_ring[2] > 0.0` evaluating `0.0 > 0.0`. It was NOT a moved measured
number and NOT a re-baseline candidate: the beam-sizing path was turning a failed
equilibrium solve into a silent `ω = 0` and sizing the machine as STOPPED. See
the trust log, row 2026-09-25, for the mechanism and the three-part fix
(`on_missing_omega`, `r_hub_init`, `resize_hub=false`). `test_beam_sizing_closed_form.jl`
is now fully GREEN with no number re-pinned.

The rule this establishes for the rest of T7: **classify every red before touching
a number.** Three classes only — (a) a law broke: fix the code; (b) the design
point moved: re-express the assertion as a relation, or state the design point
explicitly in the test; (c) the design point is infeasible: re-seed (T8), never
re-pin. A test whose setup calls the decoder is answering "did the design change?",
not "is the physics right?", so it must not be used as a physics guard.

Remaining T7 work:
- `scripts/ktd-format`.
- Classify the remaining reds into the three classes. As of this writing:
  `test_settle_validity.jl:197` and the 14 in `test_trpt_realisability.jl` both
  raise the torsional realisability cliff — class (c), T8's re-seed.
- `scripts/ktd-julia test/acceptance_runtests.jl`. All eight files, about 18
  minutes. Mandatory, because `src/` physics changed.
- Re-gate the three islands over 120 s at `lin_damp` 0.00. Record the FoS trough,
  the hub lateral, the cone slack and the power for each.

**T8. Re-seed and re-screen.**
- The 5 kW campaign is VOID. Every size moves, so no island 1 winner transfers.
- Re-seed from `seed_genome(5.0)` and screen one genome before any matrix, per
  the standing rule in `ACTIVE.md`.

*Screen run 2026-09-25* (`scratch/probe_t8_seed_screen.jl`, fixture genome, frozen
6.901 m geometry, ω = 12.983466 rad/s, τ = 377.6 N·m):

| n_lines | max demand | worst segment | crossing | τ_carry[end] | verdict |
|---|---|---|---|---|---|
| 6 | 3.4893 | 4 | 2.2401 | 328.40 | REFUSED |
| 8 | 2.6007 | 4 | 2.2401 | 293.21 | REFUSED |
| 10 | 2.0312 | 4 | 2.2401 | 262.45 | REFUSED |
| 12 | 1.6563 | 4 | 2.2401 | 238.54 | REFUSED |
| 14 | 1.3985 | 4 | 1.4770 | 217.81 | REFUSED |
| 16 | 1.2127 | 4 | 1.4718 | 207.01 | REFUSED |

**`n_lines` ALONE CANNOT CLEAR THE CLIFF.** The demand falls about as `1/n_lines`,
and at the genome's ceiling (16) the segment still needs `sin Δα = 1.20`. The
tension in this build is low (65-70 N/line), and the ceiling scales with it. The
two remaining levers are the preload tension and the operating torque (`ω` via
`k_mppt`). Either the line count must leave [3,16], the lifter margin must rise
from its 1.5, `k_mppt` must fall, or the optimiser must combine them. DECISION
NEEDED before the re-seed.

*Grid run 2026-09-25* (`scratch/probe_t8_grid.jl`, 20 points, ring scale x L/r x
n_lines, both limits reported from the diagnostic path):

| ring scale | L/r | n_lines | demand | crossing | verdict |
|---|---|---|---|---|---|
| 1.0 | 2.0 | 6 / 12 | 3.489 / 1.656 | 2.240 | over |
| 1.0 | 1.5 | 6 / 12 | 2.739 / 1.316 | 2.772 | over |
| 1.25 | 2.0 | 6 / 12 | 2.578 / 1.603 | 2.302 | over |
| 1.25 | 1.5 | 6 / 12 | 2.406 / 1.502 | 5.418 | over |
| 1.5 | 2.0 | 6 / 12 | 2.863 / 3.271 | 1.858 / 1.500 | over |
| 1.5 | 1.5 | 6 / 12 | 2.424 / 6.878 | 12.4 | over |
| 1.75 | 2.0 | 6 / 12 | 15.742 / 2.300 | 208626 / 1.500 | over (runaway) |
| 1.75 | 1.5 | 6 / 12 | 2.335 / 0.956 | 27.7 / 1.617 | over |
| **2.0** | **2.0** | **6 / 12** | **0.745 / 0.862** | **0.717 / 0.907** | **FEASIBLE** |
| 2.0 | 1.5 | 6 / 12 | 2.673 / 1.029 | 2.803 / 3.300 | over |

**THE FEASIBLE BAND IS RING SCALE 2.0 AT L/r 2.0** — both line counts clear both
limits. It sits at the EDGE of the grid, so the band's true extent is unmeasured:
the next screen extends the scale axis upward. The response is NOT monotone
(scale 1.75 is worse than 1.5 in several cells) and several cells carry crossing
ratios in the hundreds or thousands, which are SOLVE RUNAWAYS, not designs — the
refusal added this session now makes that visible instead of silent.

**T9. Record.**
- `DECISIONS.md`: close the three sizing defects. State the corrected totals.
- `docs/agents/instrument-trust-log.md`: close the `wind_speed_at_ring` row and
  the disc-sizing row.
- `docs/agents/physics-topology.md` section 4.1: move the status from DERIVED to
  LANDED, and record rulings D1 to D3.
- Write the handover.

**T10. Follow-on: teach the Cp surface about solidity. Not in the critical path.**
- Cause: `cp_bem(n_lines, tsr)` (`src/bem.jl:61`) has no chord and no solidity
  argument, and the solidity penalty `(5.0/n_lines)^0.7` (`src/bem.jl:75`) is
  flagged as a PLACEHOLDER at `src/bem.jl:18`. The model cannot price a chord or a
  span/chord change at a fixed blade count. Ledger C8 records this.
- Task: extend the AeroDyn BEM sweep from blade count to solidity, so the Cp and
  CT tables key on solidity as well as line count. The repo holds the sweep skill
  (`aerodyn-bem`).
- Why it matters: the corrected sizing lands the machine at 2.15 per cent
  solidity (D3). No present number confirms or refutes that operating point.
- Test: reproduce the AeroDyn Cp at the baseline point, then assert a monotone Cp
  fall past the optimum solidity.
- This task can run beside T8, because it needs no ODE window.

## 6. Costs and risks

- **The re-baseline is the bulk of the work.** The decode feeds the ring
  geometry, the beam sizing and the settle. Twenty test files use the decode
  path, and fourteen of them name `power_split` or `blocking_factor`. Most assert
  relationships, so they survive. The ones that pin measured numbers need a
  deliberate pass, one at a time.
- **Do not compare the 5 kW campaign results across the change.** Record this in
  every report that cites them.
- **A lighter machine moves the ring sizing.** The closed-form beam solve reads
  the rotor mass. The hub blade mass of island 1 falls by 38.8 times, so the whole
  structural result set moves.
- **Do not let the wake factor decide the geometry.** It is unanchored. If it
  stays a sizing input, bound it and declare the bound in the provenance.

## 7. Out of scope

- The Daisy rated wind against the rated power. D1 records the conflict: 10 m/s
  at 4.8 m, and 1.5 kW at the recorded Cp and annulus, do not reconcile.
  Resolving it needs the Tulloch thesis body.
- `tether_length` as a genome gene. It stays blocked on the same anchor question.
- The top-ring exclusion retirement. It has its own plan,
  `docs/plans/2026-09-24-banked-topmost-rotor.md`, and it lands after T7.
- The duplicated `params_at_length` definitions. The trust log records the class
  on 2026-09-24. Eight copies sit in `scripts/` and one in
  `test/settle_case_builders.jl`. Fold this into T3 if the two touch the same
  call sites.
