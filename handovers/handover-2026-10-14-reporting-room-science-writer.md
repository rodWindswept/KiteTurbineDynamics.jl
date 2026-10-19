# Handover: the science-writer seat, KTD reporting room

**Date:** 2026-10-19. **From:** @science-writer. **To:** the successor session.
**Base:** branch tip `b2e7e28` on `bank-derate-cos2p65`. The section 6.1 hold is live and comes first. The explainer block and the references gate follow at this seat.

This page holds the rotation insurance for this seat. It is an index, not a retelling.
The receipts carry the story.

## Live hold: the section 6.1 phase-2 pass (2026-10-19)

The branch is `bank-derate-cos2p65`. The draft on disk is `daab5102`
(1291 lines / 10,570 words) at commit `ad40fb1`. Nothing ran.
The script `scratch/au_sec61_phase2.py` declares the result `207bd022`.
That result is stale, and the script still inserts the retired bold rule.
**Do not run it.** The replacement script is not written yet. It has to be
built from the ruled block below.

The pass now holds six blocks. The text of each sits in the room record.

1. 1116 and 1148: `bank and steer` becomes `tilt and steer`.
2. 1117: the list item drops. The seat ruling sits in the room record.
3. 1107: the defining clause never lands. The line took the only semicolon with it.
4. 168: `ring plane` becomes `plane of rotation`.
5. The gate block replaces the old azimuth-resolved bank rule.
6. The re-declarations: PRE stays `daab5102`, and POST is re-declared once.

Measured at this desk, all re-run, all byte-identical to the room record:

| State | md5 | lines / words | STE | word leg | status |
|---|---|---|---|---|---|
| D2 | `0b9d09bd` | 1299 / 10,667 | 22 / 0.21 | `6c1396ec` | spent |
| F1 | `01e2ec9f` | 1298 / 10,664 | 23 / 0.22 | `536076fe` | spent, STE breach |
| F2 | `559ce2dc` | 1298 / 10,665 | 22 / 0.21 | `e76c8223` | spent |
| F3 | `9a7a5d17` | 1298 / 10,664 | 22 / 0.21 | `a308305d` | dead at source |
| G3 | `4b49cfca` | 1298 / 10,667 | 22 / 0.21 | `faf3d9a6` | spent |
| G4, ruled by the author | `a825aaef` | 1298 / 10,663 | 22 / 0.21 | `c5d1ebda` | declaration target |
| G5, this seat, pending | `6d047d73` | 1298 / 10,662 | 22 / 0.21 | not made | one word |

Every state reproduces: the md5, the line and word counts, and each STE
counter. The counters are passive 5, long_sentence 3, nominalization 1,
contraction 1, long_paragraph 12, semicolon 0. G4 reads five sentences of
17 / 6 / 11 / 16 / 14 words.

**The defect chain, graded from source.** F3 said the model was unbridled and
that no bridle existed. Both are false as absolutes.
`src/initialization.jl:342-359` builds N bridle segments from the lift bearing
to the hub-ring vertices, at `BRIDLE_EA` 500 kN. G3 scoped the premise to the
tether-to-blade set. G4 scoped the conclusion to match. One claim survives in
G4, and it is the word `can`: "nothing here **can** check".

That word is false too. The model computes bridle tension on every
sub-segment (`src/rope_forces.jl:404-412`), accumulates the bridle path length
and rest length (`:512-520`), and applies a bridle break test at
`ROPE_BREAK_STRAIN` 0.035 (`:618-620`). What it does not do is gate or report a
bridle load. `get_max_rope_tension` loops only `4 * n_lines * (n_ring - 1)`
shaft tethers (`:173-190`). Gates 4 and 6b read `cumulative_thrust`
(`objective_v10.jl:634-666`). No output column carries bridle tension.

Delete `can` and the sentence tells the truth without losing the rule:

> No such bridle exists to go slack, so nothing here checks that it stays loaded.

That is G5. One word. The block reads 63 words and the sentence 15. STE holds
at 22 / 0.21. @author rules the word, and @aero-validator declares from the
ruled state. If @author keeps G4, G4 stands and the declared value is its own.

**Two calls belong to @user and release the run.** One: bless the gate text.
Two: keep the gene name `bank`, or rename the command sense. The command
rename costs two prose words at 1116 and 1148 and no plate. A gene rename
re-renders two PCA panel titles, one leader inside the drawing, and three
captions.

**One figure item stays open.** @fig asks for a tip-down direction clause at
168. That would be a seventh block and one more re-measure.

**Probe files.** `scratch/au_g4_candidate.md` and `scratch/au_g4_word.md` are
the ruled G4 pair. `scratch/sw_probe_g5.py` and `scratch/sw_probe_full_G5.md`
are this seat's G5 probe. `scratch/av_g3_candidate.md` and
`scratch/av_g3_word.md` hold G3 with its verify scripts.
`scratch/sw_probe_full_D2.md`, `_F1`, `_F2` and their `_word` legs hold the
retired states.

## What this seat does

This seat sweeps the draft after every push and keeps the consistency record.
It writes the interpretive readings for figure families and hands them over as frozen blocks.
It owns the references gate and the glossary candidate supplies.
The register is the firewall: cite only signed rows, and never read raw telemetry.

The sweep procedure and the text conventions sit in the `ktd-reporting` skill.

## Open items

1. **The section 6.1 phase-2 hold.** Read the live section above first.
   The run waits on @user for two calls: the gate text, and the gene name.
   The G5 word waits on @author.
   Nothing runs and the draft stays at `daab5102` until both land.

2. **Sweep 35 on the next draft push.**
   The next movers now due: the figure re-stamp at the scaling-ladder
   kit, the hermes rebuild and the author rebuild verification.
   A-13 and A-20 to A-22 stay gated as routed.
   The sweep keys on the next push. The section 6.1 pass lands before it.

3. **The explainer block.**
   The round-4 routing seats the kg-equivalent explainer block on this seat.
   It lifts from the printed section 2.4 block and NR-046.
   This is the next writing item.

4. **The references gate.** Three source calls stay pending in `references.bib`: the
   Ranneberg report, the Jamieson slides and the Hancock slides.
   Each needs an own-source read or a room decision before prose cites it.
   The pass lands as `docs/reporting/references-verification.md`.

5. **The Nomenclature fold.** The term gate cleared at `cadf83d`.
   The fold runs with the lead and this seat.
   The three projection terms sit in the candidates for Track D.

6. **The reading scope.** The thrive/fail view (figure-map row 22) joins the levers reading if it lands.

7. **Signal.** Sign Signal posts as the science-writer seat. Never post in the Signal Note to Self channel.

## Closed, last (evidence index)

- Section 6.1 phase-2 verification (2026-10-19): G4 reproduced at `a825aaef`, word leg `c5d1ebda`, all STE counters equal. G5 probe at `6d047d73` stands pending the author's word. Probe `scratch/sw_probe_g5.py`. F3, G3 and the four earlier states are retired.

- Sweep 34: the record section sits in `docs/reporting/draft-consistency-sweep.md` and the receipt lands beside this page. The span `de18442..7e60f37` verifies the house-vocabulary swap.

- Sweep 33: commits `c27b677` to `79e75df`. Receipt `docs/reporting/room-responses/science-writer-2026-10-18-sweep-33.md`. The span `1b01453..de18442` verifies the A-10 to A-19 prose pass and folds the levers re-freeze.

- The levers re-freeze: the block, the receipt region and the md5 record refresh at `0d9001e4c19c78cc239cc22f8ac6dba7`. The break commits `f7de920` and `646cddf` record beside the new md5. The pre-break md5 `7bbd964db09d2b33269ce5cb8c334054` stays as the record.

- Sweep 32: commits `4c83178` to `fc57814`. Receipt `docs/reporting/room-responses/science-writer-2026-10-15-sweep-32.md`. The span `ffc63a7..1b01453` verifies the three movers.

- Sweep 31: commits `45ed846` to `459eee2`. Receipt `docs/reporting/room-responses/science-writer-2026-10-15-sweep-31.md`. The span `4ded913..ffc63a7` verifies the two movers and folds the lifting-bridles term set.

- The lifting-bridles term set: commits `97eefdc` to `ffc63a7`. Receipt `docs/reporting/room-responses/science-writer-2026-10-15-lifting-bridles-term-set.md` sits beside this page.

- Sweep 30: commits `94742ec` to `72115e7`. Receipt `docs/reporting/room-responses/science-writer-2026-10-15-sweep-30.md`. The span `8a1e552..4ded913` verifies the four round-6 movers.

- The round-6 legs: commits `69ec727` to `50e0300`. Receipt `docs/reporting/room-responses/science-writer-2026-10-15-round6-legs.md` sits beside this page.

- Sweep 29: commits `cde8089` to `e104f30`. Receipt `docs/reporting/room-responses/science-writer-2026-10-14-sweep-29.md`.

- Sweep 28: commits `4b19592` to `d2a57aa`. Receipt `docs/reporting/room-responses/science-writer-2026-10-14-sweep-28.md`.

- Sweep 27: commits `b526161` to `0f46aa7`. Receipt `docs/reporting/room-responses/science-writer-2026-10-14-sweep-27.md`.

- Sweep 26: commits `89ddfde` to `a359061`. Receipt `docs/reporting/room-responses/science-writer-2026-10-14-sweep-26.md`.

- Sweep 25: commits `ff159d7` to `bbc214e`. Receipt `docs/reporting/room-responses/science-writer-2026-10-14-sweep-25.md`.

- Sweep 24: commits `17a9016` to `ad3eec8`. Receipt `docs/reporting/room-responses/science-writer-2026-10-14-sweep-24.md`.

- Sweep 23: commits `80685c3` to `9553780`. Receipt `docs/reporting/room-responses/science-writer-2026-10-14-sweep-23.md`.

- The levers reading: `a011c26`. Receipt `docs/reporting/room-responses/science-writer-2026-10-14-levers-reading.md`. The block froze at md5 `7bbd964db09d2b33269ce5cb8c334054` and re-froze at `0d9001e4c19c78cc239cc22f8ac6dba7` on 2026-10-18.

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

**Owner:** @science-writer. **Next action:** the section 6.1 hold. Declare from the ruled state once @user makes both calls and @author rules the G3 repair. Then the explainer block, then the references gate. Sweep 35 keys on the next draft push.
