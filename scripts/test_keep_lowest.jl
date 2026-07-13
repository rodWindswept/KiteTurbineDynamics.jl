using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "builders_util.jl"))
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

sp = SpokeParams(enabled=true)

for (label, keep) in [("DROP lowest", false), ("KEEP lowest", true)]
    sys, u0, p, _ = build_v10_tight(blade_scale=1.0, tether_diameter=0.004, r_bottom_scale=1.30, keep_lowest=keep)
    N=sys.n_total; Nr=sys.n_ring; hr=(sys.nodes[sys.rotor.node_id]::RingNode).ring_idx
    n_rotors = length(sys.expansion_rotors)
    println("=== V10 Reinforced, $label ($n_rotors expansion rotors) ===")
    wf(pos,t) = (z=max(pos[3],1.0); [11.0*(z/p.h_ref)^(1/7), 0.0, 0.0])
    for k in [2.0, 4.0, 6.0, 8.0, 10.0, 14.0]
        sys.k_mppt_ref[] = k
        u = KiteTurbineDynamics.settle_to_operational_state(sys, copy(u0), p, 4.5; lift_device=nothing)
        for seg in 1:3
            KiteTurbineDynamics.run_canonical_sim!(u, sys, p, wf,
                round(Int,10.0/ControlMapHunt.DT), ControlMapHunt.DT;
                lift_device=nothing, lin_damp=0.05, spoke=sp)
        end
        w = abs(u[6N+Nr+hr]) * 60/(2π)
        ef = ControlMapHunt.capture_extended(u, sys, p, 34.5, wf, nothing; brake_engaged=false)
        af = @view u[(6N+1):(6N+Nr)]
        rea = KiteTurbineDynamics.ring_element_analysis(u, collect(af), sys, p, 34.5, wf)
        local rf = [isnan(r.max_util)||r.max_util<=0 ? Inf : 1.0/r.max_util for r in rea]
        local mf = minimum(r for (i,r) in enumerate(rf) if !isinf(r)&&i>1; init=Inf)
        local nf = count(r->r<1.5, rf)
        @printf("  k=%4.1f  ω=%3.0frpm  P=%3.0fkW  FoS=%4.2f  fail=%d\n", k, w, ef.base.P_kw, mf, nf)
    end
end
println("Done")
