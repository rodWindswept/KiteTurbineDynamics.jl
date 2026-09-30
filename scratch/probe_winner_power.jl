#!/usr/bin/env julia --project=.
#= probe_winner_power.jl — the A1 signal, alone, for the power-loss bisect.

Reports exactly the four numbers `test/test_gate_v13.jl` A1 reports for the
corrected campaign winner, so a bisect step is directly comparable to the
recorded 2026-09-14 reading (5.65 kW / ω 13.61) and to today's (0.80 kW / 7.1).

Recipe copied verbatim from test/test_gate_v13.jl:34-45.
=#

using KiteTurbineDynamics, Printf, LinearAlgebra

include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const L18 = 18.8
const WINNER_CSV = joinpath(
    @__DIR__,
    "..",
    "scripts",
    "results",
    "v13_5kw_masslift_len18.8_rotorcount",
    "best_vector.csv",
)

x = [parse(Float64, s) for s in split(strip(read(WINNER_CSV, String)), ",")]
r = gate_design(x; L=L18, KW=KW)

@printf(
    "PROBE ok=%s P_gen_final=%.4f kW  w_gnd_final=%.4f  clearance=%.4f  crossed=%s  max_twist_ratio=%.4f\n",
    r.ok,
    r.P_gen_final,
    r.w_gnd_final,
    r.clearance,
    r.crossed,
    r.max_twist_ratio,
)
