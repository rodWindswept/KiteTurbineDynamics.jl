# Register status: the eval timeline

**Slug** `eval-timeline`. Status note for the figure rows.
**Date** 2026-10-13.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-008 | The window mean power 5.309 kW and P_end 5.314 kW | Signed |
| NR-012 | The cold-path reproduction (the cold curve) | Signed |
| NR-013 | The rapid-path rejection (the warm leg cause) | Signed |
| NR-013 ext | The two lane-3 strain annotations: 1.00081 at t = 2.841 ms and 1.448 at t = 5.798 ms, the grid max | Signed (science-validator, 2026-10-12). Counter-read closed (aero-validator) |
| NR-016 | The start reference 10.17 rad/s, the rotor Cp-peak speed | Signed |
| NR-027 | The floor numeral, with NR-039, per the section 2.4 table | Signed |
| NR-029 | The window mean 13.38 rad/s (the taps basis) | Signed |
| NR-039 | The same floor numeral, as the over-power ceiling | Signed |

The figure draws no other row. The gate-map rows read the code at
a89642b: ground clearance at decode, rope break at every step, the
sampled gates once per second, and the power reads on P_end. The
register seat verified the strings true as code facts, with pins
(science-validator, `20d06bb`). One bounce stands: "≥ 1.5 m" is the
only unrowed numeral. The clearance row is scheduled (W7 proposes the
value, SV5 signs). The string stands as-is until the row lands, then
it joins this list.

## Drawn precision

- Lane 1 reads 10.17 and 13.38 at 2 dp. The phrase "rotor Cp-peak
  speed" carries its own pin line: `src/initialization.jl:2239-2250`
  and the committed BEM table (λ_peak 5.2, the argmax, cp 0.308697).
  The identity closes at 11.0099266 m/s. NR-016 carries the value
  alone, so a caption that prints the Cp-peak speed as a value takes
  its own row first.
- Lane 2 reads 5.309 kW, 5.314 kW and the 5.0 kW floor. The dense
  curve re-reads 5.309770 kW at 100 Hz, so at 3 dp it rounds to 5.310.
  The plate prints the row form 5.309. A once-per-second subsample
  reproduces the evaluator value to 1.1e-5, so the gap is sampling
  cadence, not a discrepancy. The tail pair reads 5.314 on both bases
  (evaluator tail-5 5.314114, plotted 5.314264). The mean is the one
  that needs this note.
- Lane 3 reads the signed forms: "2.841 ms", and "1.448 at t = 5.798
  ms". The 1.448 is the extract grid max.
- The axes carry the scale. They are not readouts.

## Reproduce

Command:
`/usr/bin/python3 docs/reporting/figures/eval-timeline/eval-timeline.py --script-commit <commit>`

Toolchain pin: CPython 3.12.3, matplotlib 3.10.8, numpy 2.4.4
(`/usr/bin/python3`). The manifest pins the four input records and the
output hashes. Self-check: two consecutive runs stay byte-identical.
The run log sits at `checks.log`.

**Delta** v2 (2026-10-13): the register seat's two backing clauses
land, and the "≥ 1.5 m" bounce is recorded. v1: created with the kit
landing.
