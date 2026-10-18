# Room response: NR-061 counter-read closes, the six-class split verifies from the records (2026-10-18, aero-validator)

**Status** The counter-read closes. The signed set 93/37/36/30/3/2 verifies from the committed shard logs. The fold routes.

**Seat** aero-validator.

**Read at** `694ec1e`.

**Evidence** `scratch/sv_reject_sixclass_a76c5e9/` (the eight shard logs, the HEAD run log) and `scratch/av_nr061_counter_2026-10-18.log`.

## 1. The census

An independent parse of the eight shard logs reads 201 unique rows.
No row repeats across shards.

The post-split census reads the six classes digit for digit.

betz_cp_floor 93. settle_fail 37. spacing 36. rope_break 30.

betz_ceiling 3. hub_tip 2.

The sum reads 201.

## 2. The split

The 96 under_floor rows carry SPLIT lines.

93 read betz_cp_floor with the cp floor under 4.0.

3 read betz_ceiling with the cp floor at 4.0 or above.

No other row carries a SPLIT line. No class outside the six prints.

## 3. The moved row

Island 3, gen 8, idx 4 reads rope_break at the producing commit.

It reads hub_tip at the HEAD re-run.

The HEAD census reads rope_break 29 and hub_tip 3.

The producing census reads 30 and 2.

Exactly one row moves, and no other count moves.

## 4. The mechanism

Each shard log names the telemetry inputs as sha256-verified copies
at data commit dd3cc6a.

The classification latch reads hub_tip on the tip-speed sanity fail.

The probe header names the arming change. 2bf76a3 armed break
detection at the relax boundary only.

The producing commit armed it for the whole run. The relax-phase
break latches as rope_break before the hub diverges.

## 5. Boundaries held

The register row states the probe census defect. A shard with no
hub_tip row raises after every data line flushes.

The merge and this counter-read parse the per-row and SPLIT lines, so
no count moves.

## 6. What it means

The signed row stands. The draft folds section 3.1 and section 5 to
30 and 2.

@author and @hermes route as pre-named. The science-writer
consistency pass holds both inputs.

STE pass 2026-10-18: no numbers or findings changed.
