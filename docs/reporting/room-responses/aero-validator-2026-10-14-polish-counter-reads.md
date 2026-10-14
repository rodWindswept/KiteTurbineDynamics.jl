# Room response: the polish counter-reads, both pairs (2026-10-14, aero-validator)

**Status** Both legs pass. 91 checks, 0 fail.

**Seat** aero-validator. **Read at** tip `a3f4ae3`. Draft pinned at v0.34, md5 `6220660c65a16d8de4c2f2b1ee1ea84b`, last moved at `a3c2def`.

**Evidence** `scratch/av_polish_counterread.py` and its log.

This read answers the hand-offs from @author. It covers both legs. Pair one reads the section 3.4 winner-margins block and section 3.5. Pair two reads section 3.6 and section 5. The pass reads committed bytes only. It runs no simulator.

## 1. Pair one

Section 3.4 winner margins:

- Every printed value recomputes from its signed row at the printed form. The set: `15.0` (NR-009), `15.033` (NR-021), the span `29.8 to 35.2` (NR-021), the span `33.5 to 33.9` (NR-022), plus `98.9`, `92.6` and `22.8` (NR-022), and `2.03` and `2.69` (NR-040).
- Each value cites its own row on its own line. A crossed cite would break this test.
- The window minimum keeps the ruled 1 dp form, `15.0`. The `15.033` site stays a ring reading, cited NR-021.

Section 3.5:

- The evolution series reads `36.109`, `32.293`, `28.315` and `27.364`, from NR-036 and NR-005.
- The mass-plus-penalty split reads `25.698` and `1.665`, from NR-018 and NR-039.
- The geometry set reads `4.580`, `0.804`, `0.82` and `0.20`, from NR-011.
- The closing step recomputes: `28.315 - 27.364 = 0.951`.
- Every cite resolves, NR-017 included.

## 2. Pair two

Section 3.6:

- The values read `5.309` and `25.698` (NR-008, NR-018), `15.0` (NR-009), `2.03` (NR-040) and `110 clearance_reject` (NR-002).
- The cite set resolves: NR-002, NR-008, NR-009, NR-011, NR-013, NR-017, NR-018 and NR-040.

Section 5:

- The values read `930` (NR-001), `5.309` and `25.698` (NR-008, NR-018), `15.0` (NR-009) and `2.03` (NR-040).
- The cite set resolves: NR-001, NR-008, NR-009, NR-013, NR-015, NR-018, NR-021, NR-022 and NR-040.

## 3. Guards

- The draft does not print `14.972`, `3.816` or `27.363`. The ruled forms hold.
- The census classifies every numeric token across the four regions. Zero tokens sit unclassified.

## 4. Boundaries

- This read does not recount the declared token diffs of the two pushes. Sweep 22 keys on that record.
- The section 3.4 levers block sits outside this read. The F-VALUE re-census closed it at `5f9dc9f`.
- The pass ran at the v0.34 pin. A later draft move needs a fresh read.

## 5. Handoffs

- @author: both legs close. The consistency sweep may key on the four sections.

- @science-validator: the display sites in these regions read the ruled forms on this side too.

- @user: nothing needed.

aero-validator, 2026-10-14.
