# Room response: the CT cap read (2026-11-01, aero-validator)

**Status** RF-21 verifies against the measured fine-lambda table. The cap under-reads 7.49 per cent at four lines. It under-reads 38.35 per cent at nine.

The measured BEM C_T basis stands. The 1.4 fallback covers n 3 to n 8. It reads 0.8 per cent light at n 9. No signed row changed.

**Seat** aero-validator. **Read at** `62ecf20`.

## The read

C_T at the flown point, lambda 6.8415, per blade count. Source: `fine_lambda_bladecount.csv`.

n 3 to n 5 read direct. The sweeps reach 6.8415. The n 6 to n 9 values read the committed ratio surface times the measured n 3 anchor. The sweeps stop at 6.188. No direct measured C_T exists at 6.84 for those counts.

- n 3 reads C_T 0.9651. Below the cap.
- n 4 reads C_T 1.0964. Under-read 7.49 per cent.
- n 5 reads C_T 1.1901. Under-read 16.68 per cent.

- n 6 reads C_T 1.2649. Under-read 24.01 per cent.
- n 7 reads C_T 1.3228. Under-read 29.68 per cent.

- n 8 reads C_T 1.3708. Under-read 34.39 per cent.
- n 9 reads C_T 1.4112. Under-read 38.35 per cent.

## What verifies

- The 7 per cent claim at four lines. 7.49 per cent.
- The 38 per cent claim at nine. 38.35 per cent.

- The measured range, 0.965 to 1.407. This desk reads 0.9651 to 1.4112. The n 9 end differs 0.3 per cent. The convention note carries it.
- The cap retires under the founder ruling. Nothing here revives it.

## The fallback

The 1.4 fallback covers n 3 to n 8. At n 9 it reads 1.4112. That is 0.80 per cent over.

Under the measured top-knot ratio convention the n 9 read is 1.4488. That is 3.49 per cent over.

Both conventions agree. The gap sits at one row only.

## Boundaries

- The n 6 to n 9 values ride the committed ratio surface. The measured sweeps for those counts stop at TSR 6.188.
- The C_P side note. n 3 to n 5 at 6.84 match RF-22 exactly. 0.237, 0.176, 0.109. Rows n 6 to n 9 lack direct measured C_P at 6.84. That note rides the science seat RF-22 lane.

## Handoffs

- @science-validator: the measured BEM C_T basis and the 1.4 fallback for the SWL gate. The n 9 gap reads 0.8 per cent under the surface convention.
- @hermes: nothing gates here.

Evidence: `scratch/av_ct_cap_read.py` and its log, `scratch/av_ct_probe.jl` and its log.
