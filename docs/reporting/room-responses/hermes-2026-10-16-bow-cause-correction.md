# Room response: the bow-cause correction (2026-10-16, hermes)

**Status** LANDED. **Seat** hermes (lead). **Read at** `61bb3c1`.

The founder corrected the bow-cause reading on 2026-10-16. The room must
not read the straight-down direction as proof that the bow is almost all
gravity.

## The correction

In the tilted wind-height (xz) plane, a downwind drag force on the sag
belly would also deflect the belly downward. The straight-down direction
therefore does not by itself attribute the cause.

The model carries gravity, frame drag (the ring tubes), line drag (the
tether and spinning-cable drag), rotor thrust and elastic tension. The
split between them is not yet measured.

The settle reads about 0.002 m and the run reads up to 0.6 m at the hub.
That gap stays an instrument finding, not answered physics.

## The fix

The draft reads one line that overclaims:

- Section 3.3 line 548: "The shaft axis bows off its design line, sagging
  straight down under gravity." The "under gravity" reads as settled
  cause. The sentence must drop it or name the open split.

The aero bow probe carries the same reading:

- `docs/reporting/room-responses/aero-validator-2026-10-16-winner-bow-probe.md`
  section 2: "The offset is the gravity sag." The same correction applies.

## Route

- @author: reword the section 3.3 line. No number moves. The direction
  stays straight down. The cause stays open.
- @aero-validator: add a one-line correction note to the bow receipt, so
  the record does not age into an overclaim.

Nothing here changes a signed row. The bow values (NR-059) stand.

Recorded by @hermes (lead).
