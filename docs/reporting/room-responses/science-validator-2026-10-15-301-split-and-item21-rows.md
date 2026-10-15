# Room response: the 301-reject split and the item-2.1 environment rows (2026-10-15, science-validator)

**Status** LANDED. **Seat** science-validator. **Base** `0e18e08` (branch `bank-derate-cos2p65`).

Two sign-offs the room routed to this desk: the 301-reject split, ruled for print, and the three item-2.1 environment rows from the aero seat. Both land in one pass.

## 1. The 301-reject split (NR-055)

The founder ruled "Print" on the 301-reject breakdown. This seat re-read all 930 rows of the three bankderate2 telemetry files. The split reads 96 / 4 / 201.

- Subgroup A, ran with power below the 5 kW floor: 96 rows, P range 1.90 to 4.98 kW. 34 of the 96 also read FoS below 2.5, so the split reads the power floor first.
- Subgroup B, ran at or above 5 kW with FoS below 2.5: 4 rows. Island 1 gen 6 idx 7 (P 5.47, FoS 2.27), island 3 gen 5 idx 8 (5.15, 1.61), island 3 gen 14 idx 8 (5.72, 1.25), island 3 gen 22 idx 2 (5.68, 0.42).
- Subgroup C, fields zeroed with the cause not logged: 201 rows, P 0, FoS Inf, T_lift 0.

The status mix around the split reads 508 / 301 / 110 / 11. The per-island counts match the figures notes, and the three telemetry sha256 values match the NR-054 header. The Phase 0 audit carries the same 100/201 split on the FoS census.

## 2. The item-2.1 environment rows (NR-056 to NR-058)

Each source line was re-read at the tip. The library values were re-read through the shipped library. All three reads agree with the aero receipt.

- NR-056, the shear law: Hellmann power law, exponent 1/7, on the measured Daisy pair 10.0 m/s at 4.8 m. The probe reads 11.007738 m/s at the design hub, 11.009694 at the rung reference, 10.924573 at the settled hub.
- NR-057, the shaft-elevation angle: 30.0 degrees (pi/6), the model convention. Design hub 9.4000 m. Flown settled read 28.64 deg at z 8.914 m.
- NR-058, the steady-wind basis: the evaluator closure reads altitude only. The NR-014 swing is a steady-wind response, not a stability property.

## Evidence

- Checker `scratch/sv_301_split_check.py` and its log. rc=0, all checks pass.
- Probe `scratch/sv_item21_env_probe.jl` and its log. rc=0, all checks pass.
- Checker `scratch/sv_item21_env_check.py` and its log. rc=0, all checks pass.
- The register blocks append only. No signed row changed.

## Handoffs

- @author: NR-055 keys the status-mix split and the panel-one labels. NR-056 to NR-058 key the environment folds in section 3.3 and the swing basis note.
- @fig-img-diagrams: the panel-one label set is fixed by NR-055. No new bytes for the build.
- @aero-validator: the three rows are signed. Nothing opens.
- @hermes: the queue can record the 301 sign and the three reads closed.

Recorded by @science-validator (science-validator seat).
