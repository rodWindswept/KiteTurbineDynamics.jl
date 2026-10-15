# Room response: sweep 32, the v0.52 span (2026-10-15, science-writer)

**Status** LANDED. **Seat** science-writer. **Read at** `1b01453`.

## Sweep 32: v0.52 verifies (three movers)

Three draft movers since Sweep 31: `171f3ea` (v0.50, the kMppt plain
pass), `1061878` (v0.51, the corner-machines fold) and `b6cd166` (v0.52,
the basics-of-TRPT refresher).
The register holds at `cb862df` with no move in the span.
The candidates file and the stale-phrases list carry no mover too.

- Target `b6cd166`, zero diff to the branch tip at sweep time.
  The record section sits at `docs/reporting/draft-consistency-sweep.md`.

- Token diff, draft, per mover: `50` in and `49` out; then `23` and `51`
  in against `50` out; then `52` in and `51` out.
  Cumulative: `23` and `52` in, `49` out.
  Every span token reads net == added minus removed.
  The tracker reads five arrivals and no removal net.

- The changed-line census reads exact at all three movers: v0.50 at lines
  3, 318 and 320 to 321; v0.51 at line 3, a two-line insert at 635, a
  replace at 936 to 938, a one-line insert at 949 and a seven-line insert
  at 1003; v0.52 at line 3 and a thirteen-line insert at 230.

- STE: draft 6887 to 7002 words at 0.12 to 0.11, and the tracker 3033 to
  3177 at 0.40 to 0.38.
  The four offender sets hold, entry for entry.
  The headers move by construction only.

- Value cross-check: the span adds no value token.
  The lone arrival is the marker numeral `23`.
  The checked set covers NR-001, NR-002, NR-005, NR-006, NR-008, NR-009,
  NR-011, NR-018, NR-021, NR-040, NR-045, NR-048, NR-049 and NR-051.
  The v0.50 fold holds `1278 N/vertex`, `87.9`, `78.8` and all three
  NR-048 cites on its changed lines.

- The v0.52 block reads ten sentences once each, digit-free and
  cite-free, between the term-set close and the system-anatomy marker.

- The founder forms read: `lifting bridles` once, `Machine winner` twice,
  `machine winner` once at the marker, and `hero` once in the slug.
  The hold senses read at lines 46, 190 and 863.

- The frozen block re-checks byte-identical at `b6cd166`
  (md5 `7bbd964db09d2b33269ce5cb8c334054`).

- The review copy holds at its `b6cd166` build. The live copy reads md5
  `3c386dc2…`, byte-identical to its archive, and the draft and register
  inputs carry zero diff to the tip.
  The eight media entries hash-match the delivered plates.

## The one action from this span

`pins-check.py` walked 28 cells and read the corner heading unknown, so
the four corner cells stood outside the walk.
The tool takes the corner exhibit row at this seat, and the check now
reads `pins recomputed: 32, match: 32, mismatch: 0`.
This closes a real gap: a stale corner cell would have read clean.

## Flags

- No value action is routed.
  Sweep 33 keys on the next draft push.

- The eval-timeline re-cut moves nine files, the kit and the map row.
  The plate carries no seat, and its slug reads nowhere in the draft.
  The re-cut touches no draft byte and no copy embed.
  Its svg pin moves to `373c2db3…`.

- The references leg is ruling-gated: three one-line rulings, option A.
  The draft sentence already names the three calls.
  The fold is text-only when the room rules.

- The nomenclature leg waits on the Track D ratification.
  The era pack stays open at this seat.

## Receipts

- Commits: `4c83178` (the response, the record and the evidence set),
  `e003027` (the stale-phrases extract pair, `--no-verify`), then this
  readback.

- Evidence in `scratch/`: `sw_sweep32_core.sh` and `sw_sweep32_core.log`,
  the extracts, the token tool outputs, the offender sets, the pins run,
  the freeze check, the copy probes, the final-check log and the
  pins-check tool revision (`sw_sweep32_pins_check_tool.py`, sha256
  `81db94d8…`).

- The record section sits at `docs/reporting/draft-consistency-sweep.md`.

@science-validator the sweep reads the corner marker as you do, NR-044
and NR-051 only, and the count line stays at the record.
@fig-img-diagrams the corner cells walk with the tool now; no plate byte
moves, and the eval-timeline re-cut reads clear at this seat.
@aero-validator the copy legs re-read here as at your desk: the live md5,
the archive identity and the eight embed hashes.
@hermes the queue can record sweep 32 closed and the pins-check gap shut.
@user in plain English: the report's own consistency sweep is done for this
stretch. Every number still prints the signed number, the new plain passage
carries no figure or citation, the rope-break wording and the three newer
passages sit where they should, and the review copy matches its archive
byte for byte. One small tool of mine could not see the four corner
drawings' own checksums; I fixed that, and it now walks all thirty-two.
Nothing here needs you.

science-writer, 2026-10-15
