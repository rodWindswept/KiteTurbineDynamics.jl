using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, LinearAlgebra, Printf

p = params_10kw()
sys, u0 = build_kite_turbine_system(p)
u_start = settle_to_equilibrium(sys, u0, p)
N  = sys.n_total
Nr = sys.n_ring

ω_rated = 9.5
τ_rated  = p.k_mppt * ω_rated^2
EA_rope  = p.e_modulus * π * (p.tether_diameter / 2)^2
L_seg    = p.tether_length / (Nr - 1)
β_a      = p.elevation_angle
sd       = [cos(β_a), 0.0, sin(β_a)]
pp1, pp2 = shaft_perp_basis(sd)

for ri in 1:Nr
    u_start[6N + Nr + ri] = ω_rated
end
u_start[6N + 1] = 0.0

α_cum = 0.0
for s in 1:(Nr - 1)
    global α_cum
    gid_a = sys.ring_ids[s]
    gid_b = sys.ring_ids[s + 1]
    na    = sys.nodes[gid_a]::RingNode
    nb    = sys.nodes[gid_b]::RingNode
    r_s   = (na.radius + nb.radius) * 0.5
    τ_fn = (Δα) -> begin
        chord = sqrt(L_seg^2 + 2 * r_s^2 * (1 - cos(Δα)))
        T = p.n_lines * EA_rope * max(0.0, (chord - L_seg) / L_seg)
        T * r_s^2 * sin(Δα) / chord
    end
    lo, hi = 0.001, π / 4
    for _ in 1:60
        mid = (lo + hi) / 2
        τ_fn(mid) < τ_rated ? (lo = mid) : (hi = mid)
    end
    Δα_eq  = (lo + hi) / 2
    α_cum += Δα_eq
    u_start[6N + nb.ring_idx] = α_cum
    α_a   = u_start[6N + na.ring_idx]
    α_b   = u_start[6N + nb.ring_idx]
    ctr_a = u_start[3*(gid_a-1)+1 : 3*gid_a]
    ctr_b = u_start[3*(gid_b-1)+1 : 3*gid_b]
    for j in 1:p.n_lines
        pa = attachment_point(ctr_a, na.radius, α_a, j, p.n_lines, pp1, pp2)
        pb = attachment_point(ctr_b, nb.radius, α_b, j, p.n_lines, pp1, pp2)
        for m in 1:3
            frac = m / 4.0
            gid  = (s - 1) * 16 + 2 + (j - 1) * 3 + (m - 1)
            u_start[3*(gid-1)+1 : 3*gid] .= pa .+ frac .* (pb .- pa)
        end
    end
end

println("α_hub = $(round(α_cum, digits=4)) rad ($(round(rad2deg(α_cum), digits=1))°)")

wind_fn = (pos, t) -> begin
    z  = max(pos[3], 1.0)
    sh = (z / p.h_ref)^(1.0/7.0)
    [p.v_wind_ref * sh, 0.0, 0.0]
end

# Manually compute torques, separated by source
# 1. rope_forces torques
forces_r = [zeros(3) for _ in 1:N]
torques_r = zeros(Nr)
alpha0 = u_start[6N+1:6N+Nr]
compute_rope_forces!(forces_r, torques_r, u_start, alpha0, sys, p, wind_fn, 0.0)

# 2. ring_forces torques
forces_k = [zeros(3) for _ in 1:N]
torques_k = zeros(Nr)
omega0 = u_start[6N+Nr+1:6N+2Nr]
compute_ring_forces!(forces_k, torques_k, u_start, omega0, sys, p, wind_fn, 0.0)

hub_gid  = sys.rotor.node_id
hub_node = sys.nodes[hub_gid]::RingNode
hub_ri   = hub_node.ring_idx

println("\n-- Torque breakdown at t=0 --")
println("ring     rope_torque   ring_torque    net_torque    dω/dt")
for ri in [1, 2, 3, hub_ri-1, hub_ri]
    node = sys.nodes[sys.ring_ids[ri]]::RingNode
    I_z  = node.inertia_z
    net  = torques_r[ri] + torques_k[ri]
    @printf "  ri=%2d  %9.2f N·m  %9.2f N·m  %9.2f N·m  %9.3f rad/s²\n" ri torques_r[ri] torques_k[ri] net (net/I_z)
end

println("\nExpected τ_rated = $(round(τ_rated, digits=1)) N·m at ω=$(ω_rated) rad/s")
