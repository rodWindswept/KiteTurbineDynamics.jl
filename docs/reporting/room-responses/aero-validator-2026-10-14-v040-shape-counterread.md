# Room response: the v0.40 shape counter-read, the six shape lines, the diff census and the copy read (2026-10-14, aero-validator)

**Status** LANDED at `b0d7f70`. **Seat** aero-validator. **Read at** `a359061`, the tip at read time (branch `bank-derate-cos2p65`, local equal to origin).

**Scope** This pass runs the v0.40 counter-read. The author fold (PL13, the decision shape) routes the read over the three shape additions, the receipt and the copy. The read covers the six shape lines, the diff census and the v0.40 build at md5 `835de8d8dc92e209d23cba39e7c11549`.

## 1. The six shape lines

- The draft carries each line once, at its section. The set reads one line in section 3.4, three in 3.5 and two in 3.6.

- Digits read zero in all six lines.

- The frozen levers block reads carried once, byte-identical. Its md5 reads `7bbd964db09d2b33269ce5cb8c334054`.

## 2. The diff census and the receipt

- The diff v0.39 to v0.40 adds the pin line and the six shape lines. It removes the old pin alone. No other line moves.

- Sections 4 onward hold byte-identical against the base (`12a5753`).

- The receipt re-reads against the draft: the three addition sets and the pin-alone diff read as declared.

## 3. The v0.40 copy read

- Identity. The copy md5 reads `835de8d8dc92e209d23cba39e7c11549` and matches the archived build byte for byte. The build record reads draft `0e7d396`, register at `a7d09eb`, six seats resolved. The citation line reads 37 cited of 48 signed, with the 16:43:52Z stamp.

- The six shape lines read in the document body. The head line reads "Draft v0.40". The v0.37 to v0.39 marks read zero.

- The pins recompute. All 24 read pin equal to file equal to HEAD equal to origin. The six exhibits embed the delivered render bytes.

- The guards hold. The `14.97` class prints once, inside the register appendix. `3.816`, the rounded `27.363` and the unresolved notice read zero. `15.033` keeps its form.

- The register appendix carries its 37 cited rows, spot values at the register forms.

- The register holds append-only since `d2bf63d` (54 added, 0 removed). No cited value moves.

## Gates

- 164 checks, 0 fail. Evidence: `scratch/av_v040_shape_counterread.py` and its log.

- No value moves. The shape lines carry no digits, and no display form enters or leaves.

## Handoffs

- @author: the shape fold stands counter-read. No value touched.

- @science-writer: sweep 27 keys on the next draft push. The register and the consultation file hold unchanged from this read.

- @hermes: the v0.40 counter-read closes at this seat. The queue can record it.

- @user: the copy reads clean at v0.40.

## Evidence

- `scratch/av_v040_shape_counterread.py` and its log (164 checks).

aero-validator, 2026-10-14.
