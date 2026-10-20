# SPEC: power-curve. The winning design's scored power across a wind sweep.

**Slug** `power-curve`

**Status** SPEC v1, first issue. Angle brackets ⟨⟩ mark binding slots.
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

| field | what it is | 10 kW box | 50 kW box |
|---|---|---|---|
| `p.h_ref` | hub altitude | 15.000 m | 33.541 m |
| `p.v_wind_ref` | site wind at the hub, drives the aerodynamics and the forcing | 11.7677 m/s | 13.2014 m/s |
| `cfg.v_rated` | config constant, default 11.0, sets the Betz ceiling, the floor and the k bracket | 11.0 m/s | 11.0 m/s |
| forcing ÷ ceiling, in power | (v_wind_ref / v_rated)³ | 1.224 | 1.729 |

`evaluate_design` defaults `v_rated` to 11.0 and takes no value from the
machine's own site wind. So the ceiling sits at a wind that matches
neither box, and the two boxes fly at winds 1.1218 apart. The ceiling
question is with @science-validator and @aero-validator. This SPEC does
not depend on their ruling, because it sets both fields at every point.

## Binding contracts

1. **Axis.** The x-axis is the wind at the winner's own hub altitude, in
   m/s. The swept variable is the site reference wind. The plate converts
   it to the hub wind with the anchor site profile (SITE_DAISY: 10.0 m/s
   at 4.8 m, Hellmann exponent 1/7). The axis label names the hub
   altitude and the shear.

2. **One wind, two fields.** At every point, `p.v_wind_ref` equals
   `site_wind(p.h_ref)` from that site spec, **and** `cfg.v_rated` equals
   the same value. A point that moves one field and not the other is not
   admissible, because its Betz ceiling and its forcing then disagree.

3. **Controller.** The gain is not fixed. `with_k_bracket` scores the
   genome at k̂·{0.5, 1, 2} and keeps the best accepting evaluation, so
   each point is the best of three gains. The caption says this in one
   clause. A curve drawn from one fixed gain is admissible only as a
   separate series with its own label.

4. **Fixed design.** The genome is ⟨the campaign winner at the declared
   stamp⟩ and does not move across the sweep. A genome that adapts per
   wind is a different figure.

## The drawing

- Wind is a metric axis, so a polyline through the evaluated points is
  admissible. This is the opposite of the ordinal panel strip, where a
  line was banned as a rate drawn where no rate exists.
- Nothing is drawn between or beyond evaluated points. No fit, no smooth
  curve, no dashed extrapolation past the sweep ends.
- Each point is a marker. Each marker prints its scored power to one
  decimal.
- The 5.0 kW floor draws as a horizontal line. It is a declared
  constraint with a row behind it.
- The Betz ceiling at the winner's swept area draws only if
  @science-validator signs a row for each swept wind. Without those rows
  the plate carries no ceiling line.
- No slope numeral, and no "cut-in", "rated" or "cut-out" wording. The
  sweep has ends, not features.

**Sweep** ⟨7 points, site reference 6.0 to 16.0 m/s⟩, chosen to bracket
the design point of 10.0 m/s at 4.8 m.

## What it may not print

- A single power value as "the power at N m/s" without the gain-bracket
  clause.
- Any power above the Betz ceiling at that wind and that swept area.
- Any mass value. This plate carries no mass.

## Inputs. The record contract.

- The winner genome, read from ⟨the campaign results file⟩ at the
  declared stamp.
- The site spec: SITE_DAISY, named once, with its three constants.
- One CSV per sweep: wind, scored power, gain used, status, plus a header
  carrying the commit, the harness md5 and the site constants.
- No value prints without an NR row. The numbers seat derives the rows
  from the CSV, never from this document.

## Checks at the gate

1. Seven points, seven statuses, each `:ok` or named as rejected.
2. `v_wind_ref == site_wind(h_ref)` at every point.
3. `cfg.v_rated == v_wind_ref` at every point.
4. Every scored power below the Betz ceiling for its wind and area.
5. The winner genome identical at every point.
6. Every printed digit on an NR row.

## What this plate is expected to expose

The two cartography boxes already fly at different winds, because
`mass_scale` grows the hub altitude by √5 and the site profile then hands
the bigger machine 1.1218 times the wind — 1.41 times the available
power. If that holds on this sweep, the caption must say it: a bigger
machine of this family flies higher and reads more wind. The plate is the
instrument that measures the effect instead of asserting it.
