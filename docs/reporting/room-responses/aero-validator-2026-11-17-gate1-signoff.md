# Room response: gate 1 sign-off and samara citation verdict (2026-11-17, aero-validator)

**Status** Aerodynamics numbers PASS (20 of 20 checks). Samara citation form FAILS the 2026-11-06 ruling and blocks release.

**Seat** aero-validator.

**Read at** `a107cb64` (committed draft v0.91 from `5d4b0067` and `e93192a6`).

## 1. Whole-draft read

This seat read the committed v0.91 draft from `git show HEAD:docs/reporting/drafts/2026-10-08-report-first-draft.md`.
The file holds 1,541 lines (`sha256` `55927d47e5926c1d`).
The staged v0.90 revert in the desktop working tree stayed untouched.

The draft cites 59 distinct register rows across 360 tokens.
All 59 cited IDs resolve to signed or amended rows in `HEAD:docs/reporting/numbers-register.md`.

## 2. Aerodynamics counter-read against the register

### Power

- Floor and ceiling: `5.0 kW` floor and `5.0 kW` over-power threshold match NR-027, NR-039 and NR-046.
- Population bounds: surviving ok designs span `5.02` to `6.32 kW` mean power (NR-007).
- Window-end bound: one ok design of 508 reads `5.00 kW` and the next reads `5.02 kW` (NR-069).

- Winner power: mean power `5.309 kW` (`5.308779 kW`), end power `5.314 kW` (`5.314114 kW`) and swing `0.029 kW` (`29 W`, `0.5` per cent) match NR-008 and NR-014.
- Gate margin: `+0.314 kW` and `+6.28` per cent above `5.0 kW` match NR-008, NR-027 and NR-039.

- Wind and shear: `11.01 m/s` at `9.41 m` matches NR-008 and NR-032.
- Hellmann exponent `1/7` from the Daisy pair `10.0 m/s` at `4.8 m` matches NR-056.
- Shaft elevation `30 deg` with design hub `9.4000 m` (NR-057) and steady-wind basis (NR-058) match.

- Power gap in section 2.3: `P_mean` `5.309 kW` against `k` times mean speed cubed `5.366 kW` (`5.365889 kW`) gives a `57 W` (`1.07` per cent) gap.
- That `57 W` gap exceeds the `29 W` window swing (NR-014).
- The Jensen inequality (`mean(omega^3) >= mean(omega)^3`) rules out speed trend and averaging causes.

- Areas and Betz screens: swept area `45.9733 m²` raw and `39.4912 m²` wind-normal match NR-033.
- Air density `1.225 kg/m³`, Betz ceiling `19.1304 kW` on the wind-normal area, and delivered share `27.75` per cent match NR-034.
- Section 2.4.5 names the per-rotor screen on the untilted bank-projected annulus as a loose tripwire (NR-034, E2).

- Rotor `Cp` and eras: AeroDyn v5.0.0 BEM `Cp` reads `0.2944` at ring speed ratio `5.566` (NR-031).
- It reads `0.2258` at tip-speed ratio `6.8415`, matching NR-032 and the 2026-10-15 source-cell amend.
- The bank-derate exponent `2.65` matches NR-019 and NR-020.
- The length screen (`18.8`, `21.2` and `25.0 m` pre-fold fail, folded pass at `18.8 m`) matches NR-027 and NR-028.

- Glauert ceiling: the appendix prints `Cp_glauert(a, gamma) = 4a(cos gamma - a) sqrt(1 - 2a cos gamma + a^2)` and `-3a^3 + 7a^2 c - 3a c^2 - 2a + c = 0`.
- Both match NR-086 (`0.5192` at `a = 0.3434`), which this seat signed on `bank-derate-cos2p65` at `320330fd`.
- Line 1526 withholds the `0.5192` numeral because `NR-086` is not yet on `master` (`HEAD`).

### Torque

- Winner torque and speed: delivered torque `396.76 N·m` (`P_mean` over mean speed) matches NR-030.
- Load-law torque `401.03 N·m` at window-mean speed `13.38 rad/s` matches NR-015 and NR-029.
- Settle speed `10.170 rad/s` matches NR-016.

- Segment twists and limits: S1 to S4 read `33.5` to `33.9 deg` (`33.946 deg` at S1) against `98.9 deg` (`98.859 deg` `δcrit`), and S5 reads `22.8 deg` against `92.6 deg` (NR-022).
- Realisability floor `72.25 deg` gives `2.13` times at S1 (NR-053), and crossing ratio `0.4393` gives `2.28` times with torsional FoS floor `1.5` (NR-052).

- Torque margins: least segment torque margin `2.03` at S1 (`+102.9` per cent above unity) and largest `2.69` at S5 match NR-040 and NR-023.
- The closed-form margin `M(theta_op, delta_peak)` in the appendix gives `2.0255` at S1 and `2.6883` at S5.
- Both values round to `2.03` and `2.69` (NR-040).

### CT figures

- The v0.91 draft prints zero `C_T` numerals.
- Section 4.3 line 1128 states that flown blades carry tether-to-blade bridling.
- That bridling resists thrust and expansion and adds unmodelled drag, matching Track E and NR-019 boundary 1.

- The measured fine-lambda `C_T` cap read (`0.9651` at `n = 3` to `1.4112` at `n = 9`, `1.4` fallback) sits in `aero-validator-2026-11-01-ct-cap-read.md`.
- That item belongs to the Phase 3 queue and does not print in v0.91.

### k values

- Campaign gain: `k = 2.24 N·m/(rad/s)²` at `18.8 m` line length, `10 s` relax, `40 s` window and `2.5` FoS floor matches NR-015.
- Load-sweep table: all six NR-047 rows in section 2.3 (`k = 0.5, 1.0, 1.5, 1.94, 2.24, 3.0`) match NR-047 on status, `P_mean`, `omega_final` and `FoS_min`.
- The tip-speed pairings (`omega 17.6`, tip about `85 m/s` at `k = 1.0` and `omega 15.3`, tip about `73 m/s` at `k = 2.24` against the `100.0 m/s` ceiling) match NR-047.

- Plateau band: `8.9475` to `8.9511 kW` at 4 dp (`k = 4.0` to `9.0`) and `< 0.5` per cent `P_mean`/`P_end` agreement in section 3.2 match NR-041.
- Sizing load step: section 2.3 prints `twice the nominal load` (NR-048) and omits the withdrawn numerals `1278 N/vertex`, `87.9°` and `78.8°` per the 2026-10-20 NR-048 amend.
- Failure-ledger gains: `k_mppt 10.0` against `1.94`, `5.18 kW` re-gate, and retired anchors `3.55` and `5.39` (`about 9 kW`) in section 4.2 match NR-047.
- NR-085 (`k* = 8.4387`, bracket `8.4` and `8.9`) stands counter-read in the register and is not cited in v0.91.

### Blade geometry

- Sizing base: power-sizing radius `r_rotor = 2.434 m`, base span `0.75` of `r_rotor` and base chord `0.113` of `r_rotor` match NR-050.
- The projection token `f_proj` in section 2.1 matches the 2026-10-19 NR-050 notation note.
- E1 fix: section 2.1 states that the blade crosses the ring.
- Its outer tip sits at `5.630 m` from the shaft axis (NR-032), with built span `1.499 m` (NR-043).

- Winner decode: `n_lines = 3`, `rings = 6`, `n_active = 1`, `r_hub = 4.580 m`, `r_bottom = 0.804 m`, `blade_scale_top = 0.8213` (quoted `0.82`), inactive `blade_scale_bottom = 0.20`, active main-rotor bank `7.088 deg` at ring 6, and inactive `bank_bottom = 22 deg` match NR-011 and NR-017.
- Transition cone: fixed half-angle `22 deg` and the reference apex-angle gloss in section 2.1 match NR-049.
- They also match the 2026-10-21 Boundary 3 state note, with no `11.0 deg` per-side numeral printed.
- Clearance: blade-tip clearance `5.468 m` against the `1.5 m` floor (`+3.968 m`, `+264.5` per cent, `3.65` times) matches NR-042.

## 3. Verdict on the samara citation form

Verdict: FAIL against `docs/reporting/room-responses/hermes-2026-11-06-tallak-citation-ruling.md` (`e93192a6`).

The 2026-11-06 ruling sets three requirements:

1. Cite the public samara page (`math.osp.no/parameter-fibers`) and name the private communication, with the joint short note by `@author` and `@science-writer` first.
2. Print nothing as a citation in the report fold until the joint short note draft exists.
3. Record the ruling in the `.bib` comment and note field and add a dated section to `docs/reporting/references-verification.md` at the derivations fold.

Committed draft v0.91 (`5d4b0067`, landed before `e93192a6`) violates that ruling:

- Lines 1439 to 1541 print the new appendix (`Appendix: TRPT shaft section: closed forms`).
- That appendix prints the two new samara results.
- They are the half-shortening peak-torque identity at line 1479 and the geometry-free torque margin at line 1485.
- Line 1442 attributes the appendix only to the Tulloch thesis (`Eq 4.30 to 4.34`) and `src/trpt_twist_limit.jl`.
- The draft contains zero occurrences of `Tveide`, `samara` or `math.osp.no/parameter-fibers`.

- No draft of the joint short note exists in the repository.
- `HEAD:docs/reporting/references.bib` (18 entries, lines 1 to 244) carries no comment, note field or entry for samara or Tveide.
- `HEAD:docs/reporting/references-verification.md` (sections 1 to 9, ending 2026-10-21) carries no dated section for the 2026-11-06 ruling.

## 4. What blocks release and founder call

No aerodynamics number blocks release.
Every printed power, torque, `k` and blade-geometry value in v0.91 matches its signed register row.

One item in this lane blocks the Strathclyde release.
Committed v0.91 prints the uncredited samara closed-forms appendix against the 2026-11-06 citation ruling.

**Founder call (Rod): how should the Strathclyde release handle the closed-forms appendix and the samara credit?**

- Option A (recommended for immediate send): Keep `Appendix: TRPT shaft section: closed forms` in the release.
  Add the interim credit in the appendix and section 8 References.
  Name Tallak Tveide (private communication, November 2026) and the public samara page (`math.osp.no/parameter-fibers`).
  Record the ruling in `references.bib` and `references-verification.md`, and cherry-pick `NR-086` (`320330fd`) onto `master` so the `0.5192` Glauert ceiling prints at line 1526.

- Option B: Hold the Strathclyde send until `@author` and `@science-writer` draft the two-to-four-page joint short note.
  Land the `.bib` and `references-verification.md` updates under the 2026-11-06 ruling at the same time.

- Option C: Drop `Appendix: TRPT shaft section: closed forms` from the Strathclyde send.
  Ship the v0.90 body, where only the E3 Jensen inequality in section 2.3 prints.
  Hold the appendix until the joint short note is ready.

Evidence: `scratch/av_gate1_2026-11-17.py` and `scratch/av_gate1_2026-11-17.log`.
