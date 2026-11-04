#!/usr/bin/env julia --project=.
#= export_ontology_telemetry.jl — export the four ontology-axiom quantities
from the reference machine's ODE gate run, as telemetry.json for the
ontology-invariant evaluator (scripts/test_ontology_invariants.py).

Reference machine: the S2-class fold seed (seed_genome(5.0), L = 18.8 m) —
the same machine test/test_gate_v13.jl gates. The gate already carries the
settle -> 2x5s relax -> 30s window protocol, twist_report, and rope-break
detection; this script runs it once and reads the final state out of the
result for the per-section tension matrix.

Fields:
  power_coefficient   P_gen_final / (0.5 rho A v^3), A = betz_wind_normal_area
                      (the repo's own Betz-ceiling basis), v = p.v_wind_ref.
                      Electrical at the ground against the wind-normal swept
                      area — conservative against the aero Cp.
  max_twist_ratio     the gate's twist ratio against the geometric crossing
                      limit (the ontology's collapse_margin, ratio form).
  tension_matrix      (n_sections x n_lines) tether tensions at the final state.
  slack_per_section   lines below the 5 N convention per section.
=#
using KiteTurbineDynamics, Printf, JSON3
include(joinpath(@__DIR__, "compute_seeds.jl"))
include(joinpath(@__DIR__, "ode_gate_v13.jl"))

const KW = 5.0
const L18 = 18.8

function main()
    x = seed_genome(KW)
    r = gate_design(x; L=L18, KW=KW)
    d = decode_winner(x; L=L18, KW=KW)
    p, dec = d.p, d.dec

    A = KiteTurbineDynamics.betz_wind_normal_area(r.sys, p)
    rho = p.rho
    v = p.v_wind_ref
    P_gen_W = r.P_gen_final * 1000.0
    cp = P_gen_W / (0.5 * rho * A * v^3)

    n_sections = r.rings - 1
    n_lines = r.n_lines
    Tmat = zeros(n_sections, n_lines)
    for s in 1:n_sections, j in 1:n_lines
        Tmat[s, j] = KiteTurbineDynamics.get_segment_tension(r.u, r.sys, p, s, j)
    end
    slack_per_section = [count(Tmat[s, :] .< 5.0) for s in 1:n_sections]

    telemetry = Dict(
        "machine" => "s2_fold_seed_5kw",
        "gate_ok" => r.ok,
        "P_gen_final_kw" => r.P_gen_final,
        "w_gnd_final" => r.w_gnd_final,
        "power_coefficient" => cp,
        "swept_area_m2" => A,
        "v_wind_mps" => v,
        "rho" => rho,
        "max_twist_ratio" => r.max_twist_ratio,
        "crossed" => r.crossed,
        "line_broken" => r.line_broken,
        "tension_matrix" => Tmat,
        "n_sections" => n_sections,
        "n_lines" => n_lines,
        "slack_per_section" => slack_per_section,
        "delta_peak_ratio" => nothing,
    )
    open(joinpath(@__DIR__, "..", "tests", "ontology", "telemetry.json"), "w") do io
        JSON3.write(io, telemetry)
    end
    println("gate_ok=", r.ok, "  P_gen=", round(r.P_gen_final; digits=2),
            " kW  Cp=", round(cp; digits=4), "  max_twist_ratio=",
            round(r.max_twist_ratio; digits=4), "  crossed=", r.crossed,
            "  slack_per_section=", slack_per_section)
    return nothing
end

main()
