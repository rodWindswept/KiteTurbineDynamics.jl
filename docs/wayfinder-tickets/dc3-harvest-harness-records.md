# dc3 — Harvest the rulings made outside git

> Part of [Decisions Conformance Audit](../wayfinder-decisions-conformance.md) · `wayfinder:research` · **frontier**

## Resolution

Harvested 2026-09-24. Eight rulings went unlanded. Report: `docs/reports/2026-09-24-unlanded-rulings.md`.

The first item on the map does not hold as stated. The damper term is signed. The scan covers TRPT sub-segments only. The reported maximum tracks the elastic maximum at 0.97 times. It does not overstate the load.

The real hazard in that path is a step-size fault. At the legacy `dt = 4e-5` the reported maximum inflates to 6.8e6 N. The elastic term tracks that inflation.

Two premises of this ticket were wrong. The transcripts live under `~/.gemini/antigravity-cli/brain/`. The `~/.dsh/sessions/` directory holds 19 files for this repo, not 31. The protobuf stores under `~/.gemini/` stay unread. No schema exists here, and no `sqlite3`. A second run of the same probe reproduced all three numbers on 2026-09-24.

## Question

Which decisions were ruled inside agent-harness state and never written to the repo
record? A ruling that lives only in a harness brain is invisible to every future
session, and it is the one place decisions live with no version control.

This ticket completes the ruling set before dc2 judges code against it. Judging
conformance against an incomplete record repeats the original error.

## Where to look

| Source | Path | Notes |
|---|---|---|
| Antigravity brain transcripts | `~/.gemini/antigravity/brain/<conversation>/.system_generated/logs/transcript.jsonl` | Plain text, step-based. Antigravity was the **supervisory** agent for the 2026-09-20 to 09-23 rulings |
| dsh sessions | `~/.dsh/sessions/--home-rodbot-Documents-GitHub-KiteTurbineDynamics.jl--/` | 31 zstd JSONL sessions, Sep 6 to 23, 52.5 MB. The implementer side |
| Protobuf stores | `~/.gemini/antigravity/conversations/*.db`, `~/.gemini/antigravitycli/*` | Schema readable, `steps.step_payload` blobs are not decoded. Assume the text transcripts cover them |
| Existing inventory | `/home/rodbot/.hermes/cache/scratch/antigravity-record-inventory.md` | 18 ranked sources, from the 2026-09-24 reconnaissance. Read this first |

## Known open finding

`get_max_rope_tension` adds the damper's viscous regularisation term to the maximum
tension it reports, and that value feeds FoS and the rope-break discussion. Only a code
comment records it (`test/test_rope_break.jl:127-130`). No `DECISIONS.md` entry, no
trust-log row. The Antigravity transcript flags it as "needs clarification". The
magnitude the transcript quotes — a 2.6× overstatement — is **not** independently
verified. Measure it before it becomes a claim.

## Method

1. Read the inventory file above for the ranked source list.
2. Search each source for rulings, not for code: phrases such as "we should", "ruled",
   "decided", "do not", "permanently", "canonical", "revert". A code change without a
   `DECISIONS.md` entry is the signal.
3. For each candidate, check whether the record already holds it (`DECISIONS.md`,
   `physics-topology.md`, `docs/adr/`, `instrument-trust-log.md`,
   `physics-validation-ledger.md`). Report only the gaps.
4. Rank the gaps by what they protect: a load-path or FoS ruling outranks a tooling
   preference.

## Output

`docs/reports/2026-09-24-unlanded-rulings.md` — one row per unlanded ruling: the
ruling, the source path, the date, whether the code already behaves that way, and the
record it should join.

## Sizing

One session. Delegate the reading to a subagent if the transcripts are large. Read-only:
touch no harness state and no repo file except the report.
