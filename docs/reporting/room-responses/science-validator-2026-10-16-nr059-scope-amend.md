# Room response: the NR-059 direction scope amend (2026-10-16, science-validator)

**Status** The amend lands. **Seat** science-validator. **Read at** `4fe517f` (branch `bank-derate-cos2p65`). Checker `scratch/sv_nr059_scope_check.py` and its log read 19 checks, 0 fail.

The aero counter-read (`271182b`, receipt `docs/reporting/room-responses/aero-validator-2026-10-16-nr059-counterread.md`) passed every value and handed one scope correction to this seat. This receipt records the landing.

## 1. What the amend does

- The register gains one appended block, `Bow direction scope amend: NR-059`. The block gives the sideways bound its true scope: over the extension series and from t=38 s onward. No signed row changes, and no value moves.

- The corrected figures, all re-derived at this seat from the committed counter-read log. The relax sampled peak reads 0.23586 at t=2 s. The window decays from 0.03740 (hub) and 0.03734 (mid) at t=11 s. The hub reads under 0.003 from t=37 s, and the midpoint from t=38 s. The extension peak reads 0.00217, and the t=200 read is 0.0002.

- The early motion is the known ~10 s lateral mode. It rings out.

## 2. The verification

- The counter-read instrument holds its anchors. The window-end speed matches the committed read to 8.882e-15. Both window series reproduce byte for byte against the committed probe log.

- The landing is a pure addition. The register diff reads 23 added and 0 removed. The STE categories hold at identical counts, and the totals read 178 at 1.03 to 1.02 per100w.

- The scope finding re-verifies. The whole-run bound reads false, so the amend carries the true scope.

## 3. The blast radius

- The draft carries no direction bound, so no report byte moves. The section 3.3 sentence cross-checks against NR-059 unchanged.

- The glossary entry carries no value and cites no register row. Nothing opens there.

## Handoffs

- @aero-validator: the amend lands with your proposed wording, and the counter-read pair closes.

- @author: no bounce. The printed sentence carries no direction bound, and no draft byte moves.

- @hermes: the queue can record the scope amend landed and the NR-059 chain fully closed.

Recorded by @science-validator (science-validator seat).
