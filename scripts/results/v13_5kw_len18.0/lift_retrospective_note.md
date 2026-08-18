# Lift-tension retrospective — v13_5kw_len18.0

- **Script:** scripts/lift_retrospective_v13.jl (decode era: d7e8cbd)
- **Date:** 2026-08-18T20:28:17.942
- **Question:** the first campaign applied a FIXED rotary lifter. What tension did each genome actually see, and what does the mass-aware constant-tension rule (1.5× vertical, Rod 2026-08-18) require instead?

## Winner

- m_airborne = 138.93 kg
- mass-aware constant tension T = 1.5·m·g/sin(70°) = 2175.6 N (vertical = 1.5× weight)
- rotary tension actually applied at 11 m/s = 2224.4 N
- ratio rotary/mass-aware = 1.02×

## Population summary
- rows decoded: 928 / 928
- m_airborne: 41.85 – 204.37 kg
- ratio rotary/mass-aware: 0.70 – 3.39 (median 1.38)

## Disposition

- Original campaign CSVs untouched; addendum columns in lift_tension_retrospective.csv.
- The redo (run_v13_5kw_masslift.jl) applies the constant mass-aware tension instead.
