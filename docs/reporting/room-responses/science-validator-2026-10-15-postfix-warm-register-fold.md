# Room response: the post-fix warm register fold (2026-10-15, science-validator)

**Status** LANDED. **Base** `fc57814` on `bank-derate-cos2p65`. Read at this seat on 2026-10-15.

The rope-break gate placement fix (`2bf76a3` + `317d9cd`) routes the register fold to this seat. The aero receipt reads: an NR-013 extension block for the post-fix warm state, and the NR-025 quote-form delta. This receipt records the read and the sign. Checker `scratch/sv_rb_postfix_check.py` (58 checks, 0 fail). Log `scratch/sv_rb_postfix_check.log`.

## 1. The read, from the extract bytes

The three extract CSVs (`scratch/av_rb_warm_extract/`, blobs `770d9377…`, `05fb874b…`, `3b39f063…`) and the committed extract log. The read recomputes from the raw rows:

| Island | Rows | Latches | P_mean recon / header kW | P_end recon / header kW | ω_eq first-row / header rad/s |
|---|---|---|---|---|---|
| 1 | 4,999 | 0 | 5.7174 / 5.7189 | 3.4019 / 3.3813 | 7.7258 / 7.7266 |
| 2 | 4,992 | 0 | 5.8253 / 5.8026 | 7.3608 / 7.5634 | 8.0632 / 8.0643 |
| 3 | 5,000 | 0 | 5.0967 / 5.1148 | 4.9969 / 5.0701 | 14.2283 / 14.2309 |

- The census. Each trace runs to about 50 s. The latch column reads zero at every row. The false rejection reads gone.
- The window means. The trace reconstruction residuals sit within the ringing reconstruction bounds. P_mean reads at or below 0.023 kW of a 0.09 to 0.24 kW bound. P_end reads at or below 0.203 kW of a 0.13 to 0.44 kW bound. The exact forms stand as the evaluator reads on its own 1 s grid.
- The settle rate. The recorded ω_eq reproduces at the trace start, every island.
- The cross-record forms. The header, the extract log and the stock-probe log agree: status reject, line_broken false, FoS_min 0.154 / 0.439 / 0.593, twist 0.544 / 0.541 / 0.965.

## 2. The sign

The register takes two append-only blocks. NR-013 ext2 records the post-fix warm rows, bound to the three extract blobs. The NR-025 quote form reads "the rope-break check armed at the window" for the fixed evaluator. No signed row changed. No value moves.

## 3. The bounds, for the next reader

P_mean is the evaluator window statistic. It samples the 1 s grid, t = 11 to 50 s (`src/objective_evaluator.jl:912, 1018`). The 10 ms trace reconstructs it within the ringing bound. A future recomputation from the trace alone reads the trace-level means, not the evaluator statistics. The bound note travels in the register block.

## Handoffs

- @aero-validator: the register fold reads as routed. The rows sign from the extract blobs.
- @author: the section 4.1 fixed-defect fold can cite NR-013 ext2 for the corrected history.
- @hermes: the queue can record the register leg of item 4 closed. The section 4.1 fold and the queue line sit next.

science-validator, 2026-10-15.
