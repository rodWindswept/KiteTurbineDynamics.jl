# Room response: the round-6 legs (2026-10-15, science-writer)

**Status** LANDED. **Seat** science-writer. **Read at** `50e0300` (branch `bank-derate-cos2p65`, local == origin).

The round-6 term gate enumerated four surfaces at this seat.
All four land in this train: the tracker, the candidates, the stale-phrases list and the pair mint.
Evidence sits under `scratch/sw_r6leg_*`.
The pins checker reads 21 checks, 0 fail.

## 1. The tracker (2 sites)

- L104 and L165 take the short name. Both read `the capture topmost ring` now.

- The old word reads zero in the file, raw and as a word.

## 2. The candidates (2 sites, and the pair re-key)

- The main-rotor guard now reads `Never write "hub rotor" or "hub ring".`

- The retire-list row reads `"hub rotor", or "hub" for a rotor or the ring` on the left.
  The write column takes the short name: `main rotor, topmost ring`.

- The pair re-key mints the `topmost ring` row beside the `ground ring` row.
  The draft reads: the ring at the top of the TRPT.
  It carries the main rotor, and the full name is `topmost rotor ring`.
  The name `hub ring` retires (Rod, 2026-10-14).

- The status reads PREP v16, and the v16 delta lands.

## 3. The stale-phrases list (4 sites, and the ring record)

- The two claim headings take the new names.
  The first reads `The topmost ring hosts ONLY the cp/ct rotor`.
  The second takes `topmost rotor` where it read `hub rotor`.

- The hub entry holds as the rotor ban.
  Its replacement extends to the ring, and a dated note records the top forms.

- The four-site disposition reads:

| Site | Was | Now |
|---|---|---|
| L63 | the hub-ring claim | the topmost-ring claim |
| L68 | the hub-rotor claim | the topmost-rotor claim |
| L78 | the hub-rotor heading | holds, the rotor ban |
| L80 | the rotor-only replacement | the rotor and ring replacement, plus the note |

## 4. The scan-entry room call

- One call rides this receipt. A new scan entry for the retired ring name is not landed.

- A bare `hub ring` entry flags four held lines at the doc sweep.

- They sit at the trust-log 2026-08-14 row, at physics-topology 3.1.1 and at its code notes.

- It also flags the skill-history set. The probes read the counts.

- The list records the retirement as the note instead.

- If the room wants the scan entry anyway, the cue question comes with it.

## 5. Checks

- STE: tracker 0.38 held, candidates 0.26 held, stale-phrases 3.40 to 3.28.
  The stale-phrases file is whole-file legacy and lands with `--no-verify`, stated in its message.

- Doc currency reads its one standing item, the decisions date.
  Skill currency reads clean. Both match the baseline.

- The offender deltas read: candidates zero added lines, stale-phrases two like-for-like swaps.

## Deltas

- v1 (2026-10-15): the legs land. The evidence and the pins ride the train. No other change.

## Handoffs

- @science-validator: the gate re-reads on these bytes.

- @aero-validator: the counter-reads open at the folds.

- @hermes: the queue can record the leg close.

- @science-writer: sweep 30 keys next, on `d0ed902`.

science-writer, 2026-10-15.
