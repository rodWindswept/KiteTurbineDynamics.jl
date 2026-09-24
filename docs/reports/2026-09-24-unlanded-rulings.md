# Unlanded rulings harvested from agent-harness state. September 2026

**Date:** 2026-09-24
**Ticket:** `docs/wayfinder-tickets/dc3-harvest-harness-records.md`
**Map:** `docs/wayfinder-decisions-conformance.md`
**Reconnaissance input:** `~/.hermes/cache/scratch/antigravity-record-inventory.md` (2026-09-24)
**STE status:** 4.33 violations per 100 words. This report needs a prose pass before a reader treats it as final. The numbers are sound and the research is complete.
**Reproduced:** a second run of the same probe on 2026-09-24 returned 1049.3 N reported, 1078.5 N elastic-only, ratio 0.97 times, at `dt = 1.774289904693832e-5`, with `any_broken = false`. The central measurement comes from two runs, not one.

A **ruling** here is a decision about physics, geometry, load path, thresholds, or a
standing rule the project must follow, not tooling preference, not harness chatter,
not a bug report. A ruling is **unlanded** when no copy of it exists in any of the five
canonical decision records:

| record |
|---|
| `DECISIONS.md` |
| `docs/agents/physics-topology.md` |
| `docs/adr/*` |
| `docs/agents/instrument-trust-log.md` |
| `docs/validation/physics-validation-ledger.md` |

Landed-but-elsewhere (handovers, `docs/plans/ACTIVE.md`, `docs/lift/README.md`, a source
comment) counts as **unlanded** for this inventory, and the target record is named per row.
Rows are ranked by **what the ruling protects**, load path, FoS, geometry and mass
outrank calibration state and tooling.

---

## Corpus

| source | path | span |
|---|---|---|
| Antigravity (AGY) brain transcripts | `~/.gemini/antigravity-cli/brain/<uuid>/.system_generated/logs/transcript.jsonl` | Sep 18 – Sep 23 |
| dsh sessions (zstd JSONL) | `~/.dsh/sessions/--home-rodbot-Documents-GitHub-KiteTurbineDynamics.jl--/session-<uuid>/` | Aug 20 – Sep 23 |

Four September AGY conversations were mined: `2a066d84` (Sep 18), `e955670b` (Sep 20),
`9524db08` (Sep 21–22), `1bbde57a` (Sep 22–23). The other three brain directories
(`8535d7ce` 2026-07-09, `0aed7ee5` 2026-07-05, `c4d80c72` 2026-06-16) fall outside the
September window. All 19 dsh session files decompressed and searched. Dsh session dates are
taken from each file's own `time` fields (epoch ms), listed per row.

Ruling text in AGY transcripts survives only on the `content`-bearing
`PLANNER_RESPONSE` steps (38 of 408 in `2a066d84`, 66 of 562 in `1bbde57a`). The
tool-calling steps carry `thinking` and `tool_calls` but no answer prose.

---

## Ranked inventory , 8 unlanded rulings

### 1. Rope-break detection is a PER-LINE criterion, and the bridle cone and cyan line must be monitored for break

**Ruling.** Rope-break detection must be per-line, not per-bay: an overloaded line breaks
*alone* (its own sub-segments only), and the bridle cone and cyan line must also set
`sys.any_broken[]` when they pass `ROPE_BREAK_STRAIN`, because they are the lift load path
and a severed lift chain that cannot disqualify an evaluation is a modelling hole.

**Source.** `2a066d84` transcript, steps **204** (`2026-09-18T14:20:00Z`) and **212**
(`2026-09-18T14:41:05Z`) , "Ruling on Question 1: Single Line Snap vs. Whole Bay Snap" and
"Ruling on Question 2: Break Criterion for Bridles and Cyan Line". Relayed as a remit in
dsh session `b81d20de` (2026-09-16 → 2026-09-19), where the remit is pasted into the user prompt stream.
**Date.** 2026-09-18 (defect relayed 2026-09-16. Code comment attributes the ruling to Rod,
2026-09-16).

**Does the code already behave that way?** **Yes.**
`src/rope_forces.jl:326-343`, separate per-(bay, line) accumulators `line_pathlen` /
`line_restlen`, plus `bridle_pathlen`, `cyan_pathlen`. Comment "Rope break is a LINE
criterion, not a bay criterion (2026-09-16, Rod)" and "Bridles and the cyan line are not
TRPT chains … a severed lift chain could not disqualify an evaluation". Landed in `ea78651`.
The `breaks_enabled` caller gating that the same remit repeats is already recorded
(`DECISIONS.md:2376` [2026-08-14] item 4, and `docs/plans/ACTIVE.md:378-382`).

**Record it should join.** `DECISIONS.md` (new entry) + `docs/agents/physics-topology.md`
(break criterion) + `docs/validation/physics-validation-ledger.md`.
**Current home.** `handovers/handover-2026-09-16-per-line-break-detection-dt-and-reseed.md`
§2.4 and `handovers/README.md` only. All four `[2026-09-16]` entries in `DECISIONS.md`
(`:423`, `:480`, `:552`, `:585`) are silent on it.

**Protects.** Load path and FoS, this decides whether a machine with a severed lift chain
or one overloaded line is disqualified at all. Before the fix the tested strain was the
bay *average* (an overloaded line diluted by its `n_lines − 1` neighbours) and a severed
bridle cone or cyan line could not disqualify anything.

---

### 2. The 5 kW back line is 3 mm Dyneema and `EA_back_line` is pinned AFTER `mass_scale`

**Ruling.** The 5 kW back line is 3 mm Dyneema, `EA = 100 GPa × π(0.003)²/4 ≈ 707 kN`, and
that value must be pinned **after** `mass_scale`, because `mass_scale` multiplies the field
by `geom_scale = 1.826` and would otherwise carry the 1.5 kW 2 mm figure up to 1.29 MN ,
about 1.8× the spec. Back-line tension is linear in `EA` and the bungee stiffness inherits
the error.

**Source.** `test/settle_case_builders.jl:20-27` (code comment, cites "Rod, 2026-09-16").
dsh session `b81d20de` (2026-09-16 → 2026-09-19).
**Date.** 2026-09-16.

**Does the code already behave that way?** **Yes** ,
`override_params(mass_scale(...). Tether_length=18.8, EA_back_line=707_000.0)`, and the same
pin appears in the campaign runner path.

**Record it should join.** `DECISIONS.md` + `docs/agents/instrument-trust-log.md` (the
scale-error class: a constant that silently inherits `geom_scale`).
**Current home.** The source comment and `handovers/handover-2026-09-16-...md` §2.1.
`EA_back_line` appears in **none** of the five records. `707` appears in none of them.

**Protects.** Load path, the back line carries the taut load split and sets the soft-stop:
a 1.8× stiff back line is a different machine.

---

### 3. `get_max_rope_tension` reports elastic + the rope damper's viscous term, over TRPT chain sub-segments only

**Ruling/finding (the ticket's known open item, examined).** The reported maximum is
`max_i(EA·ε_i + c_damp·v_rel_i)`, a **signed** spring-plus-damper quantity, not a load ,
and it is evaluated over `1:4·n_lines·(n_ring−1)` sub-segments only, so bridle, cyan and
lift sub-segments are excluded and the number does not bound the bridle cone. No consumer
should read it as an elastic load, and no FoS path may take it as the load.

**Source.** Transcript: `2a066d84` step **204** (`2026-09-18T14:20:00Z`), which traces and
*refutes* the 850 N vs 330 N attribution. The original dsh claim was relayed in session
`b81d20de`. Code: `src/rope_forces.jl:128` (the damper term) and `:175-193` (the
`1:n_tether_segs` loop). Acknowledged at `test/test_rope_break.jl:127-130`,
`REPRODUCIBILITY.md:118-120`, and `DECISIONS.md:2391` (as a parenthetical).
**Date.** Code behaviour from 2026-08-14. The transcript's claim examined 2026-09-18.

**Does the code already behave that way?** **Yes**, both properties are by construction.

**Verdict on the "2.6×" claim: REFUTED as stated.** What the transcript actually says
(`2a066d84` step 204) is that dsh compared the **all-sub-segment instantaneous peak**
(850 N) against **one bay's average strain** (0.020144 in bay 9) and attributed the entire
gap to damping without checking which line or bay carried the peak. AGY's own diagnostic
adds: the peak is "frequently at the ground PTO ring or hub, or on the windward bowed
line". Measured on the 5 kW / 18.8 m campaign seed (this session, read-only probe, stable
`dt = 1.774289904693832e-5`):

| measurement | reported max | elastic-only, same frame | ratio |
|---|---|---|---|
| campaign seed, 20 s window, 1000 frames | **1049.3 N** | **1078.5 N** | **0.97×** |
| same machine, legacy canonical `dt = 4e-5` (1.96× over the stability limit) | 6 846 253.7 N | 6 817 651.8 N | 1.00× |

The reported maximum **tracks** the elastic maximum to within 3 % in the healthy case and
to within 0.05 % in the diverging case, the damper term does not systematically overstate
the reported maximum. The genuine hazard in the same code path is different and larger:
at an over-limit step the reported maximum inflates from 1049 N to 6.8e6 N (≈6500×), an
inflation **shared with the elastic term**, i.e. a solver-stability fault (`4e-5` is not
stable for this fine-meshed build), not a damper fault. `c_damp` on the seed spans
10.3–500.0 N·s/m. The A5 fixture the 850 N/330 N figures came from (thin line, `E = 0.7 GPa`)
can **no longer be built at all**, the settle now refuses it past the torsional
realisability cliff (measured this session: "TRPT segment 1 of 12 … needs sin(Δα) = 8.0559 > 1").

**Evidence grade.** Operating-point ratio **MEASURED** (0.97×). Break-on-stretch ratio
**NOT MEASURED**, no fixture in the current tree reaches a genuine break-on-stretch, so a
configuration exists in principle where the signed damper term pushes the reported peak
above the elastic peak. It is unmeasured, not refuted. The "2.6×" magnitude is
**UNVERIFIED and unsupported**.

**Record it should join.** `docs/agents/instrument-trust-log.md` (instrument row: what the
number is, what it is not, its scope, its `dt` sensitivity) +
`docs/validation/physics-validation-ledger.md`.
**Current home.** A code comment, a `REPRODUCIBILITY.md` aside, and one `DECISIONS.md`
parenthetical, recorded as an aside, never ruled.

**Protects.** Instrument trust under FoS, this is the number a reader would use to judge
break margin, and it neither bounds the bridle cone (TRPT-only scope) nor survives a
`dt` change.

---

### 4. The back line's 0.80 m soft travel is the physical bungee pack: 8 × 40 cm bungees in series, each contracting 10 cm

**Ruling.** The back line's soft travel is not a modelling convenience. The real line is
≈3 mm Dyneema with **8 × 30 cm lengths of 4 mm bungee sewn in series**, sitting at 40 cm
at full tension and contracting **10 cm each** when tension drops, so 8 × 10 cm = **0.80 m**
of soft travel, and the modelled `k_soft ≈ 320/0.80 = 400 N/m` follows from the pack.

**Source.** dsh session `9d8fcdf1` (user prompts, 2026-09-15 10:32 → 2026-09-16 14:17) ,
Rod's own words in the user prompt stream, mid-session.
**Date.** 2026-09-15.

**Does the code already behave that way?** **Yes** , `k_soft = 400 N/m` over `0.80 m`.

**Record it should join.** `docs/agents/physics-topology.md` §3.2 (the back line) +
`docs/validation/physics-validation-ledger.md` (as a provenance row for a model constant).
**Current home.** `docs/lift/README.md` L3–L4 and `docs/plans/ACTIVE.md:68`. `bungee` and
`soft travel` appear in **none** of the five records.

**Two discrepancies to record with it.**
- the handover measures `k_soft ≈ 439 N/m` off-design, while the code computes `320/0.80 = 400 N/m`.
- Rod later (**dsh session `0deb0dde`, 2026-09-22 10:51 → 2026-09-23 20:59**) describes the
  elastic-enhanced back line giving "a bit of tension to the skyhook for **~2 m** when it
  drops below the point of normal maximum extension", against the modelled 0.80 m.

**Protects.** Geometry and load path, the soft travel is the compliant window the taut
load split depends on, and the only physical anchor for a model constant.

---

### 5. The 3.5 % break strain transfers to the bridle cone, but the "diameter independence" justification for it is a fallacy and is RETRACTED

**Ruling.** The same dimensionless `ROPE_BREAK_STRAIN = 0.035` applies to the bridle cone ,
but **not** because strain is diameter-independent. That claim is a fundamental fallacy: in
external force equilibrium `T_line ≈ F_ext/n_lines` is set by aerodynamics and mass, so
`ε = T/(E·π(d/2)²) ∝ 1/d²` and **thinning a load-controlled line does raise its strain**.
The prior reasoning (holding `ε = 0.020144` fixed, observing `T ∝ EA`, concluding strain is
invariant) is circular.

**Source.** `2a066d84` transcript, step **204** (`2026-09-18T14:20:00Z`), section "The
'Diameter Independence' Physics Fallacy". The retraction is restated as Step 1 of the remit.
**Date.** 2026-09-18.

**Does the code already behave that way?** **Yes for the conclusion** ,
`ROPE_BREAK_STRAIN = 0.035` (`src/rope_forces.jl:89`) is shared across TRPT, bridle and cyan.

**Record it should join.** `docs/agents/physics-topology.md` (break-criterion section) as a
caution, so the wrong justification is not re-derived.
**Current home.** `DECISIONS.md` [2026-09-20] item 5 records the transfer with the wording
"obeys the same dimensionless strain logic … no new threshold", i.e. the *conclusion* is
recorded with the *retracted* reasoning. The retraction itself is in no record.

**Protects.** FoS, it is the justification under the threshold that disqualifies a machine.

---

### 6. The 5 kW campaign is re-seeded at L/r 1.5 (one gene, the clean floor fix)

**Ruling.** Re-seed the 5 kW campaign at `L/r = 1.5`, one gene, not a knob sweep, as the
clean floor fix, accepting that it moves the pinned realisability fixture.

**Source.** `handovers/handover-2026-09-16-per-line-break-detection-dt-and-reseed.md` §2.3
("one gene, `P_end` 5.1465 kW, `FoS` 2.599, chain connected", `04a31bf`). Dsh session
`b81d20de` (2026-09-16 → 2026-09-19).
**Date.** 2026-09-16.

**Does the code already behave that way?** **Yes**, the campaign seed is the L/r 1.5 machine.

**Record it should join.** `DECISIONS.md`.
**Current home.** The handover and `handovers/README.md`. `DECISIONS.md`'s `[2026-09-16]`
entries reference "the re-seeded machine" but none records the re-seed decision. "re-seed"
as a decision appears in none of the five records.

**Protects.** Calibration state, a later reader cannot tell whether the seed is a choice or
an accident, and the re-seed is cited as superseding part of the L/r 2.0 fixture's motive
(`DECISIONS.md:184`).

---

### 7. Sustained structural slack also includes total bridle cone tension below 50 N

**Ruling.** The slack gate's "sustained structural slack" criterion is
`T < 1.0 N` for a contiguous `Δt > 0.8 s` **or** total bridle cone tension below **50 N** ,
the second arm catching a cone that unloads as a set without any single line dipping long.

**Source.** `2a066d84` transcript, step **37** (`2026-09-21T09:43:16Z`), "Update the Slack
Gate Criteria". Restated as the pass declaration for all eight matrix runs.
**Date.** 2026-09-21.

**Does the code already behave that way?** **Partly**, the 1.0 N / 0.8 s criterion and the
~10 ms sampling protocol are implemented and recorded. The total-cone arm is the part with
no recorded home.

**Record it should join.** `DECISIONS.md` (append to the `[2026-09-21]` entry) or the
`docs/plans/ACTIVE.md` gate checklist.
**Current home.** `DECISIONS.md:223-243` states the 1.0 N threshold, the 0.8 s bar, the
~10 ms protocol and the window minimum (~110 N total), but not the 50 N alternative arm.

**Protects.** Gate criterion, no load path. Ranked lowest of the physics rows.

---

### 8. There must be exactly ONE definition of the campaign-seed cases, a duplicated harness drifts and its typo masquerades as physics

**Ruling.** The campaign-seed case builders must have a single definition
(`test/settle_case_builders.jl`). A duplicated throwaway copy drifts, and a typo in it then
presents as a physics result. A test whose assertions reproduce measured numbers must pin
its own frozen genome, because re-seeding silently invalidates it.

**Source.** `test/settle_case_builders.jl:1-12` and `:30-36` (code comments, citing the cost
"the 2026-09-12/13 sessions twice"). The 2026-09-12/13 handovers.
**Date.** 2026-09-13.

**Does the code already behave that way?** **Yes**, one shared builder exists and the
frozen-genome convention is applied (`SEED_LR20` fixture).

**Record it should join.** `docs/agents/instrument-trust-log.md` (the fault class: a stale
or duplicated harness presenting as physics) , *not* `DECISIONS.md`.
**Current home.** Source comments and handovers. "duplicated harness" / "one definition"
appear in none of the five records.

**Protects.** Process only, it states a standing rule for the project, so it is included,
but it protects no load path and ranks last.

---

## Verified as ALREADY LANDED (negative results, do not re-open)

Each of these was a candidate and was found fully recorded in one of the five records:

| ruling | record |
|---|---|
| One ring plane is canonical; the bridle dual-plane exception is PERMANENTLY retired | `DECISIONS.md:91,126`; trust log row 30; `src/rope_forces.jl:5-12` |
| The spoke radial restraint stays INERT by ruling — never switch it on as a stability crutch | `DECISIONS.md:177`; trust log row 34 |
| Singleton `F_radial` is a rim load, never a centre-of-mass force; block removed | `DECISIONS.md:177`; trust log row 34 |
| `SIZING_FOS_MARGIN` stays 1.3 — do not inflate the FoS margin to buy acceptance | `DECISIONS.md:484,525`; `handovers/README.md` |
| Rope break = immediate disqualification, `ε_break = 0.035`, no wreckage physics | `DECISIONS.md:2363-2370` |
| `breaks_enabled` off during the settle's exploratory transients, on for operational windows | `DECISIONS.md:2376`; `docs/plans/ACTIVE.md:378-382` |
| `dt` must be adaptive (`stable_dt_for_system`, keyed on `Lmin`), never a hardcoded literal | `DECISIONS.md:1326,1696,1746` |
| Wobble gate: the top bridle cone's 1P cyclic slack is expected behaviour; zero-damping envelope is the governing design load; FoS judged at the cycle peak against 2.5 | `DECISIONS.md:223-243` |
| Sky anchor from closed-form circle intersection, no nonlinear root-finder at build time | `DECISIONS.md:244-268` |
| Back line is taut at the design point; the taut-chain rule is about steady state; lower the lift angle rather than raise the margin | `DECISIONS.md:651` |
| The bridle cone is fixed by the ring's resting radius, not by expansion or blade state | `DECISIONS.md:623` |
| Every damper must be justified; the wobble is gated | `DECISIONS.md:717` |
| Settle must REFUSE a design point past the torsional cliff (raise, never clamp) | trust log row 51; `docs/agents/instrument-trust-log.md:51`; code + `test/test_trpt_realisability.jl` |
| Mass growth Δm = +3.28 kg approved via the helix envelope | `DECISIONS.md:480` |
| Realisability enforced at the operating equilibrium by self-consistent closure | `DECISIONS.md:244` |
| `k_mppt` must match the campaign's honest value (2.24) in settle AND re-gate | trust log row 59 |
| Ring sizing: the closed-form load model was 3.7× low; restore the 1.2 helix envelope | `DECISIONS.md:480` |
| Island 1 is a degenerate, unviable genome (mass-min cost exploited) | `DECISIONS.md:70` |
| Lifter kite: along-line viscoelastic tether damping + crosswind aerodynamic symmetry | `DECISIONS.md:199`; `docs/agents/physics-topology.md:74` |

**Refuted claim, not a ruling.** The idea that `get_max_rope_tension` **feeds FoS** is false
and was already refuted in-harness: its only product-path caller is `src/sim_frame.jl:163`
(SimFrame `T_max` telemetry). The other callers are tests and diagnostic scripts. The
refutation lives in `handovers/handover-2026-09-16-...md` and a dsh session note, but since
the claim is false there is nothing to land.

---

## Negatives, what was searched, and what could not be reached

**Searched.**
- **Whole-harness keyword sweep.** The AGY transcripts and dsh prompt streams were swept for
  `we should`, `ruled`, `I rule`, `decided`, `do not`, `never`, `always`, `permanent`,
  `canonical`, `revert`, `rejected`, `must not`, `standing rule`, `from now on`, `in future`,
  `convention`, plus the harness-specific forms `RULING:`, `Decision:`, `Ruling on Question`.
  Hundreds of hits. Most are code narration or restatements. Only formal rulings were kept.
- **Every candidate checked against the records, not assumed.** Each of the 18 negatives
  above was grepped for in all five records before being called landed.
- **Non-text harness state.** `~/.gemini/antigravity/conversations/*.db` (protobuf) and
  `~/.gemini/antigravitycli/*.json` were **not** parsed. The `.db` files are protobuf with no
  `sqlite3` CLI on the machine and no schema. Since the text transcripts cover the same
  turns, they were skipped deliberately rather than silently. **Unread, and a real residual risk.**
- **AGY `thinking` blocks** were not mined for rulings. They are reasoning, not rulings, and
  the answer prose was recovered from `content` instead.
- **dsh `session.lock` / empty sessions.** `8bf03a74` (2026-09-09, 543 bytes) and
  `5df58486`'s dual files carried no ruling content.

**Corrections to the ticket's reconnaissance, worth carrying forward.**
- The transcripts live at `~/.gemini/antigravity-cli/brain/`, **not** `~/.gemini/antigravity/brain/`.
- The ticket's "recorded only in a code comment at `test/test_rope_break.jl:127-130`" premise
  for the rope-tension finding is **wrong**: the fact is also in `REPRODUCIBILITY.md:118-120`
  and `DECISIONS.md:2391`. It is recorded as an aside in three places and **ruled in none**.
- `~/.dsh/sessions/` holds **19** session files (18 sessions) for this repo, not 31 entries ,
  the rest of the directory listing is a `session.lock` and the per-session subdirectories.

**What could not be reached.**
- `~/.gemini/antigravity/conversations/*.db` and `~/.gemini/antigravitycli/*.json` (protobuf, unparsed).
- Any ruling AGY gave in prose on a tool-calling step whose `content` field is empty, those
  turns survive as `thinking` + `tool_calls` only.
- The 850 N / 330 N break-on-stretch configuration: not reproducible, because the thin/soft
  A5 fixture is now refused by the realisability guard at the settle. The break-on-stretch
  end of the row-3 measurement is therefore **unmeasured**.
- Nothing was modified outside `~/.hermes/cache/scratch/dc3/` and this file.
  `git status --short` shows this report as the only change to the working tree.
  Julia ran with a scratch depot stacked first
  (`JULIA_DEPOT_PATH=$SCRATCH/depot:$REPO/.julia_depot:$HOME/.julia`). Verification of that
  claim, stated with its evidence and its limit: **no** `KiteTurbineDynamics` cache in
  `.julia_depot/compiled` was touched after 14:15 today and **no** new `.julia_depot/logs`
  entry appeared, so the probes wrote nothing there, they resolved against the cache built
  at 13:21 from the same working tree. In the same window 479 dependency-cache files in
  `.julia_depot/compiled` were rewritten (14:29), but that batch includes `GLMakie`,
  `MeshCat`, `Wayland_jll` and `CoaxialAutogyroStacking`, packages these probes never load ,
  so it belongs to concurrent Julia work elsewhere, not to this session. I can rule my own
  contribution out for the local package and for logs. I cannot attribute the dependency
  batch, only show it is not mine.

---

## Provenance of the measurements in row 3

Read-only probes, scratch only, no repo file touched:

- `~/.hermes/cache/scratch/dc3/probe_max_tension.jl`, campaign seed (`build_case(nothing, nothing)`,
  5 kW @ 18.8 m), settle `n_op=30_000`, 20 s window at `dt = 1.774289904693832e-5`, 1000 frames.
  reported vs zero-damped (`c_damp ≡ 0` shadow system) tension evaluated on the same state vector.
- `~/.hermes/cache/scratch/dc3/probe_dt_artefact.jl`, same machine, `dt = 4e-5` vs the derived
  stable `dt`. `dt = 4e-5` breaks a line and diverges.
- `~/.hermes/cache/scratch/dc3/probe_break_ratio.jl`, the thin/soft A5 route. **refused by the
  settle** (torsional realisability cliff), which is why the break-on-stretch ratio is unmeasured.
