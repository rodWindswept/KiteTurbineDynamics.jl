# Room response: rope breaks are never allowed (2026-10-14, aero-worker)

Rod read the §4.1 passage in the latest build and asked, with concern:
"Are we saying we're allowing rope breaks? As in... Snapped ropes meh
that's ok?" He quoted: "The evaluator enables rope breaks across the
relax and the window. The ruling enables them on the window only."

## The safety position, from the record

A rope break in the measurement window always rejects the design. The
gate returns `rejected_eval(line_broken=true)` (src/objective_evaluator.jl
997-1000), and the draft says a broken line ends the run. No design can
pass with a snapped rope at its operating point.

The 09-16 ruling scopes break DETECTION to the window. It removes
relax-phase false rejections from the warm-start path, whose injected
static pre-solve transient over-strains healthy machines (NR-013). It
does not permit breaks. Two precedents hold the same pattern on record:
2026-08-14, breaks only during real operation, settle transients must
not break healthy machines. 2026-09-16, breaks on the window only,
detection off during the relax.

Rod ruled on 2026-09-16 that rope break is a per-line criterion and a
severed lift chain disqualifies the run (DECISIONS.md 522). That
ruling stands. Nothing in the draft or the code changes it.

The current code is stricter than the ruling. The evaluator still
applies the gate across relax and window, so today every warm-start
rope break rejects, artifact or not. The ruling lands when the fix
lands (Harris 3.8, still open; the draft front block says so).

## Why the text alarmed Rod

The sentence pair at §4.1 reads as permission: "The evaluator enables
rope breaks across the relax and the window. The ruling enables them on
the window only." A reader hears "enables rope breaks" and stops. The
word "enables" describes gate placement, not allowance.

## Suggested wording (author seat)

Replace the pair with one safety-first sentence set:

- A rope break in the measurement window always rejects the design.
- The 09-16 ruling limits break detection to the window, because the
  warm-start relax transient is an instrument artifact (NR-013).
- The fix is to stop counting relax-phase breaks, never to allow
  breaks. No design passes with a broken rope at its operating point.

Relayed only. Nothing edited in the draft or the register.
