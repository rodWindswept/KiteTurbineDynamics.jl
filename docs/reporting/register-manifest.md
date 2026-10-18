# Register manifest: the full-precision readings behind the human-facing register

**Slug** `register-manifest`. **Status** LIVE, seed 2026-10-18. **Owner** @aero-validator. **Readers** the report-team room and Rod.

The reader-facing register prints each NR row at four significant
digits. This file carries the full-precision readings those cells
round. The display amend 2026-10-18 in
`docs/reporting/numbers-register.md` cites this file.

Rows NR-021 to NR-024 hold the aero seat. The science-validator rows
land here in the same pattern when that seat runs its half of the
register formatting.

## NR-021 Ring check at the winner operating point (island 3)

The register prints the interaction and the FoS per checked ring at
four significant digits. The full strings read:

```text
R2 0.03323714455441065 = 0.033223570205929 + 1.3574348481652112e-5, FoS 30.086820435580936
R3 0.033548608446737266 = 0.03354237801917142 + 6.230427565848155e-6, FoS 29.80749563987516
R4 0.028380221733419368 = 0.028374815022862057 + 5.40671055731162e-6, FoS 35.23580644975869
R5 3.058346201008972e-6 = 0.0 + 3.058346201008972e-6, FoS 326974.1011237028
R6 hub 0.06652238395895148 = 0.06652164721153939 + 7.36747412096439e-7, FoS 15.032534020684876
```

Source: `docs/reporting/figures/pair-extract/extract-winner-operating-point.csv`, ring block.

## NR-022 Segment twist and over-twist limit at the winner operating point

The register prints the angles at four significant digits. The full
strings read:

```text
abs(dalpha): S1 33.94561934829036°, S2 33.811870056223555°, S3 33.67952027817454°, S4 33.54707806507812°, S5 22.821871326820364°
dcrit: S1 to S4 98.85908296054023°, S5 92.64281134151318°
has_limit true on all five
```

Source: extract, segment block.

## NR-023 Segment torque pair at the winner operating point

The register prints the torques at four significant digits. The full
strings read:

```text
segment_torque: S1 396.791634149159, S2 397.1554424859068, S3 397.45360112890063, S4 397.68800908436924, S5 397.1777954649229
torque_capacity: S1 805.0097155967861, S2 808.6780945063998, S3 812.213802301376, S4 815.650844050359, S5 1069.9324759682652
```

Source: extract, segment block.

## NR-024 Evaluator step law

The register prints the winner derived step at four significant
digits. The full string reads:

```text
Winner derived step 2.8987873697672758e-5 s
```

Source: winner value from the extract log.
