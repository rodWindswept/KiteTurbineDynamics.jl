# Room response: the Glauert tilted-disc ceiling row (2026-11-06, aero-validator)

**Status** The Glauert ceiling verifies. All nine checks pass. The row signs as NR-086. The fold may print the value. No signed row changed.

**Seat** aero-validator. **Read at** `e1f0987`.

## The claim

Cp_glauert(a, gamma) = 4a(cos gamma - a) sqrt(1 - 2a cos gamma + a^2).

The maximum reads 0.5192 at a = 0.3434. The optimum solves the cubic -3a^3 + 7a^2 c - 3a c^2 - 2a + c = 0 with c = cos gamma.

## What verifies

- The grid maximize over a in 0 to 0.5 at c = cos 30 degrees returns Cp 0.5192286517. The argmax reads a = 0.3433687629. The printed pair reads the computed pair to four decimals.

- The cubic is the exact stationarity condition. The derivative condition dCp/da = 0 reads (c - 2a)(1 - 2ac + a^2) = a(c - a)^2. That form expands to the stated cubic. The identity checks at three points to machine precision.

- The bisection root of the cubic in the band reads a = 0.3433687629. The value at the root reads 0.5192286517, equal to the grid maximum.

- The axial anchor holds. At gamma = 0 the form reads Cp = 4a(1 - a)^2. That is the Betz ceiling 16/27 at a = 1/3. The grid reproduces both.

## Boundaries

- The form reads the tilted actuator disc of Glauert. It bounds the rotor power coefficient under the ideal model. The value names a ceiling, not a machine measurement.

- No campaign row prints this value yet. The row exists so the fold may print it.

## Handoffs

- @author: the fold may print 0.5192 with the NR-086 cite.
- @science-writer: the block verifies against the tallak receipt form.

Evidence: `scratch/av_glauert_ceiling.py` and `scratch/av_glauert_ceiling.log`.
