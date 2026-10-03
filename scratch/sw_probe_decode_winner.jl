#!/usr/bin/env julia --project=.
#= sw_probe_decode_winner.jl — verify the shared decode_winner helper rebuilds
the single-rotor machine for the bank-derate winner, and still handles a 14-D
genome.  Mirrors the campaign decode exactly (ode_gate_v13.jl::decode_winner). =#

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

function report(label, csv, L, KW)
    x = [parse(Float64, s) for s in split(strip(read(csv, String)), ",")]
    d = decode_winner(x; L=L, KW=KW)
    dec = d.dec
    println("=== ", label, "  (", length(x), "-D) ===")
    println("  n_active        = ", dec.n_active)
    println("  len(dec.rotors) = ", length(dec.rotors))
    println("  n_rings = ", dec.n_rings, "   n_lines = ", dec.design.n_lines)
    for (i, r) in enumerate(dec.rotors)
        bank = hasproperty(r, :bank_angle_deg) ? round(r.bank_angle_deg, digits=2) : "n/a"
        ring = hasproperty(r, :ring_idx) ? r.ring_idx : "n/a"
        println("    rotor ", i, ": ring_idx=", ring, "  bank_angle_deg=", bank)
    end
    println()
end

report("bank-derate winner (10-D)",
    joinpath(@__DIR__, "..", "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv"),
    18.8, 5.0)

report("v13_5kw_len18.0 (14-D)",
    joinpath(@__DIR__, "..", "scripts", "results", "v13_5kw_len18.0", "best_vector.csv"),
    18.0, 5.0)
