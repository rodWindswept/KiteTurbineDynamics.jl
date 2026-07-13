using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "builders_util.jl"))
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams
sp = SpokeParams(enabled=true)

function test_design(td, rbs, bs, ks)
    sys, u0, p, _ = build_v10_tight(blade_scale=bs, tether_diameter=td, r_bottom_scale=rbs)
    N=sys.n_total; Nr=sys.n_ring; hr=(sys.nodes[sys.rotor.node_id]::RingNode).ring_idx
    wf(pos,t) = (z=max(pos[3],1.0); [11.0*(z/p.h_ref)^(1/7),0.0,0.0])
    best_P = 0.0; best_FoS = 0.0; best_k = 0.0; best_w = 0.0
    for k in ks
        sys.k_mppt_ref[] = k
        u = KiteTurbineDynamics.settle_to_operational_state(sys, copy(u0), p, 4.5; lift_device=nothing)
        for seg in 1:2
            KiteTurbineDynamics.run_canonical_sim!(u, sys, p, wf,
                round(Int,10.0/ControlMapHunt.DT), ControlMapHunt.DT;
                lift_device=nothing, lin_damp=0.05, spoke=sp)
        end
        w = abs(u[6N+Nr+hr]) * 60/(2π)
        ef = ControlMapHunt.capture_extended(u, sys, p, 24.5, wf, nothing; brake_engaged=false)
        af = @view u[(6N+1):(6N+Nr)]
        rea = KiteTurbineDynamics.ring_element_analysis(u, collect(af), sys, p, 24.5, wf)
        local rf = [isnan(r.max_util)||r.max_util<=0 ? Inf : 1.0/r.max_util for r in rea]
        local mf = minimum(r for (i,r) in enumerate(rf) if !isinf(r)&&i>1; init=Inf)
        local nf = count(r->r<1.5, rf)
        local v = mf >= 1.5 && ef.base.P_kw > 50
        println("  $(rpad("$k",5)) ω=$(round(w;digits=0))  P=$(round(ef.base.P_kw;digits=0))  FoS=$(round(mf;digits=2))  fail=$(nf)  $(v ? "✅ VIABLE" : "")")
        if v; return true; end
        if ef.base.P_kw > best_P; best_P=ef.base.P_kw; best_FoS=mf; best_k=k; best_w=w; end
    end
    @printf("  best: k=%.0f ω=%.0f P=%.0f FoS=%.2f %s\n", best_k, best_w, best_P, best_FoS, best_FoS >= 1.5 && best_P > 50 ? "✅" : "❌")
    return false
end

# Phase A: 4mm reinforced with blade bracketing
rounds = [
    ("Round 1: 4mm, r1.30, blade bracket", [
        (0.004, 1.30, 0.80), (0.004, 1.30, 0.85), (0.004, 1.30, 0.90),
        (0.004, 1.30, 0.95), (0.004, 1.30, 1.05), (0.004, 1.30, 1.10),
        (0.0035, 1.30, 1.0), (0.0035, 1.30, 1.05), (0.0035, 1.30, 1.10),
    ]),
    ("Round 2: 4mm, r1.15, wide blade", [
        (0.004, 1.15, 0.95), (0.004, 1.15, 1.0), (0.004, 1.15, 1.05),
        (0.004, 1.15, 1.10), (0.004, 1.15, 1.15),
    ]),
    ("Round 3: 4mm, r1.0, big blades", [
        (0.004, 1.0, 1.05), (0.004, 1.0, 1.10), (0.004, 1.0, 1.15), (0.004, 1.0, 1.20),
    ]),
    ("Round 4: 4mm, r1.40, heavy blade", [
        (0.004, 1.40, 1.05), (0.004, 1.40, 1.10), (0.004, 1.40, 1.15),
        (0.004, 1.40, 1.20), (0.004, 1.40, 1.25), (0.004, 1.40, 1.30),
    ]),
]

ks = [2.0, 4.0, 6.0, 8.0, 10.0, 14.0]
found = false
for (label, designs) in rounds
    println("\n=== $label ===")
    for (td, rbs, bs) in designs
        println("  tether=$(td*1000)mm  blade=$(bs)  r_bottom=$(rbs)")
        if test_design(td, rbs, bs, ks)
            global found = true
            println("\n*** VIABLE DESIGN FOUND: $((td*1000))mm, blade=$(bs), r_bottom=$(rbs) ***")
            break
        end
    end
    if found; break; end
end
if !found
    println("\n*** No viable design found across 3 rounds ***")
end
