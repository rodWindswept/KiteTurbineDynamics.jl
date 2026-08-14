#!/usr/bin/env julia --project=.
#= diag_chain_state.jl — distinguish torsional decoupling from brake latch.
At the 50-60s mark: brake state, twist angles across the chain (vs collapse
limit δα*), and rope torques per ring pair. =#

using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0; const PW = 5000.0; const DT = 4e-5
p = mass_scale(params_10kw(), 10.0, KW)
x = [parse(Float64, s) for s in split(strip(read(joinpath(@__DIR__, "results", "v12_5kw_coldstart", "island_1_best.csv"), String)), ",")]
x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
x[10] = clamp(x[10], 0.0, Float64(N_VALID_MASKS))
dec = design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=PW)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, p.k_mppt; tether_diameter=p.tether_diameter)
wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
lift = rotary_lifter_default()

u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wind_fn, n_op=30_000)
N = sys.n_total; Nr = sys.n_ring
sys.k_mppt_ref[] = p.k_mppt

# Run to 60s, checkpoint at 10s intervals from 30s
for chunk in 1:12
    run_canonical_sim!(u, sys, pc, wind_fn, round(Int, 5.0/DT), DT; lift_device=lift, lin_damp=0.05)
    t = chunk * 5.0
    if t in [30.0, 40.0, 50.0, 60.0]
        omega = u[(6N + Nr + 1):(6N + 2Nr)]
        alpha = u[(6N + 1):(6N + Nr)]
        hub_ri = (sys.nodes[sys.rotor.node_id]::RingNode).ring_idx
        gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx

        # Per-ring-pair twist difference Δα and per-ring ω
        println("\n── t=$(t)s  brake=", sys.brake_engaged[], " ──")
        println("ring (ground→hub):  ω        Δα vs next ring (deg)")
        for ri in 1:Nr
            da = ri < Nr ? rad2deg(alpha[ri+1] - alpha[ri]) : NaN
            @printf("  %2d: %8.3f  %10.2f\n", ri, omega[ri], da)
        end
        # Collapse limit: δα* = 2·arcsin(L/√(2(L²+2r²))) for the ground segment
        r_ground = (sys.nodes[sys.ring_ids[1]]::RingNode).radius
        r_2 = (sys.nodes[sys.ring_ids[2]]::RingNode).radius
        L_seg = norm(u[(3*(sys.ring_ids[2]-1)+1):(3*sys.ring_ids[2])] - u[(3*(sys.ring_ids[1]-1)+1):(3*sys.ring_ids[1])])
        dastar = rad2deg(2 * asin(min(L_seg / sqrt(2*(L_seg^2 + 2*r_ground^2)), 1.0)))
        @printf("  collapse limit δα* (ground seg): %.1f°  (L=%.2f m, r=%.2f m)\n", dastar, L_seg, r_ground)
    end
end
