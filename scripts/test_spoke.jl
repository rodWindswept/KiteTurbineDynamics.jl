using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

sp = SpokeParams(enabled=true)

# λ=0.69 blades + reinforced frame + spokes
fn = ControlMapHunt.v10_tight_builder(
    blade_scale=0.69, r_bottom_scale=1.30, tether_diameter=0.004)

sys, u0, p, label = Base.invokelatest(fn)
@printf("=== %s ===\n", label)
sys.k_mppt_ref[] = 6.23

function wf(pos, t)
    z = max(pos[3], 1.0)
    [11.0 * (z / p.h_ref)^(1/7), 0.0, 0.0]
end
u = KiteTurbineDynamics.settle_to_operational_state(sys, copy(u0), p, 4.5;
    lift_device=nothing)

n = round(Int, 60.0 / ControlMapHunt.DT)
uf = copy(u)
KiteTurbineDynamics.run_canonical_sim!(uf, sys, p, wf, n, ControlMapHunt.DT;
    lift_device=nothing, lin_damp=0.05, spoke=sp)

# Ring FoS
rf = Float64[]
for ref in KiteTurbineDynamics.ring_element_analysis(
    uf,
    collect(@view uf[(6*sys.n_total+1):(6*sys.n_total+sys.n_ring)]),
    sys, p, 60.0, wf)
    push!(rf, (isnan(ref.max_util) || ref.max_util <= 0) ? Inf : 1.0 / ref.max_util)
end
mf = minimum(r for r in rf if !isinf(r); init=Inf)
nf = count(r -> r < 1.5, rf)

# Ring positions
shaft = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
open("/tmp/l069_reinf_result.txt", "w") do io
    println(io, "λ=0.69 Reinforced + spokes: min_fos=", round(mf; digits=3),
            " n_fail=", nf, "/", length(rf))
    println(io, "Ring radii (r_nom → r_final):")
    for i in 1:sys.n_ring
        gid = sys.ring_ids[i]; gid === nothing && continue
        rn = (sys.nodes[gid]::RingNode).radius
        p1 = uf[(3*(gid-1)+1):(3*gid)]
        r1 = norm(p1 .- dot(p1, shaft) .* shaft)
        dr = r1 - rn
        println(io, "  ring$(i): $(round(rn; digits=2)) → $(round(r1; digits=2))  Δr=$(round(dr*1000; digits=1))mm")
    end
end
