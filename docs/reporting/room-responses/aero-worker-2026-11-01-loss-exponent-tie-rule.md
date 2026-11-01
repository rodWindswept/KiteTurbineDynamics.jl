# Room response: the loss exponent and the two-dp tie rule (2026-11-01, aero-worker)

**Status** The loss law signs at P' = P x³. The survivor counts take a tie rule at the two-decimal power floor.

One row opens: NR-084. No signed row changed.

**Seat** aero-worker. **Read at** 7e44233.

## The law

The bridle drag and the shaft power both scale as omega cubed. Torque balance then reads (1+f)x² + x − 2 = 0. Here x is the speed ratio and f is the drag fraction. The root sits near 1 − f/3. Power reads P' = P x³.

The linear form P(1−f) carries the right exponent. The flat-torque form P(1+f)^−1.5 overshoots by half again. A parabolic Cp cross-check agrees with the quadratic to 0.4 per cent.

## The three bounds at k = 2.24

The two-bridle low bound reads f 0.1036. The factor x³ reads 0.9052. The linear form reads 0.8964. The flat-torque form reads 0.8626.

The two-bridle high bound reads f 0.1295. The factor x³ reads 0.8839. The linear form reads 0.8705. The flat-torque form reads 0.8330.

The full-line bound reads f 0.1765. The factor x³ reads 0.8475. The linear form reads 0.8235. The flat-torque form reads 0.7837.

## At the measured k*

The k* move divides f by 3.75 to 3.97. The factor 3.75 belongs to k 8.4. The factor 3.97 belongs to k 8.9.

The two-bridle low bound reads x³ 0.9745 to 0.9730. The high bound reads 0.9683 to 0.9665. The full-line bound reads 0.9573 to 0.9548.

So the drag loss falls at the measured k*. It reads 9.5 to 15.3 per cent at the archive k. It reads 2.6 to 4.5 per cent at k*.

## The tie rule

The telemetry records P_end at two decimal places. A design whose printed P_end sits within half a print step of the derived floor is a boundary tie. A strict count does not take a tie row.

The full-line bound at eta 1.0 gives the case. The floor reads 5.8994 kW. The strict count reads 108. Ten rows print 5.90 and sit in the tie band. The inclusive count reads 118.

The 2026-10-22 probe printed 118 in its table and 108 in its reading line. Both numbers are right on different rules. This row prints all three counts so a reader can see the tie band.

## The two ends that hold

Two ends do not move. The full-line bound with eta 0.94 reads 2 survivors. No tie row sits there. The full-line bound with eta 1.0 brackets 108 to 118.

Quote the ends, not a middle count. A middle count carries the tie band. A reader cannot reproduce it from the printed power alone.

## Boundaries

The row reads the 508 ok rows of the live campaign.

The floor reads 5.0 kW shaft. It is not the delivered-power floor.

f reads the three signed bridle-drag bounds at the archive k. The per-design f column is the decode at the aero seat. RF-13 reads 46 survivors there. This row does not sign that column.

The exponent is first order in f. It does not carry a Cp curvature term beyond the parabolic check.

## Handoffs

@science-validator: the row sits in the register for a counter-read.

@author: the loss paragraph may print x³ 0.905 to 0.848 at the archive k. The 108 to 118 bracket needs both ends.

@hermes: the RF-12 and RF-13 items close at this receipt.

Evidence: `scratch/aw_loss_row_2026-11-01.py` and `scratch/aw_loss_row_2026-11-01.log`. The superseded probe reads `scratch/aw_loss_response_exponent_2026-10-22.py`.
