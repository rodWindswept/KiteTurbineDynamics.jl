using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

sp = SpokeParams(enabled=true)
fn = ControlMapHunt.v10_tight_builder(
    blade_scale=0.69, r_bottom_scale=1.30, tether_diameter=0.004)

sys, u0, p, label = Base.invokelatest(fn)
@printf("\n=== %s ===\n", label)

# λ=0.69 Reinforced operates at k≈6.23 (from Gate 1, ~229 rpm)
k_mppt = 6.23
wind_ms = 11.0
target_w = 229 * 2π / 60  # rad/s

shaft = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
function wf(pos, t); z = max(pos[3], 1.0); [wind_ms*(z/p.h_ref)^(1/7), 0.0, 0.0]; end

# Phase 1: motor-mode spin-up (5s, k<0 drives the PTO)
sys.k_mppt_ref[] = -200.0  # motor mode
u = copy(u0)
print("Phase 1: Motor spin-up (5s)... ")
KiteTurbineDynamics.run_canonical_sim!(u, sys, p, wf,
    round(Int, 5.0/ControlMapHunt.DT), ControlMapHunt.DT;
    lift_device=nothing, lin_damp=0.05, spoke=sp)
hub_gid = sys.rotor.node_id
hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
N = sys.n_total
w_spun = abs(u[6N + sys.n_ring + hub_ri])
w_spun_rpm = w_spun * 60 / (2π)
@printf("ω=%.0f rpm (target %.0f)\n", w_spun_rpm, 229)

# Phase 2: switch to MPPT, run 60s
sys.k_mppt_ref[] = k_mppt
print("Phase 2: MPPT sustain (60s)... ")
u2 = copy(u)
n = round(Int, 60.0 / ControlMapHunt.DT)
KiteTurbineDynamics.run_canonical_sim!(u2, sys, p, wf, n, ControlMapHunt.DT;
    lift_device=nothing, lin_damp=0.05, spoke=sp)
w_end = abs(u2[6N + sys.n_ring + hub_ri])
w_end_rpm = w_end * 60 / (2π)

# Ring FoS
af = @view u2[(6N+1):(6N+sys.n_ring)]
rea = KiteTurbineDynamics.ring_element_analysis(u2, collect(af), sys, p, 60.0, wf)
rf = Float64[]
for ref in rea
    v = ref.max_util
    push!(rf, (isnan(v) || v <= 0) ? Inf : 1.0 / v)
end
mf = minimum(r for r in rf if !isinf(r); init=Inf)
nf = count(r -> r < 1.5, rf)
# Exclude ground ring (ring1 = PTO)
airborne_fos = rf[2:end]
mf_air = minimum(r for r in airborne_fos if !isinf(r); init=Inf)

# Power from last 5s
ef = ControlMapHunt.capture_extended(u2, sys, p, 60.0, wf, nothing; brake_engaged=false)
P_end = ef.base.P_kw

@printf("ω=%.0f rpm  P=%.1f kW  FoS(airborne)=%.2f  n_fail=%d/22\n",
    w_end_rpm, P_end, mf_air, nf)

# Ring positions
println("\nRing radii (r_nom → r_final):")
for i in 1:sys.n_ring
    gid = sys.ring_ids[i]; gid === nothing && continue
    rn = (sys.nodes[gid]::RingNode).radius
    p1 = u2[(3*(gid-1)+1):(3*gid)]
    r1 = norm(p1 .- dot(p1, shaft) .* shaft)
    dr = r1 - rn
    println("  ring$(i): $(round(rn; digits=2)) → $(round(r1; digits=2))  Δr=$(round(dr*1000; digits=1))mm")
end
