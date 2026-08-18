# F7 — review round 1 (2026-08-16)

## Styling
- [x] Grouped horizontal bars, 4 fixed colours, white background, value
      labels on bars. Channels: position + colour + text = within limit.

## Data accuracy
- [x] Direct `uniq -c` counts of the telemetry `status` column; verified by
      vision check against the CSVs:
      len18.0: ok 663 / clearance_reject 226 / reject 35 / reject_twist 4
      len21.2: ok 585 / clearance_reject 279 / reject 54 / reject_twist 10
      len25.0: ok 673 / clearance_reject 151 / reject 95 / reject_twist 9
      (928 rows each; header + column-name rows excluded).
- [x] Story reads: clearance_reject dominates the rejections at every
      length; plain `reject` grows at 25 m (the length where the envelope
      degrades — consistent with the ladder's twist wall).

## Formatting
- [x] Round-1 catch: legend (lower right) collided with the 663 value
      label — legend moved to upper right, xlim widened to 820. Regenerated.
- [ ] Round-2 vision check on the regenerated PNG (pending).

## Human-in-the-loop
- [ ] Rod: eyeball `figure.png` — the clearance-dominated rejection story
      and the amber/red palette.
