# VOID — this campaign has no valid winner

**Campaign:** `v13_5kw_masslift_len18.8_rotorcount` (rotor_count_mode,
three-section TRPT geometry). Launched 2026-08-25, killed mid-flight by the
crashed session (2026-08-26).

**State of the islands:**

| island | gen reached | best fitness (kg) |
|--------|-------------|-------------------|
| 1 | 13 / 30 | 31.76 |
| 2 | 9 / 30 | 24.31 |
| 3 | 30 / 30 | 10.23 |

**Why VOID:** the combined "winner" (island 3, fitness 10.23 kg) was re-evaluated
after the FoS off-by-one fix (`73af2d9`) and **rejects**: `FoS_min = 0.556`
(was reported 67.54). The transmission-cylinder ring is buckled (util 1.75) but
the gate hid it behind the top ring. The FoS gate passed a structurally-invalid
design, so no genome in this folder is a trustworthy result.

Islands 1 and 2 also did not reach 30 generations (killed by the crash).

**Do not** re-gate, analyse, or cite any winner from this folder. The
three-section geometry + rotor_count_mode is unvalidated (DECISIONS
[2026-08-25] / [2026-08-26]; retrospective
`docs/plans/retrospective-2026-08-26-crashed-session.md`).
