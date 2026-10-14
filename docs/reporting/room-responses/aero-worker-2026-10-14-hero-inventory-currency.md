# Room response: hero-image status, waiting inventory, currency sweep actioned (2026-10-14, aero-worker)

Rod asked two things in the channel. This page holds the answers for
the lead.

## 1. Hero image: it is in the report

Yes. The machine-winner hero landed in draft v0.41.

- §3.3 carries the seat marker for figure-map row 10 (slug
  `machine-winner-hero`), citing NR-011, NR-017, NR-021, NR-022 and
  NR-043.
- The kit holds plan, side and downwind of the island-3 winner at its
  recorded final operating pose, drawn from the signed pair extract
  (NR-021, NR-022). No ODE. CairoMakie 2D, one scale, shared datum.
- Three fresh runs are byte-identical across all five outputs after
  the mutool garbage-collect fix (c438398). The capture set and the
  draft fold landed in e8159b0.
- The figures seat closed the hero counter-read at 60f5a32: 226
  checks, 0 fail, clean v0.41 read.

The next build after e8159b0 carries it. The lead should rebuild and
send so Rod sees the hero in the copy.

## 2. The waiting inventory (for the lead answer)

The room queue (handover-2026-10-14-reporting-room-queue.md, open
queue in fold order):

1. Hero: DONE since the queue wrote it (above).
2. @author: AU9 and the partner-gated tails.
3. @author + @fig-img-diagrams: the kMppt ask (founder). Structural
   sentence pass, the kMppt-space graphic, the row-5 plate waits on
   Rod's visual pass.
4. @hermes + @science-writer: Nomenclature fold. Term gate cleared.
5. @science-writer: sweep 27, the explainer block, the references
   gate (three pending source calls: Ranneberg, Jamieson, Hancock).

Standing open items: the era call (routed, no ruling), the rope-break
gate placement fix (NR-013, Harris 3.8), the rapid path until that
fix lands.

## 3. Doc-currency sweep: actioned, not just reported

All three findings from the 2026-10-14 sweep are now closed:

- handovers/README.md: the seven missing rows added.
- instrument-trust-log.md: the NR-013 warm/rapid false-reject row
  added to the Fault Ledger, stamp bumped to 2026-10-14.
- DECISIONS.md date gap: verified no entry owed. The checker now
  learns the exemption: it flags that gap only when a src/ or test/
  commit landed after the newest DECISIONS entry. Docs-only weeks no
  longer flag.

Both checks now pass: doc_currency_check.py exits 0. Committed at
b86b750.
