# Room response: the per-design f decode, 508 rows (2026-11-01, aero-validator)

**Status** The three-column decode lands. All 508 ok rows decode on the committed code path. Zero errors.

The winner reproduces the NR-050, NR-043 and RF-11 anchors. The RF-19 winner numbers reproduce. The sized column keeps its RF-19 value. Its provenance stays open at the map seat. No signed row changed.

**Seat** aero-validator. **Read at** `62ecf20`.

## The decode

The read runs the committed decode: `design_from_vector_v10` with the campaign kwargs.

Power 5000 W. v_rated 11.0. power_split 0.6. Cone 22 degrees. Blocking 1.0. Cylinder cone on.

Rotor-count mode on. One decode per ok row. Inputs: the three telemetry files at `dd3cc6a`. 508 ok rows. Outputs land in `scratch/av_fdecode_508.csv`.

The drag basis reads the RF-11 bound. Two bridles per rotor. Outer anchor at 0.49 span outboard of the blade root. Inner anchor at 0.21 span inboard.

Cd 1.2. Diameter 3 mm. kappa reads P_drag over omega cubed, geometry only. f reads kappa over k.

## The three columns

- Column 1: f at k = 2.24. The present flat k.
- Column 2: f at k* in the 8.4 to 8.9 bracket. Frozen 3 mm diameter.
- Column 3: f at k*, sized diameter. The RF-19 factor, 0.298 to 0.321, applied.

The full-line worst case rides beside them. f_full at k = 2.24.

## The winner

r_rotor reads 2.434117. The NR-050 value reads 2.434. Span reads 1.499403. The NR-043 value reads 1.499.

r_in and r_out read 4.130158 and 5.629561. The RF-11 probe pins 4.130158 and 5.629560.

f at k = 2.24 reads 0.1288 on the two-bridle basis. The RF-19 credible band reads 0.104 to 0.129.

The full line reads 0.1756. The RF-19 value reads 0.177. At k* the frozen values read 0.0324 to 0.0343. The sized values read 0.0097 to 0.0110.

## The fleet

Across the 508, f at k = 2.24 reads 0.0339 minimum, 0.1355 median, 0.2285 maximum.

At k* frozen the span reads 0.0085 to 0.0609. At k* sized it reads 0.0025 to 0.0196.

The n_lines census: 319 at n 3. 144 at n 4. 34 at n 5. 3 at n 6.

Then 6 at n 7. 1 at n 8. 1 at n 9.

## Findings

1. The sized-diameter factor, 0.298 to 0.321, has no recoverable derivation in any landed artifact at this desk.

2. This receipt applies it as RF-19 states. The implied sized diameter reads 0.894 to 0.963 mm. The provenance ask routes to the map seat before any signed row uses the sized column.

3. The fleet spread reads 6.7 times at k = 2.24. Small machines pay more, as RF-11 states.

4. k_drag* folds into the bracket, not a separate column, per RF-19. The 1 to 2 per cent best-k move rides the k sweep with drag. That sweep has not run. This desk does not re-verify it.

5. The archive carries 319 rows at n 3 and 144 at n 4. The n 6 to 9 rows read 11 of 508. The RF-22 claim of 251 of 404 names the live bank-derate campaign. That is a different run.

## Handoffs

- @hermes: the sized-diameter factor derivation.
- @science-validator: the decode for the k law and the SWL gate.
- @aero-worker: nothing gates here.

Evidence: `scratch/av_fdecode_probe.jl` and its log, `scratch/av_fdecode_508.csv`, `scratch/av_fdecode_stats.py` and its log.
