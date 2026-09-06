#!/usr/bin/env julia --project=.
#= test_rope_break.jl — acceptance tests for rope-break physics
(proposal: docs/plans/2026-08-14-rope-break-fling.md; Rod: SK99, option B —
break = immediate disqualification, sim stops at the break).
Re-baselined 2026-09-04 to the corrected 5 kW campaign (daisy params @ 18.8 m,
campaign decode knobs, mass-aware const-tension lift). Standalone.

R1: unit — a sub-segment strained past 3.5% returns zero tension and sets
    the broken flag; below the limit it is untouched.
R2: end-to-end — the pre-fix 18m winner (regression artifact) must NOT reach
    the balloon fixed point: either the lines break (sim stops, tension
    bounded) or |ω| stays ≤ 1e3.
R3: non-regression — the healthy seed runs 30 s without a break and lands
    in its known operating band (ω_gnd, re-measured on the corrected seed).
=#

using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

failures = String[]
function check(name::String, cond::Bool)
    println((cond ? "  ✅ " : "  ❌ "), name)
    cond || push!(failures, name)
end

# Campaign-aligned params: Daisy 1.5 kW → 5 kW at length L (mirrors
# run_v13_5kw_masslift.jl params_at_length).  mass_scale also scales the tether
# length, so the FINAL length is restored via override_params (2026-08-22 fix).
function params_at_length(L::Float64)
    p2 = KiteTurbineDynamics.params_daisy()
    KW = 5.0
    geo = KiteTurbineDynamics.GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = KiteTurbineDynamics.MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = KiteTurbineDynamics.AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = KiteTurbineDynamics.ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = KiteTurbineDynamics.BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = KiteTurbineDynamics.mass_scale(KiteTurbineDynamics.SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return KiteTurbineDynamics.override_params(scaled; tether_length=L)
end

# Campaign mass-aware constant-tension lift (mirrors ode_gate_v13.jl).
lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=1.5, v_ref=11.0, const_tension=true)

# Shared: build a system from a GENOME VECTOR at a given length, with the
# campaign decode knobs (x[10] = rotor count {1,2,3}).
function build_from(x::Vector{Float64}, L::Float64)
    pl = params_at_length(L)
    xr = copy(x)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))   # rotor_count_mode: {1,2,3}
    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, pl; power_W=5000.0,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=pl.tether_diameter, base_params=pl)
    return sys, u0, pc, pl
end

function read_genome_csv(csv_path::String)
    return [parse(Float64, s) for s in split(strip(read(csv_path, String)), ",")]
end

println("=== R1: line-level break criterion (healthy vs 5% line stretch) ===")
function run_r1()
    sys, u0, pc, p = build_from(seed_genome(5.0), 18.8)
    lift = rotary_lifter_default()
    wind_fn1(r, t) = [p.v_wind_ref, 0.0, 0.0]
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST   # campaign k for settle AND run
    u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wind_fn1, n_op=30_000)
    # one real-operation step from the healthy settle: no break expected
    run_canonical_sim!(u, sys, pc, wind_fn1, 1, 4e-5; lift_device=lift, lin_damp=0.05)
    broke_healthy = sys.any_broken[]
    # Stretch the top TRPT line WELL past the 3.5% break threshold by displacing
    # the hub ring axially by 20% of a segment length (2026-09-04: the corrected
    # seed's top segment is longer than the old machine's, so 5% of the average
    # segment no longer crosses 3.5% strain).
    gid_hub = sys.ring_ids[sys.n_ring]
    L_seg = pc.tether_length / (sys.n_ring - 1)
    u[(3*(gid_hub-1)+1):(3*gid_hub)] .+= 0.20 * L_seg .* [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    run_canonical_sim!(u, sys, pc, wind_fn1, 1, 4e-5; lift_device=lift, lin_damp=0.05)
    broke_stretched = sys.any_broken[]
    return broke_healthy, broke_stretched
end
bh, bs = run_r1()
println("  healthy step → broken=", bh, "   +5% line stretch step → broken=", bs)
check("R1a: healthy operation does not break lines", !bh)
check("R1b: a line stretched past 3.5% breaks (SK99)", bs)

println("=== R2: end-to-end — pre-fix 18m winner bounded or broken (regression) ===")
function run_r2()
    # Regression artifact: the pre-fix 18m winner must STILL not reach the
    # balloon fixed point (bounded |ω| or line break).
    sys2, u02, pc2, p2 = build_from(
        read_genome_csv(joinpath(@__DIR__, "..", "scripts", "results", "void_v13_pre-fix_len18.0", "best_vector.csv")), 18.8)
    lift = rotary_lifter_default()
    wind_fn2(r, t) = [p2.v_wind_ref, 0.0, 0.0]
    sys2.k_mppt_ref[] = K_MPPT_5KW_HONEST   # campaign k for settle AND run
    u2 = settle_to_operational_state(sys2, copy(u02), pc2, 60.0; lift_device=lift, wind_fn=wind_fn2, n_op=30_000)
    N2 = sys2.n_total; Nr2 = sys2.n_ring
    wmax = 0.0
    Tmax = 0.0
    for chunk in 1:6
        run_canonical_sim!(u2, sys2, pc2, wind_fn2, round(Int, 5.0 / 4e-5), 4e-5; lift_device=lift, lin_damp=0.05)
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
    sys3, u03, pc3, p3 = build_from(seed_genome(5.0), 18.8)
    lift = rotary_lifter_default()
    wind_fn3(r, t) = [p3.v_wind_ref, 0.0, 0.0]
    sys3.k_mppt_ref[] = K_MPPT_5KW_HONEST   # campaign k for settle AND run
    u3 = settle_to_operational_state(sys3, copy(u03), pc3, 60.0; lift_device=lift, wind_fn=wind_fn3, n_op=30_000)
    N3 = sys3.n_total; Nr3 = sys3.n_ring
    # 2026-09-04: use the STABLE dt (not fixed 4e-5) + a 10 s relax phase, both
    # to match the evaluator's cold path.  The fixed 4e-5 is 2× too coarse for
    # the seed's short transmission sub-segs and blows the rope tension to
    # ~2.76 MN on the settle→run transition (false break).
    dt3 = KiteTurbineDynamics.stable_dt_for_system(sys3, pc3)
    for _ in 1:2
        run_canonical_sim!(u3, sys3, pc3, wind_fn3, round(Int, 5.0 / dt3), dt3; lift_device=lift, lin_damp=0.05)
    end
    for chunk in 1:6
        run_canonical_sim!(u3, sys3, pc3, wind_fn3, round(Int, 5.0 / dt3), dt3; lift_device=lift, lin_damp=0.05)
    end
    return u3[6N3 + Nr3 + 1], sys3.any_broken[]
end
w_gnd3, broke3 = run_r3()
println("  ω_gnd @30s = ", round(w_gnd3, digits=2), " rad/s  broken=", broke3)
check("R3: seed never breaks", !broke3)
check("R3: seed lands in its known band (ω_gnd re-measured)", 14.0 <= w_gnd3 <= 16.5)

println()
if isempty(failures)
    println("ALL ACCEPTANCE TESTS PASS")
else
    println("FAILED: ", join(failures, ", "))
    error("FAILED: " * join(failures, ", "))
end
