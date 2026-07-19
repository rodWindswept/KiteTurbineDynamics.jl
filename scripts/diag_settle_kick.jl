#!/usr/bin/env julia
# Quick diagnostic: find evaluation protocol that produces realistic power.
# Test both settlement approaches (ω_rated sweep + kickstart) on 2 candidates.
using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
include(joinpath(dirname(@__DIR__), "src", "builders_util.jl"))

set_expansion_physics!(ExpansionPhysics(true, true, true))
const WIND = 11.0

# ── Candidates ──
sysT, u0T, pT, _ = build_phantom_triangle(blade_scale=0.85)
sys12, u012, p12, _ = build_v10_tight_no_lowest(blade_scale=0.80)

function eval_settle(label, sys, u0, p, ω_rated)
    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [WIND * (z/p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end
    u = settle_to_operational_state(sys, copy(u0), p, ω_rated; wind_fn=wf)
    ef = capture_extended(u, sys, p, 0.0, wf, nothing; brake_engaged=false)
    P = ef.base.P_kw; ω = ef.base.omega_hub * 60/(2π)
    @printf("  settle ω_rated=%.0f:  P=%.1f kW  ω=%.0f rpm\n", ω_rated, P, ω)
end

function eval_kickstart(label, sys, u0, p, ks)
    # Adapted from kickstart_sweep protocol: kick to high ω, then engage MPPT.
    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [WIND * (z/p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end
    dk = ControlMapHunt.DT
    u = copy(u0)
    # Phase 1: pre-load tether by running 10s with damped hub torque
    sys.brake_engaged[] = false
    sys.k_mppt_ref[] = 0.0
    run_canonical_sim!(u, sys, p, wf, round(Int, 10/dk), dk; lift_device=nothing, lin_damp=0.05)
    # Phase 2: kick — set k_mppt = ks and run for evaluation window
    sys.k_mppt_ref[] = Float64(ks)
    n = round(Int, 60/dk)
    out = Ref((0.0, 0.0, Inf))
    run_canonical_sim!(u, sys, p, wf, n, dk; lift_device=nothing, lin_damp=0.05,
        callback=(uc, tc, s) -> begin
            if s == n
                ef = capture_extended(uc, sys, p, tc, wf, nothing; brake_engaged=sys.brake_engaged[])
                airborne = Float64[]
                for i in 2:length(ef.ring_fos)
                    v = ef.ring_fos[i]; (!isnan(v)&&!isinf(v)&&v>0) && push!(airborne, v)
                end
                fos = isempty(airborne) ? Inf : minimum(airborne)
                out[] = (ef.base.P_kw, ef.base.omega_hub*60/(2π), fos)
            end
        end)
    P, ω, fos = out[]
    @printf("  kick ks=%.0f:       P=%.1f kW  ω=%.0f rpm  FoS=%.2f\n", ks, P, ω, fos)
end

println("=== triangle3_0.85 ===")
for ωr in [5.0, 10.0, 20.0, 60.0]
    eval_settle("triangle3", sysT, u0T, pT, ωr)
end
for ks in [2, 4, 8, 16]
    eval_kickstart("triangle3", sysT, u0T, pT, ks)
end

println("\n=== 12gon_0.80 ===")
for ωr in [5.0, 10.0, 20.0, 60.0]
    eval_settle("12gon", sys12, u012, p12, ωr)
end
for ks in [2, 10, 30, 62, 90, 150]
    eval_kickstart("12gon", sys12, u012, p12, ks)
end
