# Room response: the item-2.1 environment reads (2026-10-15, aero-validator)

**Status** LANDED. **Seat** aero-validator. **Base** `94f338c` (branch `bank-derate-cos2p65`).

The v0.54 scope note (author seat) leaves three items outside the signed set. They are the shear law and its exponent, the shaft-elevation angle, and the steady-wind note for the window swing. This receipt covers the three items at the aero desk. Each item below carries its value, its source and its print use. All three are reads. No run, no new number, no code change.

## 1. The shear law and its exponent

- **Value.** Hellmann power law, exponent 1/7, quote 0.1429.
- **The law.** `V(h) = V_ref * (h / h_ref)^alpha` at `wind_at_altitude` (`src/wind_profile.jl:130-137`).
- **One authority.** `SITE_ANCHOR = SITE_DAISY = WindSiteSpec("Tulloch, Daisy (measured)", 10.0, 4.8, 1/7)` (`src/wind_profile.jl:50,54`). The single runtime reader `site_shear` carries the exponent (`:110-112`).
- **The measured pair.** 10.0 m/s at 4.8 m, the Daisy anemometer mast, near the rotor centre.

- **The table pair.** The site profile at 9.4117 m reads 11.0097 m/s. The table quotes 11.01 m/s at 9.41 m. At the 9.400 m design hub the profile reads 11.0077 m/s.
- **Guard and record.** Guard `test/test_wind_authority.jl`. Landing record `docs/validation/2026-10-03-d1-wind-landing-verification.md`.

- **Print use.** One §3.3 environment row. One clause ties the 11.01 m/s pair to the measured 10.0 m/s at 4.8 m.

## 2. The shaft-elevation angle

- **Value.** 30.0 degrees, π/6, the model convention.
- **Source.** `src/parameters.jl:369` reads "elevation_angle = 30° (model convention)". The 10 kW factory reads the same value at `:294`. Angles do not scale (`:606`). The campaign runner pins `ELEV = π/6` (`scripts/run_v13_5kw_masslift.jl:73`).

- **Design hub altitude.** tether_length * sin(30°) = 18.8 * 0.5 = 9.4000 m. The rung `p.h_ref` reads 9.4117 m.

- **The gap.** The 0.0117 m gap comes from `mass_scale` and stays immaterial to the sizing (`docs/plans/2026-09-24-phase5-multirotor-sizing.md:36-42`).
- **Flown read.** The settled hub carries mean z 8.914 m at elevation 28.64 degrees. The site profile reads 10.924 m/s there (`docs/reporting/numbers-register.md:618-622`, receipt `scratch/av_probe_tipref_live.jl`).
- **Print use.** One §3.3 environment row. The settled read stands ready for the flown-basis note.

## 3. The steady-wind note for the window swing

- **The basis.** The evaluator wind closure reads altitude only: `wf(pos, t) = [wind_at_altitude(p.v_wind_ref, p.h_ref, z), 0.0, 0.0]` (`src/objective_evaluator.jl:792-795`). No time term appears, so the trace runs steady wind.
- **The constructor.** `steady_wind(v_ref) = (t) -> v_ref` (`src/wind_profile.jl:160-164`). Ramp, gust and turbulence constructors exist as separate scenario tools. The reported run engages none of them.

- **The swing.** NR-014 reads a range of 0.029 kW on 5.309 kW, quote 0.5 per cent. The register carries 0.54 per cent on the same quotient (`:826`).
- **The ask.** State that the swing comes from steady wind. It is not a stability property of the machine (`docs/reporting/feedback/2026-10-10-harris-review.md:184`). The turbulence line reads the same way (`:176`).

- **Print use.** One §3.3 sentence plus one row.

## 4. Verification

- Probe `scratch/av_item21_environment_probe.jl`, log `scratch/av_item21_environment_probe.log`.
- The probe reads the shipped library. `site_wind(9.400)` = 11.007738, `site_wind(9.4117)` = 11.009694, `site_wind(8.914)` = 10.924573. The exponent reads 0.14285714285714285. All checks pass.
- The pinned tests agree: `test/test_bem_unified.jl:202`, `test/test_betz_ceiling_projection.jl:205`, `test/test_wind_authority.jl:49-54`.

## 5. Handoffs

- @science-validator: the three rows sit for sign. They carry no new number.
- @author: the folds key on the rows. The §3.3 table takes two environment rows, and the swing sentence takes its basis note.
- @hermes: the queue can record the three items read and routed.

- No draft byte moves. No plate byte moves. No code byte moves.

Recorded by @aero-validator (aero seat).
