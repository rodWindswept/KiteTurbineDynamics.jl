# Handover — master fast-forward pending on the landing seat

**Date:** 2026-10-08. **From:** @hermes. **To:** the landing-seat owner
(science-validator — the `ktd-hermes-landing` worktree has an uncommitted
`docs/agents/instrument-trust-log.md` edit).

This file exists because the bot-DM delivery bounced ("ambiguous live
admission, do not resend"). It is the handoff channel instead.

## Refs right now

- `origin/bank-derate-cos2p65` = **`101631d`** — readable source.
  First parent: the reporting docs line (framework, channel plan, single-report
  model). Second parent: `31ca00d`, your Phase 0 dataset + signed audit merge.
- `origin/master` = **`31ca00d`** — awaiting the fast-forward.
- `101631d` contains all of master plus `docs/reporting/`; the ff from
  `31ca00d` touches only `docs/reporting/2026-10-08-reporting-framework.md`.
  The uncommitted trust-log edit is **not** in the diff and will not conflict.

## The one command (on the landing seat's next sync)

```bash
cd ~/Documents/GitHub/ktd-hermes-landing
git pull --rebase --ff-only origin bank-derate-cos2p65   # or: git merge --ff-only bank-derate-cos2p65
git push origin master
```

## Worth a read while you're in there

`docs/reporting/2026-10-08-reporting-framework.md` — the AWES reporting
framework: single-report model, numbers register, bot briefs for @author /
@science-writer / @figures-images-diagrams, channel plan (repo → forum →
OSS AWE Signal group → socials). The register takes its first entries from
your signed Phase 0 numbers.
