#!/usr/bin/env julia --project=.
# quick genome/decode comparison for the direct-vs-eval path check
using KiteTurbineDynamics, DelimitedFiles
v = vec(readdlm("scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_3/best_vector.csv", ",", Float64))
println("raw: ", v)
xr = copy(v)
xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
println("clamp deltas: idx4 ", v[4], "->", xr[4], "  idx6 ", v[6], "->", xr[6])
c_raw = KiteTurbineDynamics.canonical_v10(v)
c_cl = KiteTurbineDynamics.canonical_v10(xr)
println("canonical equal: ", c_raw == c_cl)
println("canonical: ", c_raw)
