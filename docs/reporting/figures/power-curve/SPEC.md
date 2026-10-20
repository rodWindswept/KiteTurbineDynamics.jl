# SPEC: power-curve. The winning design's scored power across a wind sweep.

**Slug** `power-curve`

**Status** SPEC v3, wind basis signed. Angle brackets ⟨⟩ mark binding slots.
This document carries no drawn value. The numbers register supplies the
citation discipline.

**Owner** @figures-images-diagrams. **Content check** @aero-validator on
physics, era and axis, and @science-validator on the numbers.
**Reader-facing layer** @author: the caption and the slotting.

**Contracts** the reporting framework (SPEC, GENERATE, CHECK, the rounds,
the dual captions). The numbers register (the firewall). The one-era rule.

## Why this exists

The founder ruled it in the room on 2026-10-20: "if we could get a power
curve figure developed, testing the winner response across a few
different winds .. that would be an incredibly valuable figure to print."

It is the only plate in the set that tests a machine outside its design
point. Every other plate reads one evaluation at one wind. This one reads
the same design at several winds.

It is **not** a rating curve and **not** a manufacturer curve. It is one
fixed design under a declared gain bracket, scored at each sweep wind.

## The wind problem. Three winds exist in the harness today.

A sweep cannot start until they are collapsed to one. Measured at
`914be4e`:

| field | what it is | 5 kW box (this winner) | 10 kW box | 50 kW box |
|---|---|---|---|---|
| `p.h_ref` | hub altitude | 9.4117 m | 15.000 m | 33.541 m |
| `p.v_wind_ref` | site wind at the hub, drives the aerodynamics and the forcing | 11.0097 m/s | 11.7677 m/s | 13.2014 m/s |
| `cfg.v_rated` | config constant, default 11.0, sets the Betz ceiling, the floor and the k bracket | 11.0 m/s | 11.0 m/s | 11.0 m/s |
| forcing ÷ ceiling, in power | (v_wind_ref / v_rated)³ | 1.003 | 1.224 | 1.729 |

`evaluate_design` defaults `v_rated` to 11.0 and takes no value from the
machine own site wind. So the ceiling sits at a wind that matches neither
box, and the two big boxes fly 1.4336 m/s apart, a factor of 1.1218. This
winner is the exception. Its hub wind is 0.09 per cent above the ceiling
wind, so the mismatch is a 10 kW and 50 kW concern and not a reading on
this plate. The ceiling question is with @science-validator and
@aero-validator. Contract 2 carries their ruling.

## Binding contracts

1. **Axis.** The x-axis is the wind at the winner hub altitude, in m/s.
   The plate sweeps `p.v_wind_ref` directly, so no conversion is applied.
   For this winner the hub sits at 9.4117 m and the reference wind is
   11.0097 m/s. That value is `site_wind` of the altitude under SITE_DAISY
   (10.0 m/s at 4.8 m, exponent 1/7), carried through `mass_scale`. The
   axis label names the altitude and the value.

2. **One field. ⟨signed: @science-validator, @aero-validator, 2026-10-20⟩**
   The swept field is `p.v_wind_ref`. `cfg.v_rated` holds at 11.0, because
   it is part of the machine and not part of the wind.
   `design_from_vector_v10` takes `v_rated`, and `size_beams_closed_form`
   reads it. A decode of the fixed genome at five rated winds prints five
   different masses:

   | `cfg.v_rated` | decoded mass | against 11.0 |
   |---|---|---|
   | 9.0 | 34.5650 kg | +8.8665 kg |
   | 10.0 | 28.7999 kg | +3.1014 kg |
   | 11.0 | 25.6985 kg | 0 |
   | 12.0 | 23.4864 kg | −2.2121 kg |
   | 13.0 | 23.5694 kg | −2.1291 kg |

   So the two-field basis, which this document first carried, prints a
   different machine at each of the sixteen winds. It contradicts contract
   4 and it cannot draw one design. The mass is not monotone in the
   rating: 12.0 is the minimum and 13.0 is 0.0831 kg heavier. Five
   different machines is the claim, and no direction rule follows from it.
   The mass column of the sweep CSV is the check: it prints
   25.698468 kg on every row.

3. **Controller: one fixed gain.** Every point is scored at
   `K_MPPT_5KW_HONEST` = 2.24, the campaign's own gain
   (`scripts/compute_seeds.jl:36`). `evaluate_windowed` applies no bracket,
   and the identity row matches the recorded score to 11 decimal places at
   that gain, so the run sits on the campaign controller. A best-of-three
   bracket would re-tune the controller at every wind, which is the
   machine-moved defect at the controller level. The caption names the gain
   in one clause.

4. **Fixed design.** The genome is ⟨the campaign winner at the declared
   stamp⟩ and does not move across the sweep. A genome that adapts per
   wind is a different figure.

5. **One base.** The genome params base is declared in the header and
   printed in the label. Three bases are measured, and they give a
   different hub altitude and a different reference wind:

   | base | route | `h_ref` | `v_wind_ref` |
   |---|---|---|---|
   | cartography | `params_10kw()` | 15.00 m | 11.7677 m/s |
   | ladder | the 1.5 kW Daisy anchor, scaled | 13.31 m | 11.5685 m/s |
   | 5 kW masslift | `params_daisy()` at L 18.8 m, `mass_scale` 1.5 to 5 kW | 9.4117 m | 11.0097 m/s |

   The first two rows are 10 kW routes. This winner is the third row.
   The label names the base, or two reference winds print in one report
   as one.

6. **Settle repeat.** Two points run twice from the same genome and the
   same wind: the identity wind and 13.5 m/s. Both scores print. The
   tolerance is 0.000001 kW. A spread larger than that means the plate
   carries no point value at all.

   Measured on 2026-10-20: both repeats print identical values at the six
   decimals the CSV records, so both spreads read 0.000000 kW. The repeat
   certifies determinism, and that is all it certifies. It cannot measure
   settle sensitivity, because that responds to a different input: at
   `caceb84` a 4 cm change of hub radius at a fixed ring count moved
   scored power 52 per cent. The caption rests the design-point claim on
   flatness instead. 11.0 scores 27.3181 against 27.3635 at the design
   point, so 11.0097 is not an optimum on these numbers.

## The drawing

- Wind is a metric axis, so a polyline through the evaluated points is
  admissible. This is the opposite of the ordinal panel strip, where a
  line was banned as a rate drawn where no rate exists.
- Nothing is drawn between or beyond evaluated points. No fit, no smooth
  curve, no dashed extrapolation past the sweep ends.
- Each point is a marker. Each marker prints its scored power to two
  decimals, the recorded precision. The drawn column is `P_end_kW`, the
  `:tail5` statistic the score reads. `P_mean_kW` prints in the caption.
  Two decimals are needed because the 11.0 and 11.0097 points differ only
  in the second one.
- The 5.0 kW floor draws as a horizontal line. It is a declared
  constraint with a row behind it.
- The Betz ceiling at the winner's swept area draws only if
  @science-validator signs a row for each swept wind. Without those rows
  the plate carries no ceiling line.
- No slope numeral, and no "cut-in", "rated" or "cut-out" wording. The
  sweep has ends, not features.

**Sweep** ⟨hub wind 6.5 to 13.5 m/s in 0.5 steps, plus the identity point
at 11.0097 m/s⟩. The ends are chosen and the caption says so. The plate
must not read them as machine limits. On the run of 2026-10-20 the top
point passes at FoS 10.55 and twist 0.443, so no gate bounds it. The low
end is the honest floor reject, which keeps its measured power. The
earlier draft read seven points on the site reference, 6.0 to 16.0 m/s.
That range converts to 6.6 to 17.6 m/s at this hub, and no part of it
was run.

## What it may not print

- A single power value as "the power at N m/s" without the gain-bracket
  clause.
- Any power above the Betz ceiling at that wind and that swept area.
- Any mass value. This plate carries no mass.

## Inputs. The record contract.

- The winner genome, read from ⟨the campaign results file⟩ at the
  declared stamp.
- The site spec: SITE_DAISY, named once, with its three constants.
- One CSV per sweep, one row per wind: the wind, the status, `P_end_kW`
  with `P_mean_kW`, `FoS_min`, `twist_ratio`, `T_lift_N`, the mass, and
  the fields that close the chain: `v_rated` 11.0, `h_ref_m` 9.411699,
  `k_mppt` 2.24 and a per-row genome hash.
- The header carries the repo commit, the `src` tree hash, the probe md5
  and the three SITE_DAISY constants: 10.0 m/s at 4.8 m, exponent 1/7.
  Without these the checks below cannot be asserted from the file.
- No value prints without an NR row. The numbers seat derives the rows
  from the CSV, never from this document.

## Checks at the gate

1. One row per swept wind, each `:ok` or named as rejected, with the
   status split printed beside the count.
2. `p.h_ref` identical at every point, and `mass_kg` identical to the
   winner mass. A moved mass means the machine moved.
3. `cfg.v_rated` constant at 11.0 across the sweep.
4. Every produced power sits below the Betz ceiling at its own wind and
   that swept area. A ceiling held at 11.0 is not a bound on a point flown
   at 13.5, where the available power is 1.85 times the 11 m/s value.
5. The winner genome identical at every point.
6. A below-floor reject keeps its measured power. A gate reject carries
   none, and the plate does not draw a number for it.
7. Every printed digit on an NR row.

## What this plate can and cannot expose

The sweep holds one machine at one hub altitude. It cannot measure the
cross-box wind gain, because no box moves. That reading belongs to a
mass-scale comparison, where `mass_scale` grows the hub by √5 and the
site profile hands the bigger machine 1.1218 times the wind, which is
1.41 times the available power. This plate measures one machine against
its own gate. If a caption claims the scale effect here, it claims a
reading the sweep cannot produce.
