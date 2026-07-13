#!/usr/bin/env julia
# Kickstart test for blade 0.85 — proper no-load spin-up then engage
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

println("=== Kickstart test: blade 0.85 ===")
fn = ControlMapHunt.v10_tight_builder(blade_scale=0.85)
sys, u0, p, _ = Base.invokelatest(fn)
sp = SpokeParams(enabled=true)
wf(pos, t) = begin
    z = max(pos[3], 1.0)
    [11.0 * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
end

N = sys.n_total
Nr = sys.n_ring
omega_kick = 15.0  # 143 rpm
snap_times = [15.0, 30.0, 45.0, 60.0, 90.0, 120.0]
dt = ControlMapHunt.DT

# ── Test 1: No-load spin-up (k=0), then engage k=2 ─────────────────
println("\n── Test 1: 30s no-load (k=0), then engage k=2 for 90s ──")
u1 = settle_to_equilibrium(sys, copy(u0), p; wind_fn=wf)
for ri in 1:Nr
    u1[6*N + Nr + ri] = omega_kick
end
# Set orbital velocities for kicked rings
for ri in 1:Nr
    gid = sys.ring_ids[ri]
    pos = u1[(3*(gid-1)+1):(3*gid)]
    r = norm(pos)
    if r > 0.01
        tang = [-pos[2], pos[1], 0.0]
        tang ./= norm(tang)
        v_orb = omega_kick * r
        vx_idx = 3*N + 3*(gid-1) + 1
        u1[vx_idx:(vx_idx+2)] .= v_orb .* tang
    end
end
println("  Kicked to $(round(omega_kick*60/(2π))) rpm")

sys.k_mppt_ref[] = 0.0
n_noload = round(Int, 30.0 / dt)
out1 = Ref(Dict{Float64, Tuple{Float64, Float64}}())

run_canonical_sim!(u1, sys, p, wf, n_noload, dt;
    lift_device=nothing, lin_damp=0.05, spoke=sp,
    callback=(u_curr, t_curr, step) -> begin
        if step == n_noload
            ef = capture_extended(u_curr, sys, p, t_curr, wf, nothing; brake_engaged=sys.brake_engaged[])
            P_aero = sum(ef.rotor_aero_power) / 1000.0
            @printf("  No-load end: P_aero=%.1f kW, ω=%.0f rpm\n",
                P_aero, ef.base.omega_hub * 60 / (2π))
        end
    end)

# Now engage k=2
sys.k_mppt_ref[] = 2.0
snap_steps = [round(Int, t/dt) for t in snap_times]
n_mppt = maximum(snap_steps)

run_canonical_sim!(u1, sys, p, wf, n_mppt, dt;
    lift_device=nothing, lin_damp=0.05, spoke=sp,
    callback=(u_curr, t_curr, step) -> begin
        for (t_snap, s) in zip(snap_times, snap_steps)
            if step == s
                ef = capture_extended(u_curr, sys, p, t_curr, wf, nothing; brake_engaged=sys.brake_engaged[])
                out1[][t_snap] = (ef.base.P_kw, ef.base.omega_hub * 60 / (2π))
            end
        end
    end)

println("  k=2 engaged:")
for t in sort(collect(keys(out1[])))
    P, w = out1[][t]
    @printf("    %5.0fs  P=%6.1f kW  ω=%5.0f rpm\n", t, P, w)
end

# ── Test 2: Direct kickstart into k=2 (no no-load phase) ──────────
println("\n── Test 2: Direct kickstart into k=2 ──")
sys2, _, p2, _ = Base.invokelatest(fn)
sys2.k_mppt_ref[] = 2.0
u2 = settle_to_equilibrium(sys2, copy(u0), p2; wind_fn=wf)
for ri in 1:Nr
    u2[6*N + Nr + ri] = omega_kick
end
for ri in 1:Nr
    gid = sys2.ring_ids[ri]
    pos = u2[(3*(gid-1)+1):(3*gid)]
    r = norm(pos)
    if r > 0.01
        tang = [-pos[2], pos[1], 0.0]
        tang ./= norm(tang)
        v_orb = omega_kick * r
        vx_idx = 3*N + 3*(gid-1) + 1
        u2[vx_idx:(vx_idx+2)] .= v_orb .* tang
    end
end
println("  Kicked to $(round(omega_kick*60/(2π))) rpm, k=2 immediate")

out2 = Ref(Dict{Float64, Tuple{Float64, Float64}}())
run_canonical_sim!(u2, sys2, p2, wf, n_mppt, dt;
    lift_device=nothing, lin_damp=0.05, spoke=sp,
    callback=(u_curr, t_curr, step) -> begin
        for (t_snap, s) in zip(snap_times, snap_steps)
            if step == s
                ef = capture_extended(u_curr, sys2, p, t_curr, wf, nothing; brake_engaged=sys2.brake_engaged[])
                out2[][t_snap] = (ef.base.P_kw, ef.base.omega_hub * 60 / (2π))
            end
        end
    end)

for t in sort(collect(keys(out2[])))
    P, w = out2[][t]
    @printf("    %5.0fs  P=%6.1f kW  ω=%5.0f rpm\n", t, P, w)
end

println("\nDone.")
