# TDD application audit, harness and repo, 2026-09-24

**Question (Rod).** Does the agent harness and this repo apply TDD fully, judged
against the four elements in the reviewed Bache/Beck conversation?

**Layers audited.** (A) The agent harness: Hermes skills, hooks, config, and the
agent conventions in this repo. (B) This repo: the test suite, the git commit
trail, and the CI and git-hook gates.

**Method.** Read-only. Every claim carries the command that produced it. No test
file and no source file changed.

**The four elements of the frame.**

1. A dynamic test list (`test_list.md`). Create it before coding. Update it at the
   start and the end of every loop. Without it, unwritten required behaviour hides.
2. Strict red-green. A new test must FAIL first, for the expected reason, before
   any implementation.
3. Explicit refactoring with a named code-smell audit, run every cycle.
4. Deterministic sensors ("habit hooks"). These inject fix-guidance into the
   agent context. Prompt text alone is not enough.

## 1. Verdict

| Element | Harness | Repo | Status |
|---|---|---|---|
| 1 Test list | Absent | Absent as a TEST list | **Gap** |
| 2 Red-green | Iron law in 2 skills | 2 of 834 commits carry red evidence | **Partly applied** |
| 3 Refactor and smell audit | Present at review stage only | Nothing in the commit path | **Gap** |
| 4 Deterministic sensors | 2 sensors block a commit | Sensors miss code and tests | **Partial** |

The `docs/plans/ACTIVE.md` file is a maintained WORK list, not a test list.

The short answer: the sensors and the doctrine exist. The two elements that make
TDD load-bearing in an agent loop, the test list and an observed RED, do not.

## 2. Element 1, the dynamic test list: absent at both layers

```bash
find . -iname "*test_list*" -not -path "./.git/*" | grep -v .julia_depot   # nothing
grep -rIln -iE "test_list" ~/.hermes/skills --include="*.md" | grep -v .hub  # nothing
```

No `test_list.md` exists in the repo. No skill asks for one. Of the 102 active
skills, only `subagent-driven-development` and `writing-great-skills` mention
red-green, and neither defines a test list.

**The nearest artifact, and why it does not close the gap.**

The `docs/plans/` tree holds 69 plan files. Only 5 use checkbox syntax. Only 1
has a ticked box. The total box count is 73, and 6 are ticked. So the plan files
are static documents.

`docs/plans/ACTIVE.md` is the exception, and it works. It is 501 lines, and it
calls itself the single source of truth for what we do next. It holds standing
rules, one item per session, and a per-item status line. It was last updated
2026-09-21. The commit trail cites it, for example `cfe67a9`, `a7e50d9` and
`a257bf7`.

The repo therefore has the habit the frame asks for, pointed at WORK items
instead of TEST cases.

**The frame's failure mode is already visible here.** The audit in
`docs/reports/2026-09-08-test-appropriateness-audit.md` found 8 of 48 test files
to be LEGACY-ONLY. Those files assert code that the v13 chain never calls. They
were green, and they blessed dead builders. That is the frame's warning in repo
form: a passing suite proves only that the existing tests pass.

## 3. Element 2, strict red-green: doctrine, not yet practice

**The doctrine is explicit.**

- The `tdd` skill: "Red before green. Write the failing test first."
- The built-in `test-driven-development` skill: "If you didn't watch the test
  fail, you don't know if it tests the right thing."
- `CLAUDE.md` line 104: "Never commit with red."
- `AGENTS.md`: "Never commit with a red suite."

**The commit trail does not show the loop.**

```bash
git log --no-merges --pretty=format:@@%h --name-status   # 834 commits parsed
```

| Measure | Count |
|---|---|
| Commits touching `src/` and `test/` together | 87 |
| Commits touching `test/` only | 33 |
| Commits touching `src/` only | 207 |
| Commits that add a test file with a `src/` change | 28 |
| Commits that add a test file alone | 12 |
| Commits with a recorded RED observation | 2 |

The two red-phase records are real and good.

- `73a2cf8` (2026-04-24) is titled "test: add TDD tests for v4 ring_spacing, all
  failing as expected (red phase)". Its body says "All 10 testsets fail with
  UndefVarError, no implementation yet."
- `73528ac` (2026-08-22) is titled "test: RED acceptance for the non-finite-FoS
  guard". It states the defect, keeps the file unwired while the campaign runs,
  and wires it with the fix.

**The counter-signal is the re-baseline habit.** Several commits change a test to
match new code.

- `4a69a3f` "test: re-baseline settle_lowk_honest A2 with measured attribution"
- `7014445` "test: align P1's tether with the campaign"
- `9915ad4` "fix: canonical 10-D indices in test_settle_lowk_honest"
- `c38bbf5` "fix: restore break detection at the gate; re-baseline A5 on a frozen fixture"

The repo audit of 2026-09-08 names this class: tests re-baselined to new builder
behaviour, or moved goalposts. A re-baseline is legitimate when a fixture changes
on purpose. It is a green-then-test inversion when it hides a defect.

**Nothing observes the failure.** No gate, hook or CI step asks for evidence that
a new test failed before the fix. The one RED-by-design file was left unwired, so
its red state lives in prose and not in runner output.

## 4. Element 3, refactor and smell audit: review stage only

The `code-review` skill (mattpocock plugin, surfaced in Hermes) carries a 13-item
Fowler smell baseline. It lists mysterious name, duplicated code, feature envy,
data clumps, primitive obsession, repeated switches, shotgun surgery, divergent
change, speculative generality, message chains, middle man and refused bequest.
It runs on a diff from a fixed point. Two rules bind it: the repo overrides the
baseline, and every smell is a judgement call. This is the best smell asset in
the harness.

The `tdd` skill puts refactoring OUT of the loop: "Refactoring is not part of the
loop. It belongs to the review stage." The reviewed frame says the opposite.
There, REFACTOR is step 3 of the cycle, and the harness must never skip it. The
two positions conflict, and `AGENTS.md` is silent on the conflict.

**No deterministic code-quality gate runs on a commit.** `AGENTS.md` asks for
`scripts/ktd-format` (JuliaFormatter, Blue). JuliaFormatter is in neither
`Project.toml` nor a global env, so the skill says to run it from a throwaway env.
The test files are also not formatter-clean at HEAD. A blocking formatter sensor
is therefore not available today without one repo-wide pass first.

## 5. Element 4, deterministic sensors: built, and aimed away from code

The file `.githooks/pre-commit` runs on every commit, and `core.hooksPath` points
at `.githooks`. It blocks the commit on two sensors.

```bash
python3 ste-lint.py --fail-above 2.0 $MD_FILES     # staged markdown, STE-100
python3 check-provenance.py $CSV_FILES             # staged campaign CSVs
```

The design and the rationale live in
`~/.hermes/skills/.archive/hermes-bot-team/references/habit-hook-sensors.md`. The
marker format is `[HOOK:<name>] <file> <trigger> -> <fix one-liner> (skill)`. The
provenance sensor caught real debt on the first run.

Three playbooks stay manual by design: `habit-hook-physics-convention`,
`habit-hook-hardcoded-numbers`, and the STE rules. The sensors doc gives the
reason. `PHYSICS_ERA` is a per-runner constant, and the question "is this literal
supposed to come from data?" is semantic.

**What is missing.**

- No sensor and no hook touches code or tests. `runtests.jl` never runs at commit
  time.
- `.githooks/pre-push` warns and does not block when acceptance paths change.
- CI is the only real gate. `ci.yml` runs the fast suite on every push and PR.
  `acceptance.yml` runs the slow suite on six path globs only.
- Nothing runs in the agent loop. `~/.hermes/config.yaml` holds `hooks: {}`, and
  `~/.hermes/hooks/` is empty. Hermes does support shell hooks on `pre_tool_call`,
  `post_tool_call`, `pre_llm_call` and `subagent_stop`.

The asymmetry is worth naming. The sensor layer guards prose and CSV provenance.
For 3.5 minutes, the fast suite could guard the code, and no gate asks it to.

## 6. Suite facts used above

| Fact | Value | Command |
|---|---|---|
| Test files in `test/` | 57 | `ls test/*.jl \| wc -l` |
| Wired into the fast suite | 46 | `grep -c include test/runtests.jl` |
| Acceptance files, separate processes | 8 | `ACCEPTANCE_FILES` list |
| Retired to `test/archive/` | 4 | `ls test/archive/*.jl` |
| Helper file, not a testset | 1 | `settle_case_builders.jl` |

The suite split rule is DECISIONS.md [2026-08-20], enforced by the CI path
filters.

**Doc drift found while counting.** `CLAUDE.md` line 104 says "50 fast + 8
acceptance files". The fast suite includes 46, and `test/` holds 57 `.jl` files
with acceptance, helper and archive included. `CLAUDE.md` quotes ~2.6 min for the
fast suite. `test/runtests.jl` quotes ~3.5 min. These counts are what a session
reads before it decides to run the suite.

## 7. What this audit does NOT cover

- **Session transcripts.** A commit message is a weak proxy for red-first
  practice. A session that watched a test fail but wrote no red note records as
  "not red". The figure of 2 commits is a FLOOR, not a rate. A count over Hermes
  session history in `~/.hermes/state.db`, and over the DSH transcripts in
  `~/.dsh/sessions/`, would give the real rate.
- **Per-file test quality.** This audit did not sweep for tautological tests or
  for tests coupled to implementation detail. The 2026-09-08 audit covered the
  dead-builder class and the missing-guard class. No repo-wide tautology sweep
  exists.
- **TDD on the `scripts/` and `scratch/` layers.** Probe scripts carry the
  measurement burden in this repo. They have no test convention at all.

## 8. Recommendations (defaults for Rod to overrule)

Ordered by leverage per unit of work.

1. **Add a test list to the working agreement, scoped per session.** This is the
   cheapest high-leverage change. Use either a `test_list.md` beside the work, or
   a `## Tests` section in `docs/plans/ACTIVE.md` for the current item. The rule:
   write the list before the first test, then update it at the end of every cycle
   with the edge cases and the unstated requirements that the cycle found. The
   precedent is `ACTIVE.md`, which already works this way for work items.
2. **Make RED observable, not asserted.** Ask for the failing test name and the
   failure reason in the plan row or the commit body. A small wrapper script that
   runs one test file and prints the first failure line turns this into a
   copy-paste step instead of a discipline claim.
3. **Wire the fast suite to a gate that fires during the loop.** A blocking
   pre-commit of 3.5 minutes is too slow. Two workable shapes: a Hermes
   `post_tool_call` hook on `patch` and `write_file` for `src/**`, which runs the
   touched test file only; or a `.githooks/pre-push` upgrade from warn to block
   for the acceptance paths.
4. **Name the re-baseline pattern and give it a rule.** A test re-baselined to
   match new behaviour is a decision. It needs a DECISIONS entry and a stated
   reason. An unexplained re-baseline is the moved-goalposts defect that the
   2026-09-08 audit named.
5. **Resolve the refactor contradiction.** Run the `code-review` Standards axis
   on the new hunks as the REFACTOR step, or keep refactoring at review stage and
   record that in `AGENTS.md`. Today the `tdd` skill and the reviewed frame
   disagree, and `AGENTS.md` is silent.
6. **Fix the counts in `CLAUDE.md`** while this area is open: 46 fast files, ~3.5
   min, 8 acceptance files, 4 archived.

## 9. What landed, 2026-09-24

Rod approved items 1, 2, 3 and 5 in this session. The rest stay open.

| Item | Landing |
|---|---|
| Test list | `docs/plans/test_list.md`, with its rule in `docs/agents/test-first-loop.md` |
| Observe RED | `scripts/ktd-test-one` (one file in ~15 s, standalone or fragment) plus the evidence rule |
| Refactor ruling | Rod ruled that the loop carries the refactor step after GREEN. This repo now overrides the `tdd` skill, which keeps refactoring at review stage |
| Cue, commit time | `check-tdd-evidence.py` and `.githooks/pre-commit` v0.2.0. Warns, never blocks |
| Cue, edit time | `~/.hermes/agent-hooks/tdd-cue.py`, a `pre_llm_call` shell hook. The config block below is the only manual step, because the agent cannot write `config.yaml` |
| Counts | `CLAUDE.md` and `AGENTS.md` now read 46 fast files, ~3.5 min |

The manual step for Rod, in `~/.hermes/config.yaml`:

```yaml
hooks:
  pre_llm_call:
  - command: ~/.hermes/agent-hooks/tdd-cue.py
    timeout: 10
```

The first use prompts for consent, and `hooks_auto_accept` stays false.

**Landed the same day.** The block is in `~/.hermes/config.yaml` (line 491), the
pair is allowlisted (approved 12:35:37Z), and `hermes hooks doctor` reports all
healthy. `hermes hooks test pre_llm_call` returns the cue as Hermes wire shape:

```
{"context": "[HOOK:tdd] src/bem.jl: changed with no test change at least as recent. …"}
```

The hook registers per session, so the desktop session open at the time of the
change ran without it. The next session picks it up.

