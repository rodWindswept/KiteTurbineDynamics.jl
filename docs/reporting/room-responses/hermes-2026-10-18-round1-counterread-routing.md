# Room response: round-1 counter-read routing (2026-10-18, hermes)

**Status** ROUTING. **Seat** science-validator. **Read at** `646cddf`.

Five read-only counter-reads ran against the new report elements. Seven
prose fixes landed in the draft. Two register items need a seat, and one
is a release blocker.

## 1. NR-046 line-number re-pin (stale)

The rope-break arming commit `2bf76a3` added five lines to
`src/objective_evaluator.jl` (the `breaks_arm_s` argument and its
comment). Every later line shifted by five.

The register NR-046 pins the swing, cap and floor at
`objective_evaluator.jl:1192-1194, :1200-1203` (blob `52669d40`, HEAD
`7b8c101`). At HEAD the same lines read `:1197` (swing), `:1206` (cap)
and `:1207` (floor), blob `5c626ff5`.

The register claims byte-identity at launch and HEAD. That claim is now
false for `objective_evaluator.jl` only. The draft cites `:1207`, which
is correct against current source.

**Action:** amend NR-046 to re-pin `objective_evaluator.jl` at the
current blob `5c626ff5` with the corrected line numbers. The draft needs
no change.

## 2. Six-class 201-reject split needs a signed row (release blocker)

The draft now prints the six-class breakdown of the 201 unlogged rejects
in section 3.1 and section 5: 93 power-floor rotors, 37 realisability
cliff, 36 rotor spacing, 29 line breaks, three Betz ceiling, three hub
tip speed.

NR-055 is signed but covers only the three-way split. No signed row
carries the six numbers. A cited number with no signed row is a release
blocker.

**Action:** sign a new row for the six-class split. The counts came from
the re-run probe at HEAD `b65e9c8`. The rope-break count (29) may shift
if re-derived at the producing commit `a76c5e9`, because `2bf76a3`
moved break detection to the measurement window only. Re-derive at
`a76c5e9` before signing, or state the HEAD basis explicitly in the row.

## What already landed

Seven draft fixes, all confirmed by the counter-reads:

- DE/rand/1: "breeds from random members", not "from the best".
- Fixed-k coupling: "stay coupled", not "moved together".
- PC2 caveat: names the active ring-density gene at -0.5018.
- 201-reject six-class split into short sentences.
- NR-010 "peaks at the top" overreach dropped.
- R6 wording: "compressive axial load, not tension".
- PCA axis em dashes to colons.

Recorded by @hermes (lead).
