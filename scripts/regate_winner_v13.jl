#!/usr/bin/env julia --project=.
# regate_winner_v13.jl — ODE-gate a campaign winner on the corrected model:
# P_gen @ ground, twist vs crossing limit, rope break, tip-speed sanity,
# clearance. Usage: julia regate_winner_v13.jl <csv> --length L
using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))
include(joinpath(@__DIR__, "ode_gate_v13.jl"))

function main()
    csv = ARGS[1]
    L = 21.2
    for (i, a) in enumerate(ARGS)
        a == "--length" && (L = parse(Float64, ARGS[i+1]))
    end
    x = [parse(Float64, s) for s in split(strip(read(csv, String)), ",")]
    r = gate_design(x; L=L, KW=5.0)
    tip_ok = tip_speed_sanity_ok(r.u, r.sys)
    broken = r.sys.any_broken[]
    println("winner: ", csv)
    println("  gate ok        = ", r.ok)
    println("  P_gen_final    = ", round(r.P_gen_final, digits=3), " kW")
    println("  w_gnd/w_hub    = ", round(r.w_gnd_final, digits=2), " / ", round(r.w_hub_final, digits=2))
    println("  twist crossed  = ", r.crossed, "  (max ratio ", round(r.max_twist_ratio, digits=2), ")")
    println("  tip-speed ok   = ", tip_ok)
    println("  line broken    = ", broken)
    println("  clearance      = ", round(r.clearance, digits=3), " m")
    println("  r_hub=", round(r.r_hub, digits=3), "  n_lines=", r.n_lines, "  rings=", r.rings,
            "  n_active=", r.n_active)
    final_ok = r.ok && tip_ok && !broken
    println(final_ok ? "VERDICT: PASS ✓" : "VERDICT: FAIL ✗")
end
main()
