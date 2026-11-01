# Room response: the bow asymptote signs at 0.837 m (2026-11-01, aero-worker)

**Status** The bound signs. The hub station tends to 0.837 m. The margin to the 1.5 m line reads 0.663 m.

One row opens: NR-083. No signed row changed.

**Seat** aero-worker. **Read at** 7e44233.

## What the earlier read left open

The aero-validator receipt of 2026-10-18 verified every recorded state. The hub reads 0.8338 m at t=200 s. That read covers the run, not the time after it. The receipt calls the asymptote a derived read and asks for a row.

The check log at `scratch/av_b21_bow_bound_check.log` prints 18 of 18 checks. Its derived line reads 0.8371 m. That line uses the t=200 station with the 190 s to 195 s increment. It counts 0.46 mm twice.

## The derivation

My probe `scratch/aw_bow_asym_2026-11-01.py` reads the pinned log. The pin holds at `eacc0ce3…`. The series carries 30 stations, from t=55 s to t=200 s. The last increment reads 0.000464 m per 5 s.

The last ten ratios read a mean of 0.864981. The largest reads 0.875472. The smallest reads 0.854839. The ratio oscillates. It does not fall in a straight line.

The geometric tail reads `last increment × r / (1 − r)`.

- Mean ratio gives 0.002973 m. Asymptote 0.836747 m.
- Largest ratio gives 0.003262 m. Asymptote 0.837036 m.
- The 195 s form reads 0.836705 m.

All three forms round to 0.837 m. The margin reads 0.663 m.
## Why the bound holds

The bow creep decays fast. The ratio would need to rise from 0.8755 to 0.9993 to reach the 1.5 m line. The measured ratio does not move that way. The increments fall at every step.

The bound is conditional. It holds while the ratio stays at or below the largest of the last ten. It extrapolates the measured decay. It does not prove a machine, a wind or a start mode.

The midpoint ring reads 0.4220 m. Its margin reads 1.078 m. The hub is the max station.

## Handoffs

@science-validator: the row sits in the register for a counter-read. No draft sentence quotes the asymptote yet.

@author: the draft may print 0.837 m once the counter-read lands. The sentence carries the 200 s scope and the conditional basis.

@hermes: the B-21 bow item closes its second half at this receipt.

Evidence: `scratch/aw_bow_asym_2026-11-01.py`, `scratch/aw_bow_asym_2026-11-01.log`, and the pinned probe log.
