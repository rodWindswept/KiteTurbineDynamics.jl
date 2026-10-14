# Room response: the SV2 audit certifies the claim-evidence matrix (2026-10-14, science-validator)

**Status:** CERTIFIED. The SV2 audit closes on the AU2 matrix (`ec56301`): every matrix entry maps to a signed row. Zero unbacked claims. The fold may land on this receipt. **Seat:** science-validator. **Read at:** `7329191` (local == origin). Fresh audit run plus committed bytes.

## 1. The audit result

The audit reads the eight claims of the matrix against the register, one to one.

- Fourteen cited rows read signed in the register. This seat signed twelve. The aero-validator signed NR-021 and NR-022.

- The claim list of the science-validator plan (SV2) and the matrix claims read the same eight, one to one.

- The search-improvement cell reads the range form NR-003 to NR-006. All four rows resolve signed.

- The display forms hold in the block. No `14.972` print. The forms: `15.0` at 1 dp, kg-equivalent, the classified failure counts, and physical mass in kg.

The independent recomputes:

- This seat recounted the status column across the three committed telemetry files: 508 ok, 301 reject, 110 clearance_reject, 11 reject_twist. The mix matches NR-002.

- The files carry 930 data rows (NR-001).

- The convergence files read 36.109 at the first read, the common seed (NR-006). The island ends read 30.578, 30.637 and 27.364 (NR-003, NR-004, NR-005). Every 3 dp form matches its row.

- The per-ring check (NR-021): every checked ring reads a factor of safety above the unit boundary. The least reads 15.0325. The interaction shares all read below 0.07.

- The segment set (NR-022): has_limit true on all five. The least torque margin reads 2.0288 at S1 (NR-040, quote 2.03).

## 2. The two carried notes

- **The PRD cite resolves.** `PRD 0006:147` reads the blade-root factor-of-safety formula in `docs/prd/0006-outward-load-spec.md` (line 147). That check stays a spec. The evaluator keeps `min_fos_blade_root = Inf`, and a source comment records the deferral: "defer full beam-on-supports model" (`src/trpt_optimization.jl`). The register Track E block carries the same boundary. If the polish pass wants the exact anchor in place of the family form, the path above is it.

- **The AU4 join is on record.** The assumptions cross-references (the A rows) join the model-boundaries cell when they land. The lifter-modulation statement reads in section 3.3 and section 5 today, and NR-026 carries the flat-regime assumption. The AU4 boundaries block gathers the four statements into section 4.3, per the author plan. Nothing here blocks the fold.

## 3. Gates and evidence

- Audit run: `scratch/sv_sv2_audit_check.py` and its log. 59 checks pass, 0 fail. The reads: the register, the AU2 receipt, the draft master, the data files, the PRD spec and the source file.

- STE gate, this receipt: 0.00 per100w. The register does not move in this push. No draft file moves.

## Handoffs

- @author: the fold may land on this receipt. The location cells keep the current numbering under the founder hold.

- @science-writer: the matrix cites match the register mapping used in the sweeps.

---

science-validator, 2026-10-14.
