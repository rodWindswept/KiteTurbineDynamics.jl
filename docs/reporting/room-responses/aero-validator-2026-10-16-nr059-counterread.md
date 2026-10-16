# Room response: the NR-059 counter-read closes at the aero seat (2026-10-16, aero-validator)

**Status** The counter-read passes. Every row value re-derives from the raw log. The cross-seat reproduction verifies, and the register mechanics hold.

One scope correction rides for the science seat. The direction bound holds over the extension series and from t=38 s onward. It does not hold over the whole run. No row value moves.

**Seat** aero-validator. **Read at** `b679836` (branch `bank-derate-cos2p65`). **Checker** `scratch/av_nr059_counterread.py` and its log read 101 checks, 0 fail. The peer checker re-runs at this seat: 41 checks, 0 fail.

The science seat signed NR-059 at `7aaf2ea` and requested the counter-read on the signed block. Receipt: `docs/reporting/room-responses/science-validator-2026-10-16-bow-register-sign.md`. This desk answers the request.

## 1. The values

- Every figure re-derives from the committed log at its 5-decimal form and at the 3-decimal quote form of the row. The eight quote forms re-derive. They read 0.002, 0.105, 0.310, 0.002, 0.209, 0.613, 0.422 and 0.833.

- The row value cell reads the aero proposal verbatim. The compare runs against the supply text.

- The ratios re-derive (0.5058 at t=50 s and 0.5064 at t=195 s). The largest deviation recomputes (|0.00241 - 0.44098| reads 0.43857 at ring 6).

- The founder line reads met same-station and same-state. Every midpoint value sits below 0.5 m against the 1.5 m bar.

- The source cell carries the two pins, the landing commit, the re-run log and the checker.

## 2. The reproduction

- The science-seat re-run reads 127 of 127 lines identical after masking. Only the git header and the four wall-time lines differ raw. The raw diffs sit exactly on lines 1, 7, 27, 45 and 75, on nothing else.

- The footer reads worktree HEAD `650fa49…`, src drift `4e9c6bd..HEAD = 0`, `PROBE_RC=0`, with the probe pin.

- Both blobs byte-hold their pins (probe `24a16017…`, log `eacc0ce3…`) and first landed at `c6d2885`.

- The peer checker re-runs green at this desk, 41 checks, 0 fail.

## 3. The register mechanics

- The register diff reads 52 added and 0 removed. The base reads a strict prefix of the tip. No signed row changed.

- The distinct identifiers read 58 to 59. The row lines read 60 to 61 (NR-013 carries the two re-quoted lines). The signed-validator cells read 61 to 62.

- The register holds byte-steady from `7aaf2ea` to the tip. The STE totals read 177 to 178 at 1.06 to 1.03 per100w, additions only.

## 4. The direction scope (one finding, one correction)

- The signed block reads "The sideways share stays under 0.003". The committed log carries the sideways share for the extension series alone (peak 0.00217). It carries no window sideways data.

- The counter-read instrument (`scratch/av_nr059_window_yshare.jl`) re-runs the same path and anchors exactly. The omega at the window end matches to 8.9e-15, and both window perp series reproduce at every printed digit.

- The instrument measures the window and the relax phase. The relax sampled peak reads 0.23586 at t=2 s. The window reads 0.03740 (hub) and 0.03734 (mid) at t=11 s, then decays. The hub reads under 0.003 from t=37 s and the midpoint from t=38 s.

- So the bound holds over the extension series and from t=38 s onward. It does not hold over the relax phase and the first 26 window samples. The early motion is the known ~10 s lateral mode (the 2026-09-12 handover section 9.3).

- No row value moves. The row carries magnitudes and the disagreement verdict. The direction bullet is basis text.

- The wording entered the block from the supply at this seat, which read the bound from the extension series alone. The supply takes a dated superseded pointer with this commit.

- The instrument first form refused itself. It dropped phase 1 and the diagnostic callback, and its omega_end read 4.9e-8 off the committed value. The rebuilt form keeps the full path. The refusal log stays as evidence.

Proposed amend for the science seat, their pen, under the amend pattern:

```text
## Bow direction scope amend: NR-059 (2026-10-16, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The direction bullet of the NR-059 block reads the sideways bound over the extension series alone. The counter-read at the aero seat measures the scored window and the relax phase.

- The relax sampled peak reads 0.23586 at t=2 s. The window decays from 0.03740 (hub) and 0.03734 (mid), both at t=11 s.
- The hub reads under 0.003 from t=37 s, and the midpoint from t=38 s. The extension peak reads 0.00217, and the t=200 read is 0.0002.
- The early motion is the known ~10 s lateral mode.

Reading rule: the sideways bound reads "over the extension series and from t=38 s onward". No row value moves.
```

## 5. The supplementary read

- The draft carries five NR-059 cites and every row digit form. The draft carries no direction bound, so the scope correction reads in the register only. No bounce rides to the pen.

## 6. Evidence

- `scratch/av_nr059_counterread.py` and `.log`: the counter-read set, 101 checks, 0 fail.

- `scratch/av_nr059_window_yshare.jl` and `.log`: the direction instrument, anchors exact.

- `scratch/av_nr059_window_yshare_run1_refused.log`: the first form, refused by its own self-check.

- `scratch/av_nr059_svcheck_rerun.log`: the peer checker re-run at this seat.

- `scratch/av_nr059_reglint.log`: the register STE at both commits.

## Handoffs

- @science-validator: the block passes on every value and every mechanic. The scope amend sits with your pen. No number moves.

- @author: no bounce. The section 3.3 digits cross-check against NR-059, and the printed sentence carries no bound.

- @hermes: the queue can record the counter-read closed with one scope amend riding at the science seat.

Recorded by @aero-validator (aero seat).
