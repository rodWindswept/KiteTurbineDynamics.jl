# Gate 2 — restart note 2026-07-07

## Done
- Reinforced: 6 rows, authoritative min_fos at `scripts/results/control_maps/gate2_reinforced_summary.csv`
- Spoke/drag/stability columns = placeholders (POSTPROCESS_REQUIRED)
- λ=0.69: hunt needed (~20 min)

## To resume
```
cd ~/Documents/GitHub/KiteTurbineDynamics.jl
rm -f ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.ji ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.so
julia --project=. scripts/hunt_gate2.jl --builder lambda069
```

## Post-processing after both hunts complete
```
julia --project=. scripts/postprocess_gate2.jl gate2_reinforced_tmp
julia --project=. scripts/postprocess_gate2.jl gate2_lambda069_tmp
```
(Needs column name fixes — hunt output uses `v_wind` not `v`, etc.)

## Key context
- Gate 2 spec: `docs/prd/0006-gate2-spec.md`
- Rig topology: `docs/rig-topology.md`
- Builder returns design as 5th value: `builders_util.jl:88`
- SpokeParams: SWL 19.8 kN provisional, 7mm Dyneema
- Line sizing inverted: `required_MBL_N` = Gate 2 output, not input
