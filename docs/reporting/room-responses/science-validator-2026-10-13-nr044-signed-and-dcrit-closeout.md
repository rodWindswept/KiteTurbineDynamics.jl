# Room response: NR-044 signed and the δcrit close-out (2026-10-13, science-validator)

**Status** NR-044 signs: the PCA projection summary. The δcrit triple check closes across record, plate and code. **Seat** science-validator. **Read at** HEAD `4ce4b91`. Committed bytes plus fresh runs.

## 1. NR-044: the PCA projection summary, signed

The levers family (rows 20 and 21) draws the v13 5 kW screen in gene space. The kit notes carry the recipe and the row want. This seat signs the row and takes the reading ask of the science-writer: the pair total joins the share forms.

- Shares: PC1 `22.434667`, PC2 `17.263044`, pair total `39.697710` per cent. Quote forms `22.4`, `17.3` and `39.7`.

- Loadings at four decimals, the abs(v) >= 0.2 set: PC1 n_lines `-0.5385`, rotor_count `-0.5222`, blade_scale_top `+0.5180`, target_Lr `+0.2517`, r_bottom `+0.2036`. PC2 bank_bottom `+0.5621`, blade_scale_bottom `-0.5605`, density_profile `-0.5018`, bank_top `-0.2444`.

- The bin rule: 18 x 18 cells over the 1 to 99 percentile rectangle.

The reproduction is independent. This seat re-ran the projection in Julia (`LinearAlgebra.svd`) from the three committed telemetry files. That is a different instrument than the numpy path in the kits.

The shares read 22.4346665772 and 17.2630436556, and the pair total reads 39.6977102328. Every listed loading matches at four decimals.

The counts agree too: 930 rows, 310 per island, statuses 508 / 301 / 110 / 11.

Display forms, signed. The plates and the prose print `22.4` and `17.3` at one decimal. The pair total prints `39.7` at the same precision. The row keeps six decimals. The loadings print at four decimals from this row.

Boundaries. The projection reads the raw draw columns x1..x10 as logged. The evaluator rounding of x4 and x6 is not applied, because the figure maps the draw space. The bin rule is a display fact. The axis names ride the kit text.

## 2. The δcrit close-out: record, plate, code

The user ask of 2026-10-13 names roster row 7, the twist-limit plate, and the 98.9 delta_crit. It resolves across three legs on one screen.

- Record (hermes seat). Tulloch printed p.198 reads "the minimum value of delta_crit is 90°." The limit is a floor. It falls toward 90° as the tether lengthens, and it rises toward 180° as the segment packs short. Evidence: `scratch/hermes_dcrit_record_check.py` and its log.

- Plate (this seat). The census over the committed SVG text maps every drawn readout to its row. The drawn pair 98.9 and 92.6 is the 0.1° form of NR-022. The digits read 98.85908296054023 and 92.64281134151318. The segment set maps as well: the drawn |Δα| forms ride NR-022, and the drawn torque and capacity forms ride NR-023. Every drawn string equals a ledger entry. Evidence: `scratch/sv_twistlimit_plate_check.py` and its log.

- Code (this seat). The authority call reproduces the row to the last bit. `trpt_twist_limit(r_a, r_b, l_t)` runs on the segment geometry in the extract. It returns 98.859082960540235 (S1 to S3), 98.859082960540164 (S4) and 92.64281134151318 (S5). Every value matches the stored digits with exact Float64 equality. No `src/` commit lands between the computing commit `f8114be` and HEAD. The boundary probes also run: l_t = 2r reads 180.000000°, and a long tether reads 90.143960°. Evidence: `scratch/sv_dcrit_code_check.jl` and its log.

Verdict: the 98.9 is the value the row carries. The 90° is the minimum of the limit, not a cap. Nothing moves. No redraw lands. No row edits. Both seat pins stand.

One flag, unchanged from the map. The mechanism strings on the plate carry no register rows yet. They are 72.25, 42.6, 22,425 and the retired-clamp 90°. That stays the validator item on the map. Nothing here moves it.

## 3. Gates and evidence

- STE: this receipt reads 0.28/100w, rc=0. The register moves 1.00 to 1.01 per100w, additions only, zero deletions.

- Evidence: `scratch/sv_pca_projection_check.jl` and its log, `scratch/sv_dcrit_code_check.jl` and its log, `scratch/sv_twistlimit_plate_check.py` and its log, `scratch/hermes_dcrit_record_check.py` and its log (the record leg, cited), `scratch/sv_lint_register_nr044.txt`.

## Handoffs

- @fig-img-diagrams: NR-044 is in. The kit notes and the map can take the signed row.

- @aero-validator: F-VALUE for the levers family sits at the sign-off commit. Your parallel δcrit read stands as offered.

- @science-writer: the pair total prints 39.7, and the axis names mirror as agreed.

- @user: the δcrit numbers stand. The 98.9 is the value the row carries. The 90° is the floor of the limit, not a cap. Nothing redraws.

---

science-validator, 2026-10-13.
