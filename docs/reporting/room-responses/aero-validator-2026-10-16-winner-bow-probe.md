# Room response: the winner bow probe lands at the aero seat (2026-10-16, aero-validator)

**Status** The bow read lands. The September check for the winner reads: the settle and the run do not agree on the bowed shape. The disagreement prints as an instrument finding, per the 2026-09-15 ruling.

**Seat** aero-validator. **Read at tip** `4e9c6bd`. **Machine** the bankderate2 island-3 winner (NR-005). **Supply** `scratch/av_bow_read_supply.md`.

**Evidence** `scratch/av_bow_probe.jl` (sha256 `24a1601718dcb2d8536872ca975b6a823fed640e72686486c434fdc6216c73a4`), `scratch/av_bow_probe.log` (sha256 `eacc0ce3acbcdeb66b6dd9db975b177ceb401a2929bee2c40fd258e22f2bf987`), iteration logs `scratch/av_bow_probe_run1_buggy.log`, `scratch/av_bow_probe_dbg.log`, `scratch/av_bow_probe_interrupted_2026-10-15-sig15.log`.

The founder ruled "up" on 2026-10-15. This seat then ran the probe for the winner bow at the founder station. The probe also answers the Harris 2.12 question for the winner.

## 1. The bench

The read runs the NR-016 cold re-eval protocol at this tip. Phase 1 and the manual pass reproduce the recorded digits at all printed places.

```text
bench gates vs recorded: fitness true (27.3635412663488)  omega_eq true  P_end true  twist true  FoS true
protocol gates vs phase 1: settle-omega true  P_end true  twist true  FoS true
```

The machine reads `n_ring` 6, `n_total` 53, `n_active` 1 and `m_air` 25.6985 kg. The column spans 18.714 m on the design axis at 30 deg. Ring 6 carries the main rotor (r 4.580 m). Rings 1 to 5 read r 0.804 m. The geometry matches NR-011.

## 2. The settle-state read

The settle hands the machine off straight. The largest per-ring offset from the design axis reads 0.00241 m, at ring 6.

```text
SETTLE profile max = 0.00241 m at ring 6 (s_axial 18.714)
SETTLE hub perp (ring 6) = 0.00241 m ; mid-span ring 5 (s_axial 9.376) perp = 0.00160 m
```

The direction at the max ring resolves straight down in the perpendicular plane (`down_frac` 0.9999). The offset is the gravity sag. It is not a sideways move.

## 3. The run-window read

The run bows the machine straight down. The scored window reads 40 samples (t = 11 to 50 s). No line breaks.

| ring | settle m | window min m | window mean m | window max m |
|---|---|---|---|---|
| 5 (midpoint) | 0.00160 | 0.10531 | 0.22288 | 0.31005 |
| 6 (hub) | 0.00241 | 0.20862 | 0.44098 | 0.61302 |

The bow appears through the relax phase. The hub reads 0.002406 m at t=0 s and 0.19272 m at t=10 s. The max station is the hub in all 40 samples. The profile grows with `s_axial` (a whole-column lean, not a mid-span belly).

## 4. The extension run (t = 50 to 200 s)

The extension runs 150 s more from the window end. The hub series reads 0.64199 m at t=55 s and 0.83331 m at t=195 s. The last increment reads +0.00053 m per 5 s at the hub, about 0.1 mm/s. The shape approaches a quasi-terminal value near 0.83 m at the hub. The midpoint ring reads 0.42202 m at the last sample. No line breaks.

## 5. The September check

The check asks one question: do the settle and the run agree on the bowed shape? This read answers it for the winner.

- The settle shape reads straight (max 0.00241 m).

- The run shape bows downward (window mean 0.44098 m at the hub).

- The largest deviation reads 0.43857 m at ring 6 (settle against the window mean).

- The topology agrees (max ring = the hub, direction straight down).

- The magnitude does not agree. The script prints: "the two solvers do NOT agree on the shape at this state."

Per `DECISIONS.md` [2026-09-15] ruling 2, a settle/ODE bow disagreement is an instrument finding. It is a re-initialisation or force-scaling bug, not a design question. This receipt prints the finding for the winner.

The run is not divergent. It approaches a quasi-terminal bowed shape near 0.83 m at the hub. The settle does not carry that shape. That measured case stands for the open settle workstream item.

## 6. The founder line

The founder fixed the bow station on 2026-10-15: the midpoint ring belly drop from the common axis. This read meets the line at the same station and the same state.

| state | midpoint ring (ring 5) |
|---|---|
| settle | 0.0016 m |
| window (scored) | 0.10531 to 0.31005 m |
| extension end | 0.42202 m |

Every state reads below 0.5 m against the 1.5 m line. The mapping clause: the max sits at the hub. The midpoint ring reads about half the hub value. The ratio reads 0.5058 at t=50 s and 0.5064 at t=195 s.

Context only: the 2026-09-21 audit recorded the hub at 1.1 to 1.25 m on the earlier machine class. Rod ruled that reading expected. This machine reads 0.83 m at the hub. The machines differ, so this is not a comparison.

## 7. Evidence and instrument history

- Run 1 tripped a Julia scoping bug: the `bow_table` locals clobbered the main arrays. Post-run reads then showed the last sample, and the settle column of the window table read wrong.

- The fix gives every nested local a unique name and adds an integrity check. The check reads true in the read log: `integrity: settle arrays unchanged after both runs = true`.

- The debug log traces the clobber by object identity before the fix.

- The interrupted log records a shutdown (signal 15) part-way through a clean run on 2026-10-15. The read re-ran on 2026-10-16.

- Three runs at this tip reproduce the bench digits and the window series. The first two carried the settle-column defect only. The fix landed before the read, and the read is clean.

- The read log ends at `AV_BOW_PROBE_DONE`, and the run shell exited 0.

## 8. Boundaries

- This read does not fix the static solver. The fix stays a code workstream. This read supplies the measured case.

- No existing number moves. The read does not re-open the barred 1.5 m estimate.

- The register row signs at the science desk. The proposed NR-059 sits in the supply.

- The report sentence waits on that sign at the author seat.

## Handoffs

- @science-validator: the read is ready for the row. The supply carries the proposed NR-059 with value, station and state.

- @author: the section 3.3 sentence can fold once NR-059 signs. The agreement verdict reads "do not agree, instrument finding".

- @hermes: the queue can record the bow probe landed. The Harris 2.12 item reads answered for the winner.

Recorded by @aero-validator (aero seat).
