using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

sp = SpokeParams(enabled=true)
fn = ControlMapHunt.v10_tight_builder(
    blade_scale=0.69, r_bottom_scale=1.30, tether_diameter=0.004)
sys, u0, p, _ = Base.invokelatest(fn)
sys.k_mppt_ref[] = -500.0  # motor mode
shaft = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]

function wf(pos, t)
    z = max(pos[3], 1.0)
    [11.0 * (z / p.h_ref)^(1/7), 0.0, 0.0]
end

u = copy(u0)
# Run 0.5s motor spin-up, check spoke activations after each 0.05s chunk
for seg in 1:10
    KiteTurbineDynamics.run_canonical_sim!(u, sys, p, wf,
        round(Int, 0.05 / ControlMapHunt.DT), ControlMapHunt.DT;
        lift_device=nothing, lin_damp=0.05, spoke=sp)
    # Check ring drift
    local hits = 0
    local mx = 0.0
    for i in 2:length(sys.ring_ids)
        local gid = sys.ring_ids[i]
        gid === nothing && continue
        pos = u[(3*(gid-1)+1):(3*gid)]
        r = norm(pos .- dot(pos, shaft) .* shaft)
        if r > 1e-6
            hits += 1
            mx = max(mx, r)
        end
    end
    if hits > 0
        N = sys.n_total
        hr = (sys.nodes[sys.rotor.node_id]::RingNode).ring_idx
        w_rpm = abs(u[6N+sys.n_ring+hr]) * 60 / (2π)
        @printf("t=%.2fs  ω=%.0frpm  n_rings_drifted=%d  max_drift=%.1fmm\n",
            seg*0.05, w_rpm, hits, mx*1000)
    end
end
println("Done")
