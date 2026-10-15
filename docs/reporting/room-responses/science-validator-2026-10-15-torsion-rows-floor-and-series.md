# Room response: the torsion rows, the floor row and the convergence series (2026-10-15, science-validator)

**Status** LANDED. **Seat** science-validator. **Base** `ead15de` (branch `bank-derate-cos2p65`).

Three register reads the room keyed on this desk: the NR-031 and NR-032 source-cell amend, the torsion and floor rows, and the convergence series row.

## 1. The source-cell amend

The NR-031 and NR-032 source cells read "the measured n = 3 surface". The basis is the AeroDyn v5.0.0 quasi-steady BEM table. That is a computation, not a measurement. The amend block states the code sites and the corrected reading. The blade-count ratio surface is a separate, measured surface, and at n = 3 it returns the baseline unchanged.

No digit moves. The operating-point fold can carry the corrected basis.

## 2. The torsion rows

NR-052 carries the torsion criteria as implemented. The geometric crossing check is the campaign's twist gate. The torsional-stability FoS hard constraint reads 1.5 on the design-verification path. The winner reads: least segment torque margin 2.03 at S1 (1.35 times the 1.5 floor) and worst crossing ratio 0.4393 (margin 2.28).

NR-053 carries the floor. sin(dalpha) <= 1/1.05 = 0.9524 gives the floor angle 72.247 deg. The 1.05 is a design constraint, not a fit. The winner cross-reads 2.13 to the floor and 2.91 to dcrit.

The 2.5 boundary reads honest: as run, no code and no row enforces 2.5 on torsion. Extending the gate to torsion stays with the founder.

## 3. The series row

NR-054 signs the convergence series. This seat recomputed all 93 rows from the three telemetry files. Every pick and its source index equal the extract. The parity set reads clean: the telemetry sha256 values, the ok counts (152, 162, 194; sum 508), the NR-036 milestones, the finals and the stock-probe agreement.

## Evidence

- Checker `scratch/sv_criteria_check.py` and its log.
- Checker `scratch/sv_conv_series_check.py` and its log.
- The register blocks append only. No signed row changed.

## Handoffs

- @author: the torsion sentence and the floor sentence key on NR-052 and NR-053. The operating-point fold carries the corrected Cp basis.
- @fig-img-diagrams: the convergence figure can print from the NR-054 bytes.
- @aero-validator: the series is signed. Nothing opens.
- @hermes: the queue can record the three reads closed.

Recorded by @science-validator (science-validator seat).
