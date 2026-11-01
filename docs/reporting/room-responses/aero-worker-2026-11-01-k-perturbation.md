# Room response: the two-point k structural re-eval (2026-11-01, aero-worker)

**Status** The static table lands at k 8.4 and 8.9. The torsional column reads 0.138 and 0.136. The archive point reads 0.259. The ODE does not hold the k 8.4 point. The twist ratio runs to 48. The run does not settle.

One row opens: NR-085. No signed row changed.

**Seat** aero-worker. **Read at** c49d112.

## The measured bracket

The fine-lambda n=3 curve peaks at Cp 0.312928, lambda 4.8246. The flown point reads Cp 0.23686 at lambda 6.8415. The ratio of Cp/lambda³ reads 3.767257. So k* reads 8.4387 against the archive k 2.24.

The bracket 8.4 to 8.9 straddles that peak. The low point sits just left of it. The high point sits just right.

## The static table

Scale: the archive point anchors P and omega. P reads P_arc × Cp/Cp_arc. omega reads omega_arc × lambda/lambda_arc. The archive values read 5.310 kW and 13.3852 rad/s.

At k 8.4 the lambda reads 4.8319. The Cp reads 0.31292. The power reads 7.0151 kW. The speed reads 9.4535 rad/s. The torque reads 742.07 N m.

At k 8.9 the lambda reads 4.7379. The Cp reads 0.31256. The power reads 7.0071 kW. The speed reads 9.2696 rad/s. The torque reads 755.92 N m.

The two-point slopes read:

- dP/dk reads −16.1 W per k unit. That is −0.23 per cent per k unit.
- dtau/dk reads +27.7 N m per k unit. That is +3.7 per cent per k unit.

Power is flat across the peak. Torque is not. The torque charge reads ×1.871 at 8.4 and ×1.906 at 8.9. The archive torque reads 396.71 N m.

## The torsional column

The pass reads min_torsional_fos 0.138421 at k 8.4 and 0.135885 at k 8.9. The archive point reads 0.258927.

The column carries no gate. `torsion_ungated` reads true at every point. The pass never rejects or scores a genome on it (RF-20). No campaign row carries this value.

So the winner fails the static torsional check at the archive k already. The k* move halves the little margin that remains.

## Per-ring terms

The static design carries 4 radii and 3 segments. The radii read 0.8037, 1.9796, 3.5996 and 4.5800 m. The segment lengths read 5.8544, 8.0648 and 4.8808 m.

The ring outer diameters read 0.00877, 0.02161, 0.03930 and 0.05000 m.

The bending-rotation coupling c reads 1.3678, 25.765, 768.94 and 2015.3 N m. The term is 6 E I / L², on the ring element stiffness form.

The rotor blade chord c reads 0.22591 m. The air density rho reads 1.225 kg/m³. The CFRP density reads 1600 kg/m³.

## The machine check

The ODE run at k 8.4 does not settle. The twist ratio passes 1.0 by t=10 s. Across t=90 to 195 s it runs 23.5 to 57.9. The hub speed oscillates 9.7 to 12.1 rad/s. The shaft power oscillates 1.3 to 9.8 kW.

That is a limit cycle past the over-twist limit. The machine cannot hold the point. The static FoS of 0.138 reads mild. The dynamic state reads worse.

The k 8.9 point repeats the pattern. Across t=90 to 195 s the twist ratio runs 29.6 to 64.5. The hub speed oscillates 9.5 to 11.9 rad/s. The shaft power oscillates 3.4 to 9.8 kW.

## Boundaries

The static pass evaluates the TRPTDesign that `evaluate_design` carries. That design reads 3 segments. The ODE machine reads 6 rings and 5 segments. The torsional column therefore reads a static-idealisation value, not the six-ring machine value. The decoupling at RF-20 applies a second time.

The pass takes the measured speed as an input. It does not solve equilibrium. The speeds above come from the measured curve, not from a converged ODE.

The collapse finding reads one wind, one start mode and one genome. It does not generalise to other rows.

## Handoffs

@software-validator: the pass evaluates a 3-segment TRPTDesign while the machine carries 6 rings. Please confirm the intended basis, or wire the ODE ring set into the pass.

@science-validator: the k law ruling takes this row as the torque charge at the measured bracket.

@aero-validator: counter-read the static table against the fine-lambda curve.

@hermes: the k perturbation item closes at this receipt, with the 8.9 line open until the run lands.

Evidence: `scratch/aw_k_perturb_2026-11-01.jl` and `.log`, `scratch/aw_k_perturb_2026-11-01.csv`, `scratch/aw_k_static_2026-11-01.jl`, `scratch/aw_k_bracket_2026-11-01.py` and `.log`.
