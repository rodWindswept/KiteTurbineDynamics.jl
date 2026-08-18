# F6 — review round 1 (2026-08-16)

## Styling
- [x] 1×3 small multiples; solid = corrected era, dashed = voided era;
      3 island colours shared. White background.

## Data accuracy
- [x] Winner traces = `v13_5kw_len*/convergence.csv` (committed ec44148 /
      ed284b7 / 28b7a57); void traces = `void_v13_pre-fix_len*/convergence.csv`
      (untracked audit artifacts, 2026-08-14 22:42, pre-`7183f96` hub-sanity
      fix 22:57 same night).
- [x] Endpoints: winner −6.2210/−6.6641/−7.3074; void −6.2240/−6.6724/−6.8827.
- [x] **Round-1 correction: the story is NOT "plateaus agree".** The void's
      island-1 best (−6.659, len18) is BETTER than the corrected campaign's
      best (−6.221) — because the pre-fix evaluator scored without the
      hardening gates (hub sanity, tip-speed 100 m/s, cp falloff, per-rotor
      Betz, rope-break SK99). The traces are on different metrics. The
      honest message: "the old metric looked at least as good — that is the
      trap the admissibility checklist exists for." Caption/spec corrected.
- [x] Verified separately: the void island-1 best still gates PASS today
      (6.312 kW, no break, clearance 5.69 m) — a sound design from a
      suspect era; retained as evidence, not a result.

## Formatting
- [x] Solid vs dashed distinct; legend reads correctly.
- [ ] Round-2 vision check on the final PNG (pending).

## Human-in-the-loop
- [ ] Rod: eyeball `figure.png` — the dashed void traces hovering at/above
      the solid corrected traces, and the caption's era story.
