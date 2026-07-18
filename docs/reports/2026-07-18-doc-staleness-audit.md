# Documentation Staleness Audit — 2026-07-18

**Provenance:** generated 2026-07-18 against HEAD `cfd2128` ("Phase 1 complete: all
builder tests green"). Mechanical scan: `scripts/doc_staleness_audit.py` (committed
alongside this report; rerunnable). Claim verification: 6 read-only subagent passes
against source, per the `verify-model-claims` method. Working tree was dirty
(25 modified / 32 untracked) — dirty files dated by mtime.

**Question asked:** do we have too much documentation separated from the code,
risking silent staleness when code changes — and was that a precursor to the
recent confusion over code state (builder bug)?

**Verdict: yes, quantifiably.** 33k lines of markdown vs 15k lines of `src/`
(2.2×). Of 78 load-bearing claims verified in the 7 highest-risk docs, **31 (40%)
were false, stale, or unverifiable**. Three dated events each silently falsified a
class of documented numbers, and no mechanism existed for prose to fail loudly.

---

## 1. Method

1. **Heuristic classification** of every `*.md` by durability (path/filename
   conventions, ~90% accuracy by design — hours→minutes trade).
2. **Staleness-lag scan**: doc git-date vs git-date of every `.jl` file the doc
   references; broken-reference detection.
3. **Claim verification** on the scored shortlist: subagents traced each
   load-bearing claim to `path:line` or data-file provenance.
4. **Prescription**: locality-restoring moves (below).

## 2. Mechanical findings (scan of 218 md files)

| Class | Files | Lines | Meaning |
|---|---|---|---|
| Durable | 13 | 3,925 | CONTEXT, DECISIONS, ADRs, agents docs — must stay true |
| Ephemeral | 96 | 15,251 | plans/handovers/PRDs/tickets — historical by design |
| Claims-bearing | 86 | 10,661 | reports/outreach/results — stale the moment code moves |
| Dead | 23 | 3,655 | backup_conflicts_pull (7 outreach dupes), archive, scratch |

- **114 live docs** reference code newer than the doc (max lag 87 days).
- **18 docs / 30 broken code refs.** Caveat learned this run: a "broken ref" may
  correctly *document a deletion* (DECISIONS.md:102 on `hunt_kmppt_maxpower.jl`
  is proper history, not an error). Only 1 of DECISIONS.md's 2 flags was real.
- 23 live docs carry 12-gon geometry claims; post-fix these are true of the
  *code* but any pre-fix *numbers* in them were computed on the triangle.

## 3. Dated mass-staleness anchors

Any number's provenance date must be checked against these before quoting
(also recorded in the `verify-model-claims` skill):

| Date | Event | Invalidates |
|---|---|---|
| 2026-06-10 | Aero-table swap, `830950c` (AeroDyn v5.0.0, 0° elev). Peak Cp 0.232→**0.309 @ λ≈5.2**; CT(4.1) 0.548→**0.653** | every prior Cp/CT number |
| 2026-07-04 | Settle k_mppt bug fix (ADR 0004; settled at k=614.9 not ~15.6) | every prior dynamic settle result |
| 2026-07-17 | Builder x-vector fix `7d43455` (pre-fix as-built = n_lines=3 triangle) | every prior V10 Tight numeric result |

## 4. Verified-claim results (78 claims across 7 docs)

Totals: **47 TRUE (60%) · 7 FALSE · 20 STALE · 4 UNVERIFIABLE.**

| Doc | True | False/stale | Disposition | Worst finding |
|---|---|---|---|---|
| `docs/audit-literature-crosscheck.md` | 7/15 | 8 | update | presents its 3 HIGH-severity findings as open; all were fixed by the aero overhaul |
| `references/rotor-sizing-problem.md` | 3/10 | 6 | **bannered** | "Status: Open" but every blocking item landed (self-consistent solve `objective_v6.jl:568`, calibrated coeffs `expansion_rotor.jl:70–72`) |
| `docs/validation/2026-04-19-report-validation.md` | 8/13 | 5 | **bannered** | its Cp "correction target" 0.232 is itself stale (now 0.309) |
| `docs/phase_n_pitch_depower_diagnostics.md` | 8/12 | 4 | update | metrics table no longer reproduces; figures point at nonexistent `/home/rod/.gemini/…` |
| `docs/outreach/strathclyde_qa_verified.md` | 9/12 | 3 | **bannered** | "code-verified 2026-07-17" stamp written same morning *before* the 12:13 fix commit; Q5 describes pre-fix builder |
| `docs/outreach/figure-review.md` | 6/8 | 2 | **bannered** | the 2 stale rows carry every headline number; `wind_sweep.csv` at HEAD is byte-identical to the triangle legacy CSV |
| `docs/awes-forum-diagrams/awes-forum-v62-report.md` | 6/8 | 2 | keep | L313 data pointer wrong: V6.2 dir's `best_design.json` was overwritten by a v6.3 smoke test |

External-disclosure check: everything false that was shared with Strathclyde is
already covered by `docs/outreach/email-hong-amjad-builder-bug.md`. **No new
disclosure triggered.**

## 5. Corrections applied after review (2026-07-18)

- **V6.2 artifact NOT lost.** The audit initially reported the corrected V6.2
  optimum (n_lines=12, 74.17 kg) destroyed — it checked the working tree only.
  Recovered verbatim from `3fcc795`; see
  `scripts/results/v6_2_campaign_50kw/RECOVERY_NOTE.md` and the sidecar
  `best_design_v62_true_optimum_recovered_from_3fcc795.json`. HEAD's
  `best_design.json` deliberately untouched (post-06-18 scripts read it).
- **Re-run gate is in flight, not open.** Triangle3 wind sweep + 12-gon recheck
  running as of 2026-07-18. **Do not regenerate Phase-E figures until those
  CSVs land** — the current PNGs (rendered 07-17 12:05, eight minutes pre-fix)
  plot triangle data.
- **DECISIONS.md broken refs:** 1 of 2 was a false positive (see §2).
  The real one — `src/bem_cp_model.jl` cited as live at :1912; the file never
  existed in git history (surface lives in `src/bem.jl`) — annotated in place.

## 6. Audit blind spots (for the next run)

1. Working-tree-only artifact checks — always consult `git log`/`git show`
   before declaring data lost.
2. Broken-ref flags need human context reads (documents-deletion ≠ cites-as-live).
3. Filename-based classification misjudges ~10%; never archive/delete on
   classification alone.

## 7. Prescription and status

| # | Action | Status |
|---|---|---|
| 1 | Fix durable layer: DECISIONS.md `bem_cp_model.jl` annotation + 4 banners | **done 2026-07-18** |
| 2 | Claims live in tests: `test/test_documented_claims.jl` asserting externally-quoted anchors (167.474 kW legacy row, builder fingerprint, params_10kw blade consistency) | **done 2026-07-18** |
| 3 | AGENTS.md rule: plans/handovers/PRDs are historical record; only CONTEXT.md, DECISIONS.md, ADRs, and tests describe the present | proposed |
| 4 | Provenance stamps (git hash + script + date) mandatory on generated reports; never hand-edit numbers into claims-bearing docs | proposed (this report complies) |
| 5 | Delete dead 23 (after content read; `backup_conflicts_pull/` confirmed outreach-dupes-only, no campaign artifacts) | proposed |
| 6 | Update `docs/audit-literature-crosscheck.md` — mark findings #1–#4 RESOLVED with commit refs | proposed |
| 7 | Monthly lag-scan health check (skill + scheduled run of the script) | **done 2026-07-18** |

## 8. Rerunning

```
python3 scripts/doc_staleness_audit.py            # summary to stdout
python3 scripts/doc_staleness_audit.py --json /tmp/doc_audit.json --top 40
```

Verify shortlisted docs per the `verify-model-claims` skill (three staleness
anchors are recorded there). Expect and welcome a 30–50% rejection rate on
recommendations — mechanical output is a shortlist, not a to-do list.
