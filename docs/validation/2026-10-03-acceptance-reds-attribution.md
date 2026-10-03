# Pushed tip `f225e95` verified + the two new acceptance reds ATTRIBUTED (2026-10-03)

Author: software-validator. Independent of @hermes's report.

## 1 — The pushed tip is green

- `origin/bank-derate-cos2p65` = `origin/queue-landing-2026-10-03` = **`f225e95`** (both identical).
- **11 commits** off `f9f3182`.
- Delta since my verified `5191465`: `docs/validation/*` (2 records), `scratch/*` (2 probes),
  and the 3 island reports + 6 figures. **Nothing under `src/` or `test/`.**
- Fast unit suite at `f225e95`, clean worktree, independently re-run:
  **2507 Pass / 2507 Total, exit 0, 2m58.5s** — the pushed revision is green.

## 2 — The two new acceptance reds (`settle_lowk_honest` A3, `physics_path_ode` P1) are the D1 re-size class

**Attributed by two-arm ODE measurement, not inferred.** Same harness
(`test/test_physics_path_ode.jl`, P1), same seed genome `seed_genome(5.0)`, DEFAULT physics:

| arm | status | P_mean | FoS_min | verdict |
|---|---|---|---|---|
| pre-D1 @ `4d1b6c9` | `:ok` | **5.422 kW** | 12.865 | P1 PASS |
| post-D1 @ `f225e95` | `:reject` | **3.567 kW** | 10.548 | P1 FAIL |

(`settle_lowk_honest` A3 measures the same machine at 3.5766 kW through the evaluator path — the
two harnesses agree.)

### The cause, measured

The seed's own rotor, decoded statically at each revision (`scratch/sv_probe_seed_area.jl`):

| | pre-D1 `4d1b6c9` | post-D1 `f225e95` |
|---|---|---|
| `p.v_wind_ref` | 11.0 (fixed) | 11.0097 (site standard) |
| `r_out` | 3.580914 | 3.230488 |
| `r_in` | 1.893894 | 2.044077 |
| span | 1.687019 | 1.186411 |
| **raw annulus** | **29.0161 m²** | **19.6595 m²** |

Area ratio **0.678**; power ratio **0.658** (3.567 / 5.422) — the drop tracks the area to ~3 %.
The ~3 % residual is the moved operating point (a smaller radius at fixed `k·ω²` torque runs at a
different ω and Cp), not a second defect.

### Conclusion

A3 and P1 encode the same pre-D1 premise the betz §4 pins did — "this fixed genome sustains
> 5 kW". Under D1 the same genome builds a ~2/3-area machine, so its honest operating point is
~3.5 kW and the floor rejects it. **Not a physics fault; the pins are campaign-era.**

Implication to record: the whole 5 kW rung is ~2/3 its old area under D1, so the campaign
machines are ~3.5 kW at the honest operating point. The remedy is a re-optimised / re-seeded
5 kW winner under D1 (AGENTS.md already anticipates this) — **not** re-pinning A3/P1 to
`:reject`. The Sept-11 "attribute before re-pin" rule is now satisfied for these two.

## Not in scope here

The three "known" reds (gate A1, evaluator B6a/B6c, settle_drag D) are the pointer repoint —
separate item, not re-run here.

Logs: `~/.hermes/profiles/software-validator/cache/scratch/{fast_f225e95,pred1_physpath_4d1b6c9}.log`;
probe `scratch/sv_probe_seed_area.jl`.
