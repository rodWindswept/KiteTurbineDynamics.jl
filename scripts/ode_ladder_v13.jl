#!/usr/bin/env julia --project=.
#= ode_ladder_v13.jl — ODE-gate the seed-class design across the graduated
ladder (5→50 kW) × tether lengths (12→40 m) on the CORRECTED model
(A2 cp falloff, per-rotor Betz, C1 torque saturation, rope break SK99,
tip-speed ceiling). The cheap DENY/PROVE signal for scalability: does the
seed-class design transmit ≥2.5 kW, uncollapsed, unbroken, inside the
tip-speed ceiling at each rung and length?

Verdict per cell = gate ok AND no line break AND tip-speed sanity AND
no twist crossing. Writes scripts/results/ladder_v13.csv for the record. =#

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))
include(joinpath(@__DIR__, "ode_gate_v13.jl"))

const RUNGS = [5.0, 7.0, 10.0, 15.0, 25.0, 35.0, 50.0]
const LENGTHS = [12.0, 18.0, 21.2, 25.0, 30.0, 40.0]
const OUT_CSV = joinpath(@__DIR__, "results", "ladder_v13.csv")

function ladder_cell(kw::Float64, L::Float64)
    x = seed_genome(kw)
    r = gate_design(x; L=L, KW=kw)
    tip_ok = tip_speed_sanity_ok(r.u, r.sys)
    broken = r.sys.any_broken[]
    verdict = r.ok && tip_ok && !broken
    return (kw=kw, L=L, P_gen=round(r.P_gen_final, digits=2),
            w_gnd=round(r.w_gnd_final, digits=2), w_hub=round(r.w_hub_final, digits=2),
            twist_ratio=round(r.max_twist_ratio, digits=2), crossed=r.crossed,
            tip_ok=tip_ok, broken=broken, verdict=verdict,
            r_hub=round(r.r_hub, digits=3), n_lines=r.n_lines, rings=r.rings)
end

function main()
    open(OUT_CSV, "w") do io
        write(io, "kw,L,P_gen_kW,w_gnd,w_hub,twist_ratio,crossed,tip_ok,broken,verdict,r_hub,n_lines,rings\n")
        for kw in RUNGS
            for L in LENGTHS
                c = ladder_cell(kw, L)
                mark = c.verdict ? "✓" : "✗"
                @printf("%5.0fkW %5.1fm  P_gen=%6.2f  w_gnd=%6.2f  w_hub=%6.2f  twist=%6.2f  crossed=%s  tip=%s  broken=%s  %s\n",
                    kw, L, c.P_gen, c.w_gnd, c.w_hub, c.twist_ratio,
                    c.crossed ? "Y" : "N", c.tip_ok ? "ok" : "FAIL",
                    c.broken ? "Y" : "N", mark)
                write(io, "$(kw),$(L),$(c.P_gen),$(c.w_gnd),$(c.w_hub),$(c.twist_ratio),",
                      "$(c.crossed),$(c.tip_ok),$(c.broken),$(c.verdict),$(c.r_hub),$(c.n_lines),$(c.rings)\n")
                flush(io)
            end
        end
    end
    println("wrote ", OUT_CSV)
end
main()
