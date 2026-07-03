#!/usr/bin/env julia
# scripts/test_v10_reinforced.jl
# Test: V10 Tight with larger bottom rings via build_kite_turbine_system_v5
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "builders_util.jl"))

for s in [1.0, 1.3, 1.5]
    println("\n══════ scale=$s ══════")
    sys, u0, p, label = build_v10_tight_no_lowest(; tether_diameter=0.004, r_bottom_scale=s)
    r1 = sys.nodes[sys.ring_ids[1]].radius
    rN = sys.nodes[sys.ring_ids[sys.n_ring]].radius
    println("r1=$(round(r1,digits=2))m r$(sys.n_ring)=$(round(rN,digits=2))m (rings=$(sys.n_ring))")

    lift = rotary_lifter_default()
    wf(pos, t) = begin z = max(pos[3], 1.0); [11.0*(z/p.h_ref)^(1.0/7.0), 0.0, 0.0] end
    sys.k_mppt_ref[] = 200.0

    u = settle_to_operational_state(sys, copy(u0), p, 9.5; lift_device=lift, wind_fn=wf)
    N = sys.n_total; Nr = sys.n_ring
    n_steps = round(Int, 30.0/4e-5); t0w = time()

    run_canonical_sim!(u, sys, p, wf, n_steps, 4e-5;
        lift_device=lift, lin_damp=0.05,
        callback=(u_curr, t_curr, step) -> begin
            if step == n_steps
                sf = capture_frame(u_curr, sys, p, t_curr, wf, lift; brake_engaged=false)
                av = collect(@view u_curr[(6N+1):(6N+Nr)])
                rea = ring_element_analysis(u_curr, av, sys, p, t_curr, wf)
                fos_vec = [isnan(r.max_util) ? Inf : 1.0/max(r.max_util,1e-6) for r in rea]
                T_max, _ = get_max_rope_tension(u_curr, sys, p)
                n_fail = sum(fos_vec .< 1.5)
                println("  P=$(round(sf.P_kw,digits=1))kW minFoS=$(round(minimum(fos_vec),digits=2))@r$(argmin(fos_vec)) T/SWL=$(round(T_max/3500,digits=2)) fail=$n_fail/$(length(fos_vec))")
            end
        end)
end
