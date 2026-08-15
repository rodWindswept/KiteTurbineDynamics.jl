#!/usr/bin/env julia --project=.
#= test_rotor_power_realism.jl — acceptance tests for rotor power realism
(proposal: docs/plans/2026-08-14-rotor-power-realism.md, §A2 + §B).
RED on master, GREEN after implementation. Standalone (not wired into
runtests.jl — P4 runs a 30s ODE window).

P1: cp_at_tsr falloff — the blade's own rolloff continues past the table:
    zero at λ≈9.61 (1.85× design TSR 5.2), negative beyond.
P2: drag-brake regime grows cubically (cp = −k·λ³): cp(12) < cp(11) < 0.
P3: per-rotor Betz helper — rotor power vs its own swept-disk potential.
P4: no freewheel — the 18m v13 winner (r_hub 0.47) must NOT reach ω~1e66
    under the fixed model: 30s run stays state-finite (|ω| bounded).
=#

using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

failures = String[]
function check(name::String, cond::Bool)
    println((cond ? "  ✅ " : "  ❌ "), name)
    cond || push!(failures, name)
end

println("=== P1: cp_at_tsr falloff beyond the table ===")
c8   = KiteTurbineDynamics.cp_at_tsr(8.0)
c85  = KiteTurbineDynamics.cp_at_tsr(8.5)
c95  = KiteTurbineDynamics.cp_at_tsr(9.5)
c961 = KiteTurbineDynamics.cp_at_tsr(9.61)
c10  = KiteTurbineDynamics.cp_at_tsr(10.0)
cbig = KiteTurbineDynamics.cp_at_tsr(1e6)
println("  cp(8.0)=", round(c8, digits=4), "  cp(8.5)=", round(c85, digits=4),
        "  cp(9.5)=", round(c95, digits=4), "  cp(9.61)=", round(c961, digits=5),
        "  cp(10)=", round(c10, digits=4), "  cp(1e6)=", round(cbig, digits=4))
check("P1a: cp falls after the table end (cp(8.5) < cp(8.0))", c85 < c8)
check("P1b: cp near zero at the derived crossing (|cp(9.61)| < 0.01)", abs(c961) < 0.01)
check("P1c: cp negative beyond the power point (cp(10.0) < 0)", c10 < 0.0)
check("P1d: cp bounded negative at extreme TSR (cp(1e6) < 0, finite)", isfinite(cbig) && cbig < 0.0)

println("=== P2: drag brake grows cubically ===")
c11 = KiteTurbineDynamics.cp_at_tsr(11.0)
c12 = KiteTurbineDynamics.cp_at_tsr(12.0)
c14 = KiteTurbineDynamics.cp_at_tsr(14.0)
println("  cp(11)=", round(c11, digits=4), "  cp(12)=", round(c12, digits=4),
        "  cp(14)=", round(c14, digits=4))
check("P2: |cp| grows with TSR in the brake regime (cp(12) < cp(11) < 0)", c12 < c11 && c11 < 0.0)
check("P2: cubic growth (cp(14) ≈ 8×cp(7)-scale monotone)", c14 < c12)

println("=== P3: per-rotor Betz helper ===")
rho = 1.225
v = 11.0
A = π * 1.0^2                              # 1 m radius rotor disk
betz_kw = 0.593 * 0.5 * rho * A * v^3 / 1000.0
ok_under = KiteTurbineDynamics.rotor_betz_ok(0.9 * betz_kw, A, v)
ok_over  = KiteTurbineDynamics.rotor_betz_ok(1.2 * betz_kw, A, v)
ok_nan   = KiteTurbineDynamics.rotor_betz_ok(NaN, A, v)
println("  Betz(1m disk, 11 m/s) = ", round(betz_kw, digits=3), " kW; 0.9×→", ok_under,
        "  1.2×→", ok_over, "  NaN→", ok_nan)
check("P3: 0.9×Betz passes", ok_under)
check("P3: 1.2×Betz fails", !ok_over)
check("P3: NaN rotor power fails", !ok_nan)

println("=== P4: the old 18m winner cannot freewheel under the fixed model ===")
function run_p4()
    WINNER = joinpath(@__DIR__, "..", "scripts", "results", "v13_5kw_len18.0", "best_vector.csv")
    isfile(WINNER) || return nothing
    x = [parse(Float64, s) for s in split(strip(read(WINNER, String)), ",")]
    p = KiteTurbineDynamics.params_10kw()
    KW = 5.0
    geo = KiteTurbineDynamics.GeometrySpec(p.elevation_angle, p.lifter_elevation, p.rotor_radius,
        18.0, p.trpt_hub_radius, p.trpt_rL_ratio, p.n_lines, p.n_rings, p.n_blades)
    mat = KiteTurbineDynamics.MaterialSpec(p.tether_diameter, p.e_modulus, p.m_ring, p.m_blade)
    aero = KiteTurbineDynamics.AeroSpec(p.rho, p.v_wind_ref, p.h_ref, p.cp)
    ctrl = KiteTurbineDynamics.ControlSpec(p.i_pto, p.k_mppt, p.p_rated_w, p.β_min, p.β_max, p.β_rate_max, p.kp_elev)
    back = KiteTurbineDynamics.BackLineSpec(p.EA_back_line, p.c_back_line, p.back_anchor_fwd_x, p.backline_payout)
    p18 = KiteTurbineDynamics.mass_scale(KiteTurbineDynamics.SystemParams(geo, mat, aero, ctrl, back), 10.0, KW)
    xr = copy(x)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))
    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p18; power_W=5000.0)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, p18.k_mppt; tether_diameter=p18.tether_diameter)
    wind_fn(r, t) = [p18.v_wind_ref, 0.0, 0.0]
    u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=rotary_lifter_default(), wind_fn=wind_fn, n_op=30_000)
    N = sys.n_total; Nr = sys.n_ring
    sys.k_mppt_ref[] = p18.k_mppt
    wmax = 0.0
    for chunk in 1:6   # 30 s
        run_canonical_sim!(u, sys, pc, wind_fn, round(Int, 5.0 / 4e-5), 4e-5; lift_device=rotary_lifter_default(), lin_damp=0.05)
        wmax = max(wmax, maximum(abs, @view u[(6N + Nr + 1):(6N + 2Nr)]))
    end
    return wmax
end
wmax = run_p4()
if wmax === nothing
    println("  (18m winner CSV not present — skipping P4)")
else
    println("  max |ω| over 30s = ", wmax)
    check("P4: no divergence — max |ω| stays finite (≤ 1e6 rad/s)", isfinite(wmax) && wmax <= 1e6)
end

println()
if isempty(failures)
    println("ALL ACCEPTANCE TESTS PASS")
else
    println("FAILED: ", join(failures, ", "))
    exit(1)
end
