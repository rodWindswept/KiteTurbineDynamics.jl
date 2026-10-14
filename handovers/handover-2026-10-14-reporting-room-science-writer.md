# Handover: the science-writer seat, KTD reporting room

**Date:** 2026-10-14. **From:** @science-writer. **To:** the successor session.
**Base:** branch tip `e0919ff` on `bank-derate-cos2p65`. The sweep 22 push follows this page.

This page holds the rotation insurance for this seat. It is an index, not a retelling.
The receipts carry the story.

## What this seat does

This seat sweeps the draft after every push and keeps the consistency record.
It writes the interpretive readings for figure families and hands them over as frozen blocks.
It owns the references gate and the glossary candidate supplies.
The register is the firewall: cite only signed rows, and never read raw telemetry.

The sweep procedure and the text conventions sit in the `ktd-reporting` skill.

## Open items

1. **Sweep 23 on the next draft push.**
   The next mover is the consistency sweep on the author seat
   (the classified counts, the units set and the bracket moves).
   The sweep keys on its push.

2. **The explainer block.**
   The round-4 routing seats the kg-equivalent explainer block on this seat.
   It lifts from the printed section 2.4 block and NR-046.
   This is the next writing item.

3. **The references gate.** Three source calls stay pending in `references.bib`: the
   Ranneberg report, the Jamieson slides and the Hancock slides.
   Each needs an own-source read or a room decision before prose cites it.
   The pass lands as `docs/reporting/references-verification.md`.

4. **The glossary term gate.** The term gate with @science-validator keys on
   the v15 rename. That form reads across the draft and the glossary row.
   The three projection terms sit in the candidates for Track D.

5. **The reading scope.** The thrive/fail view (figure-map row 22) joins the levers reading if it lands.

6. **Signal.** Sign Signal posts as the science-writer seat. Never post in the Signal Note to Self channel.

## Closed, last (evidence index)

- Sweep 22: the record section sits in `docs/reporting/draft-consistency-sweep.md`, and the receipt lands in `docs/reporting/room-responses/` beside this page.

- Sweep 21: commits `f153802` to `852d4bd`. Receipt `docs/reporting/room-responses/science-writer-2026-10-14-sweep-21.md`.

- Sweep 20: commits `d7ece07` and the push tail. Receipt `docs/reporting/room-responses/science-writer-2026-10-14-sweep-20.md`.

- The levers reading: `a011c26`. Receipt `docs/reporting/room-responses/science-writer-2026-10-14-levers-reading.md`. The block is frozen at md5 `7bbd964db09d2b33269ce5cb8c334054` and folds at section 3.4.

- Glossary v13, v14 and v15: `724b226`, `4e559de` and `57c77cf`. The candidates record sits at `docs/reporting/glossary-candidates.md`.

## Boot

- Repo `KiteTurbineDynamics.jl`, branch `bank-derate-cos2p65`. Fetch first. Every seat pushes to this shared tree.

- Read `handovers/handover-2026-10-08-reporting-room-boot.md` and the rulings page beside it. Then the register at `docs/reporting/numbers-register.md`.

- Load the skills `ktd-reporting` and `ste-writing` before the first pass.

- Nothing of this seat lives only in a chat. This page plus the receipts resume the seat in one readback.

## Working rules

- Cite only signed rows. The sweep changes no draft line and no register row.

- Stage only your own paths. Peers may hold staged files in this shared tree.

- Add evidence logs with `git add -f`. The `*.log` pattern sits in `.gitignore`.

- Run `python3 ste-lint.py --fail-above 2.0` on a new file before the commit.

- Verify the push. The local branch matches origin, and each blob reads byte-identical at origin.

- Never run `git clean` in this tree. The untracked files carry seat evidence.

- Route findings through the room and the receipts. The Signal mechanics sit in `docs/reporting/room-responses/aero-validator-2026-10-12-signal-silence-mechanics.md`.

**Owner:** @science-writer. **Next action:** sweep 23 on the next draft push, then the explainer block.
