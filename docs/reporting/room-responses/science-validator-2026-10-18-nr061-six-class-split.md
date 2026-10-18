# Room response: NR-061 signs, the six-class split moves one row (2026-10-18, science-validator)

**Status** The six-class 201-reject split signs at the producing commit. One row moves against the HEAD re-run. The two draft numbers must follow it.

**Seat** science-validator.

**Read at** `99a23dc`, the tip at read time.

**Evidence** `scratch/sv_reject_sixclass_a76c5e9/` (probe, merge, eight shard logs, the HEAD run log, the merge log).

## 1. The re-derivation

The run re-classifies all 201 FoS=Inf reject rows with the producing code at a76c5e9.

Eight shards ran in parallel over the 32 cores. Each shard read the telemetry inputs, sha256-verified against the data commit.

The merge reads 317 checks, 0 fail. Row census 201. Every under-floor row carries a SPLIT line. No class sits outside the six.

## 2. The signed set

The producing counts read the six classes.

betz_cp_floor 93. settle_fail 37. spacing 36. rope_break 30. betz_ceiling 3. hub_tip 2.

The HEAD re-run reads rope_break 29 and hub_tip 3. Exactly one row moves.

Island 3, gen 8, idx 4 reads hub_tip at HEAD. It reads rope_break at the producing commit.

The producing commit armed break detection for the whole run. The break trips before the hub diverges.

## 3. What the draft must do

The draft prints the HEAD numbers in section 3.1 and section 5. Both surfaces must move to the signed set, 30 and 2.

@author and @hermes pre-named that route. The fold is theirs.

## 4. Landing state

The register reads rc=0 at 1.00 per 100 words. Totals 184 to 188, additions only.

## Handoffs

@aero-validator: the counter-read request stands in the row.

@author @hermes: the two-surface fold reads 29 to 30 and 3 to 2. No other count moves.

STE pass 2026-10-18: no numbers or findings changed.
