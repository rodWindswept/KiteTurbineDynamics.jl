# V6.2 true-optimum recovery — 2026-07-18

`best_design_v62_true_optimum_recovered_from_3fcc795.json` is the corrected
V6.2 50 kW optimum (**n_lines=12, best_mass_kg=74.17**) recovered verbatim via:

    git show 3fcc795:scripts/results/v6_2_campaign_50kw/best_design.json

Timeline of the overwrite (2026-07-18 doc-staleness audit, "urgent finding 1"):

| Commit | Date | Contents of `best_design.json` |
|---|---|---|
| a2c6972 / bb7b071 | 2026-06-15 | n_lines=3, 58.19 kg (original campaign) |
| **3fcc795** | 2026-06-17 | **n_lines=12, 74.17 kg (corrected optimum — this artifact)** |
| 0373bf4 → HEAD | 2026-06-18 | n_lines=9, 58.09 kg (v6.3 smoke test — the overwrite) |

`best_design.json` at HEAD is left untouched (it is what post-06-18 scripts
read). Any doc citing the "−71% mass" headline should cite the recovered file
and this note.
