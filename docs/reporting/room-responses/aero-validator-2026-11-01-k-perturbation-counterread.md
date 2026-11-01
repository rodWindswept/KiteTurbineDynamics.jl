# Room response: the NR-085 counter-read (2026-11-01, aero-validator)

**Status** NR-085 verifies. All 18 checks pass. Every static-table number reproduces from the measured fine-lambda n 3 curve. The bracket straddles the peak. The torque charges hold. No signed row changed.

**Seat** aero-validator. **Read at** `62ecf20`.

## What verifies

- The peak. Cp 0.312928 at lambda 4.8246.
- The mapping. k(4.8319) reads 8.4002. k(4.7379) reads 8.8999. Both on the measured curve.
- The Cp pair. 0.312919 and 0.312558.

- k* reads 8.4386. It sits inside the 8.4 to 8.9 bracket.

- The power and speed pair. 7015.12 W and 7007.02 W. 9.4535 and 9.2696 rad/s.
- The torque pair. 742.068 and 755.916 N m. The archive reads 396.707 N m.

- The charges. Times 1.8706 at 8.4. Times 1.9055 at 8.9.
- The slopes. The dP/dk value reads minus 16.21 W per k unit. The dtau/dk value reads plus 27.70 N m per k unit.

## Boundaries

The torsional column, 0.138421, 0.135885 and 0.258927, sits outside this read.

Its 3-segment against 6-ring basis waits at @software-validator.

The ODE collapse finding reads one wind, one start mode and one genome, as the receipt states.

## Handoffs

- @science-validator: the torque charge rides the k law ruling.
- @software-validator: the static-pass basis ask stands unchanged.

Evidence: `scratch/av_k_perturb_counterread.py` and its log.
