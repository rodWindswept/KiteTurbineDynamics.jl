# Lift system — evidence base and requirements

**Purpose.** The single place to record what we know about the kite turbine's lift
system: the options, the methods, the hypotheses, the test results, the outcomes,
the conclusions, and — as it firms up — the requirements we place on a lift system
as the machine scales. Lift is safety-relevant (see *Back-line duty*), and its
specification has been re-derived more than once. This file is where that stops.

**Status.** Established 2026-09-15. Sparse by design — an entry is added when
evidence exists, not before.

## The requirement we currently hold

> The **vertical component** of lift-line tension at the sky hook is
> **1.5 × the airborne turbine mass**, and a shallower lift-line elevation raises
> the line tension as `1/sin(el)`.

Open: what the 1.5 covers (gusts, settle transient, dynamic overshoot); what it
must be **across the wind range** — the code meets it at `v_ref` only, and below
rated with `const_tension=false` the vertical falls as `(v/v_ref)²`; and the
allowable elevation band.

## Register

| # | Date | Topic | Finding | Status |
|---|---|---|---|---|
| L1 | 2026-09-15 | Elevation trade | Holding the vertical at 1.5×, tension rises as `1/sin(el)` and the sky-anchor downwind force as `cot(el)`: 70° → 50° is **+23 %** tension, **+131 %** downwind. The downwind force lands on the **cyan** line as preload; the back line is near-vertical (3.7° off, model placement) and is *relieved*, 351 → 228 N | measured |
| L2 | 2026-09-15 | Lift angle as a preload lever | Clears the torsional floor only at el ≤ 50°, band 31°–50°. Needs ≈ 20°, not "slightly" | measured |
| L3 | 2026-09-15 | Back-line spec | 3 mm Dyneema + 8 × 30 cm 4 mm bungees sewn in series; 40 cm at full tension; 80 cm of soft travel; hard at the design length | Rod |
| L4 | 2026-09-15 | Back-line stiffness | Bi-linear, `k_soft = T_design / 0.8` N/m over 0–80 cm — no extra field data needed | derived |
| L5 | 2026-09-15 | Lift-line elevation and preload | The elevation is a *preload* lever (into the cyan line), which is a different job from the 1.5× vertical requirement | measured |

## Back-line duty (safety case)

Beyond the design-point tension, the back line must:

1. **Contain the machine if the TRPT breaks** — the anchored back line is what
   stops the lift line dragging the machinery away or components flying free.
2. **Carry the machine while raising and lowering it in tension** — for
   deployment, recovery, and high-wind / high-altitude stalling.

So its design load is the worst of **{design point, hoisting, break containment,
high-wind handling}**, not the 351 N steady figure. **None of those cases is
quantified** — no break load, hoist load or dynamic factor is on the record. This
is a project-level safety item, not a detail of one design.

## Evidence files

- `scratch/taut_backline_angle_sweep.jl` — load split, elevation sweep, bungee.
- `scratch/levers_linecount_ringdensity.jl` — preload levers (lines, ring density).
- `scratch/diag_floor_mass_and_thrust.jl` — floor criterion, mass cost, thrust.

## Aspirational

- **Realisability margin vs gust transient.** The 5 % steady margin does not cover
  the wind-up transient (rotor descending as the twist engages, torque rising).
  Record the torque margin actually consumed in a gust.
- **Lift-system scaling laws.** What the requirement becomes at 1.5 kW, 5 kW and
  beyond — and whether the elevation band tightens or loosens with scale.
