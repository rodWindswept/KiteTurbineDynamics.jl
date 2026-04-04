#!/usr/bin/env julia
# Quick physics check: does the ground ring spin when the hub does?
# Runs 5000 steps (0.2 s) — no GLMakie.
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, LinearAlgebra

p       = params_10kw()
sys, u0 = build_kite_turbine_system(p)
u_start = settle_to_equilibrium(sys, u0, p)

N  = sys.n_total
Nr = sys.n_ring

# Seed ω gradient: 0 at ground → 9 rad/s at hub (mirrors interactive_dashboard.jl)
let ω_hub = 9.0
    for ri in 1:Nr
        frac = (ri - 1) / (Nr - 1)
        u_start[6N + Nr + ri] = ω_hub * frac
    end
end

# Seed helical pre-twist: α[ri] = (ri-1) × 0.05 rad
# Required with corrected torsional formula (cubic in Δα); zero torque at Δα=0.
let Δα_pre = 0.05
    β_a  = p.elevation_angle
    sd   = [cos(β_a), 0.0, sin(β_a)]
    pp1, pp2 = shaft_perp_basis(sd)
    for ri in 1:Nr
        u_start[6N + ri] = (ri - 1) * Δα_pre
    end
    for s in 1:(Nr - 1)
        gid_a = sys.ring_ids[s];  gid_b = sys.ring_ids[s + 1]
        na    = sys.nodes[gid_a]::RingNode
        nb    = sys.nodes[gid_b]::RingNode
        α_a   = u_start[6N + na.ring_idx];  α_b = u_start[6N + nb.ring_idx]
        ctr_a = u_start[3*(gid_a-1)+1 : 3*gid_a]
        ctr_b = u_start[3*(gid_b-1)+1 : 3*gid_b]
        for j in 1:p.n_lines
            pa = attachment_point(ctr_a, na.radius, α_a, j, p.n_lines, pp1, pp2)
            pb = attachment_point(ctr_b, nb.radius, α_b, j, p.n_lines, pp1, pp2)
            for m in 1:3
                gid = (s - 1) * 16 + 2 + (j - 1) * 3 + (m - 1)
                u_start[3*(gid-1)+1 : 3*gid] .= pa .+ (m / 4.0) .* (pb .- pa)
            end
        end
    end
end

wind_fn = (pos, t) -> begin
    z  = max(pos[3], 1.0)
    sh = (z / p.h_ref)^(1.0/7.0)
    [p.v_wind_ref * sh, 0.0, 0.0]
end

const DT        = 4e-5
const LIN_DAMP  = 0.05
const N_STEPS   = 5_000

u  = copy(u_start)
du = zeros(Float64, length(u))

println("Running $N_STEPS steps ($(N_STEPS*DT) s)...")
println("Ring count: Nr=$Nr,  N_total=$N")
println()

# Corrected torsional formula: τ = n × EA × r_s² × sin(Δα) × (chord−L₀)/(L₀·chord)
L_seg   = p.tether_length / (Nr - 1)
EA_rope = p.e_modulus * π * (p.tether_diameter / 2)^2
@printf("L_seg = %.3f m,  EA_rope = %.4g N\n", L_seg, EA_rope)
println("Initial rope tensions at Δα_pre = 0.05 rad/segment:")
for ri in 1:Nr - 1
    node_a = sys.nodes[sys.ring_ids[ri]]::RingNode
    node_b = sys.nodes[sys.ring_ids[ri+1]]::RingNode
    r_s    = (node_a.radius + node_b.radius) * 0.5
    Δα0    = 0.05
    chord0 = sqrt(L_seg^2 + 2 * r_s^2 * (1 - cos(Δα0)))
    T0     = p.n_lines * EA_rope * (chord0 - L_seg) / L_seg
    τ0     = T0 * r_s^2 * sin(Δα0) / chord0
    @printf("  Seg %2d: r_s=%.3f m, T_rope=%.1f N (per 5 lines), τ_rope=%.1f N·m\n",
            ri, r_s, T0, τ0)
end
println()

let t = 0.0
    for step in 1:N_STEPS
        fill!(du, 0.0)
        multibody_ode!(du, u, (sys, p, wind_fn), t)
        t += DT

        @views u[3N+1:6N]        .+= DT .* du[3N+1:6N]
        @views u[1:3N]            .+= DT .* u[3N+1:6N]
        @views u[6N+Nr+1:6N+2Nr] .+= DT .* du[6N+Nr+1:6N+2Nr]
        @views u[6N+1:6N+Nr]     .+= DT .* u[6N+Nr+1:6N+2Nr]

        @views u[3N+1:6N]        .*= LIN_DAMP
        u[1:3]       .= 0.0
        u[3N+1:3N+3] .= 0.0
    end
end

println("=== After $(N_STEPS*DT) s ===")
println("Ring  | radius (m) | alpha (rad) | omega (rad/s)")
println("------|-----------|-------------|---------------")
for ri in 1:Nr
    node  = sys.nodes[sys.ring_ids[ri]]::RingNode
    α     = u[6N + ri]
    ω     = u[6N + Nr + ri]
    label = ri == 1 ? " ← GND/PTO" : (ri == Nr ? " ← HUB" : "")
    @printf("  %2d  | %7.3f   | %+10.5f  | %+10.5f  %s\n",
            ri, node.radius, α, ω, label)
end
println()

hub_ri = Nr
gnd_ri = 1
hub_ω  = u[6N + Nr + hub_ri]
gnd_ω  = u[6N + Nr + gnd_ri]
@printf("Hub ω     = %+.4f rad/s\n", hub_ω)
@printf("Ground ω  = %+.4f rad/s (target: nonzero)\n", gnd_ω)
if abs(gnd_ω) > 1e-4
    @printf("ω ratio hub/gnd = %.2f\n", hub_ω / gnd_ω)
    println("✓ Ground ring IS spinning — torsional coupling active")
else
    println("✗ Ground ring still NOT spinning — coupling ineffective")
end
