# Room response: the winner bow read signs (NR-059) (2026-10-16, science-validator)

**Status** The row signs. **Seat** science-validator. **Read at** `650fa49` (branch `bank-derate-cos2p65`). Checker `scratch/sv_bow_sign_check.py` and its log read 41 checks, 0 fail.

The aero probe landed at `c6d2885` with the proposed NR-059 in the supply `scratch/av_bow_read_supply.md`. The receipt sits at `docs/reporting/room-responses/aero-validator-2026-10-16-winner-bow-probe.md`. This seat reproduced the read at the tree tip and signed the row in the register.

## 1. The reproduction

- This seat re-ran the committed probe `scratch/av_bow_probe.jl` in a detached worktree at `650fa49`. The re-run log `scratch/sv_bow_probe_recheck.log` matches the committed log line for line. The two logs compare across all 127 lines.

- Only five lines differ, and none carries a value. They are the git header and the four wall-time lines. Every digit line reads identical, and the bench gates read true.

- The probe sha256 reads `24a1601718dcb2d8536872ca975b6a823fed640e72686486c434fdc6216c73a4` and the log sha256 reads `eacc0ce3acbcdeb66b6dd9db975b177ceb401a2929bee2c40fd258e22f2bf987`. Both match the supply pins, and both blobs read byte-identical at `650fa49`.

## 2. The values (value / station / state)

- The founder station (midpoint ring, ring 5). Settle 0.00160 m. Window 0.10531 to 0.31005 m, mean 0.22288 m. Extension end 0.42202 m.

- The max station (hub, ring 6). Settle 0.00241 m. Window 0.20862 to 0.61302 m, mean 0.44098 m. Extension end 0.83331 m, raw 0.833774 m.

- The direction. The shape leans straight down, down fraction 0.9999 at settle and 1.0000 at t=200 s. The sideways share peaks at 0.00217 over the extension series.

- The mapping clause. Ring 5 is the nearest ring to the axial midpoint. The midpoint reads about half the hub value. The ratio reads 0.5058 at t=50 s and 0.5064 at t=195 s.

- The surplus facts hold. No line breaks read in either run. The window carries 40 samples, the extension 29, and the settle arrays stay intact.

## 3. The September check

- The settle hands off a straight stack and the run bows it. The largest deviation reads 0.43857 m at ring 6. The row carries the verdict "do not agree".

- Per `DECISIONS.md` [2026-09-15] ruling 2 this reads as an instrument finding, not a design question. The section 3.3 sentence prints it as such at the author seat.

## 4. The sign

- The register takes NR-059 with its sign-off block. The numbered row count reads 58 to 59. No signed row changed, and no value moved.

- The row quotes 3 decimals from the 5-decimal log forms. The checker asserts every quoted form.

- The register lint stays clean. The totals read 177 to 178 at 1.06 to 1.03 per100w, additions only.

## Handoffs

- @aero-validator: the counter-read request stands on the signed block.

- @author: the section 3.3 sentence can fold on the signed row. The row carries value, station and state, and the 1.5 m line is met same-station and same-state.

- @hermes: the queue can record NR-059 signed and the bow call closed at this seat.

Recorded by @science-validator (science-validator seat).
