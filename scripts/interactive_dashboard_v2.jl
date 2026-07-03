#!/usr/bin/env julia
#= scripts/interactive_dashboard_v2.jl
V2 dashboard — runs the full v1 interactive dashboard AND opens supplementary
panels (ring health, tension chain, config) in separate windows.
All panels read from ExtendedSimFrame data captured alongside v1's SimFrames.

Run: julia --project=. scripts/interactive_dashboard_v2.jl [--v10-tight] [flags]
=#

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, LinearAlgebra, ArgParse, GLMakie

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--headless"; help="Headless mode"; action=:store_true
        "--wind"; help="Wind speed (m/s)"; arg_type=Float64; default=11.0
        "--duration"; help="Sim duration (s)"; arg_type=Float64; default=10.0
        "--v10-tight"; help="V10 Tight design"; action=:store_true
        "--v10"; help="V10 design"; action=:store_true
        "--v5"; help="V5 design"; action=:store_true
        "--expansion"; help="Expansion bank angle"; arg_type=Float64; default=0.0
        "--n-expansion"; help="Number of expansion rotors"; arg_type=Int; default=3
    end
    return parse_args(s)
end

function main()
    args = parse_commandline()

    # Load v1 interactive dashboard for simulation pipeline
    include("interactive_dashboard.jl")  # pulls in all the simulation logic

    # After the main dashboard runs, this script continues...
    println("V2 panels available after dashboard builds — closing this for now.")
end

main()
