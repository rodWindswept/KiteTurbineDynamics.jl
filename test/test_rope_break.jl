#!/usr/bin/env julia --project=.
#= test_rope_break.jl — acceptance tests for rope-break physics
(proposal: docs/plans/2026-08-14-rope-break-fling.md; Rod: SK99, option B —
break = immediate disqualification, sim stops at the break).
RED on master, GREEN after implementation. Standalone.

R1: unit — a sub-segment strained past 3.5% returns zero tension and sets
    the broken flag; below the limit it is untouched.
R2: end-to-end — the 18m v13 winner must NOT reach the balloon fixed point:
    either the lines break (sim stops, tension bounded) or |ω| stays ≤ 1e3.
R3: non-regression — the healthy seed runs 30 s without a break and lands
    in its known operating band (ω_gnd ≈ 12.5–13.5 rad/s).
=#

using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

failures = String[]
function check(name::String, cond::Bool)
    println((cond ? "  ✅ " : "  ❌ "), name)
    cond || push!(failures, name)
end

# Shared: build a system from a genome CSV at a given length (like the gate).
function build_from(csv_path::String, L::Float64)
    x = [parse(Float64, s) for s in split(strip(read(csv_path, String)), ",")]
    p = KiteTurbineDynamics.params_10kw()
    KW = 5.0
    geo = KiteTurbineDynamics.GeometrySpec(p.elevation_angle, p.lifter_elevation, p.rotor_radius,
        L, p.trpt_hub_radius, p.trpt_rL_ratio, p.n_lines, p.n_rings, p.n_blades)
    mat = KiteTurbineDynamics.MaterialSpec(p.tether_diameter, p.e_modulus, p.m_ring, p.m_blade)
    aero = KiteTurbineDynamics.AeroSpec(p.rho, p.v_wind_ref, p.h_ref, p.cp)
    ctrl = KiteTurbineDynamics.ControlSpec(p.i_pto, p.k_mppt, p.p_rated_w, p.β_min, p.β_max, p.β_rate_max, p.kp_elev)
    back = KiteTurbineDynamics.BackLineSpec(p.EA_back_line, p.c_back_line, p.back_anchor_fwd_x, p.backline_payout)
    pl = KiteTurbineDynamics.mass_scale(KiteTurbineDynamics.SystemParams(geo, mat, aero, ctrl, back), 10.0, KW)
    xr = copy(x)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))
    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, pl; power_W=5000.0)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, pl.k_mppt; tether_diameter=pl.tether_diameter)
    return sys, u0, pc, pl
end

println("=== R1: line-level break criterion (healthy vs 5% line stretch) ===")
function run_r1()
    sys, u0, pc, p = build_from(joinpath(@__DIR__, "..", "scripts", "results", "seed_5kw.csv"), 21.2)
    wind_fn1(r, t) = [p.v_wind_ref, 0.0, 0.0]
    u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=rotary_lifter_default(), wind_fn=wind_fn1, n_op=30_000)
    sys.k_mppt_ref[] = p.k_mppt
    # one real-operation step from the healthy settle: no break expected
    run_canonical_sim!(u, sys, pc, wind_fn1, 1, 4e-5; lift_device=rotary_lifter_default(), lin_damp=0.05)
    broke_healthy = sys.any_broken[]
    # stretch the top TRPT line ~5% by displacing the hub ring axially
    gid_hub = sys.ring_ids[sys.n_ring]
    L_seg = pc.tether_length / (sys.n_ring - 1)
    u[(3*(gid_hub-1)+1):(3*gid_hub)] .+= 0.05 * L_seg .* [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    run_canonical_sim!(u, sys, pc, wind_fn1, 1, 4e-5; lift_device=rotary_lifter_default(), lin_damp=0.05)
    broke_stretched = sys.any_broken[]
    return broke_healthy, broke_stretched
end
bh, bs = run_r1()
println("  healthy step → broken=", bh, "   +5% line stretch step → broken=", bs)
check("R1a: healthy operation does not break lines", !bh)
check("R1b: a line stretched past 3.5% breaks (SK99)", bs)

println("=== R2: end-to-end — 18m winner bounded or broken ===")
function run_r2()
    sys2, u02, pc2, p2 = build_from(joinpath(@__DIR__, "..", "scripts", "results", "void_v13_pre-fix_len18.0", "best_vector.csv"), 18.0)
    wind_fn2(r, t) = [p2.v_wind_ref, 0.0, 0.0]
    u2 = settle_to_operational_state(sys2, copy(u02), pc2, 60.0; lift_device=rotary_lifter_default(), wind_fn=wind_fn2, n_op=30_000)
    N2 = sys2.n_total; Nr2 = sys2.n_ring
    sys2.k_mppt_ref[] = p2.k_mppt
    wmax = 0.0
    Tmax = 0.0
    for chunk in 1:6
        run_canonical_sim!(u2, sys2, pc2, wind_fn2, round(Int, 5.0 / 4e-5), 4e-5; lift_device=rotary_lifter_default(), lin_damp=0.05)
        wmax = max(wmax, maximum(abs, @view u2[(6N2 + Nr2 + 1):(6N2 + 2Nr2)]))
        Tmax = max(Tmax, get_max_rope_tension(u2, sys2, pc2)[1])
        sys2.any_broken[] && break
    end
    return wmax, Tmax, sys2.any_broken[]
end
wmax2, Tmax2, broke2 = run_r2()
println("  max|ω|=", wmax2, "  max tension=", round(Tmax2, digits=1), " N  broken=", broke2)
check("R2: no balloon fixed point — bounded |ω| or broken", broke2 || (isfinite(wmax2) && wmax2 <= 1e3))
# Elastic break tension at 3.5% strain ≈ 44 kN (SK99, 4 mm); the sampled
# total includes the damper's viscous regularization term (does not stretch
# the line), so the bar is 2e5 N — still ~1e130 below the balloon values
# this test exists to kill.
check("R2: tension stays bounded (≤ 2e5 N; elastic break ≈ 44 kN)", Tmax2 <= 2e5)

println("=== R3: non-regression — seed stays healthy ===")
function run_r3()
    sys3, u03, pc3, p3 = build_from(joinpath(@__DIR__, "..", "scripts", "results", "seed_5kw.csv"), 21.2)
    wind_fn3(r, t) = [p3.v_wind_ref, 0.0, 0.0]
    u3 = settle_to_operational_state(sys3, copy(u03), pc3, 60.0; lift_device=rotary_lifter_default(), wind_fn=wind_fn3, n_op=30_000)
    N3 = sys3.n_total; Nr3 = sys3.n_ring
    sys3.k_mppt_ref[] = p3.k_mppt
    for chunk in 1:6
        run_canonical_sim!(u3, sys3, pc3, wind_fn3, round(Int, 5.0 / 4e-5), 4e-5; lift_device=rotary_lifter_default(), lin_damp=0.05)
    end
    return u3[6N3 + Nr3 + 1], sys3.any_broken[]
end
w_gnd3, broke3 = run_r3()
println("  ω_gnd @30s = ", round(w_gnd3, digits=2), " rad/s  broken=", broke3)
check("R3: seed never breaks", !broke3)
check("R3: seed lands in its known band (12.5–13.5 rad/s)", 12.5 <= w_gnd3 <= 13.5)

println()
if isempty(failures)
    println("ALL ACCEPTANCE TESTS PASS")
else
    println("FAILED: ", join(failures, ", "))
    error("FAILED: " * join(failures, ", "))
end
