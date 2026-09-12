#!/usr/bin/env julia --project=.
#= test_jtheta_no_reversal.jl — R8 acceptance regression (2026-09-10).

The spurious torsional spring `torques -= J_rotor·alpha` in ring_forces.jl used
the ring TWIST ANGLE as an angular acceleration, anchoring every rotor ring at
θ=0 and braking multi-rotor machines to reversal (DECISIONS [2026-08-25]).  The
fix moved expansion-rotor blade mass into the ring's rotary inertia
(`dω/dt = τ/(I_z + J_rotor)`).  The suite only ever checked the J VALUE, never
that a 2-rotor machine stays FORWARD — this pins it.

A 2-rotor seed is settled and run for 20 s; the ground-ring and hub-ring ω must
stay strictly positive (no reversal), and the machine must deliver power.

Standalone acceptance file (20 s ODE window) — listed in
test/acceptance_runtests.jl.
=#

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const L = 18.8
const WINDOW_S = 20.0

failures = String[]
function check(name::String, cond::Bool)
    println((cond ? "  ✅ " : "  ❌ "), name)
    cond || push!(failures, name)
end

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return override_params(mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW);
                           tether_length=L)
end

p = params_at_length(L)
x = seed_genome(KW)
x[6] = 2.0                       # 2 rotors: hub + 1 expansion (the J·θ case)
dec = design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=PW, v_rated=V_RATED,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8,
    blocking_factor=BLOCKING_WIND_FACTOR_5KW)
check("decode: 2 active rotors", dec.n_active == 2)

cfg = ObjectiveConfig(; power_W=PW, v_rated=V_RATED, p_floor_kw=5.0,
    fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
    rotor_count_mode=true, power_split=0.6,
    blocking_factor=BLOCKING_WIND_FACTOR_5KW)
sizing = size_beams_closed_form(dec, p, cfg)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3,
    beam_sizing=sizing)
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=V_RATED, const_tension=true)
wf = (r, t) -> [V_RATED * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]

dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
    lift_device=lift, wind_fn=wf, n_op=30_000)
check("settle: reached a positive operating point",
      u !== nothing && u[6 * sys.n_total + sys.n_ring + 1] > 0.0)

N = sys.n_total
Nr = sys.n_ring
n_steps = round(Int, WINDOW_S / dt)
chunk = round(Int, 1.0 / dt)          # sample every 1 s
ω_gnd_min = Ref(Inf)
ω_hub_min = Ref(Inf)
n_chunks = div(n_steps, chunk)
for _ in 1:n_chunks
    run_canonical_sim!(u, sys, pc, wf, chunk, dt; lift_device=lift, lin_damp=0.05)
    ω_gnd = u[6N + Nr + 1]
    ω_hub = u[6N + Nr + Nr]
    ω_gnd_min[] = min(ω_gnd_min[], ω_gnd)
    ω_hub_min[] = min(ω_hub_min[], ω_hub)
end

@printf("  ω_gnd: min=%.3f  final=%.3f rad/s\n", ω_gnd_min[], u[6N + Nr + 1])
@printf("  ω_hub: min=%.3f  final=%.3f rad/s\n", ω_hub_min[], u[6N + Nr + Nr])

check("no reversal: ground-ring ω stays > 0 over 20 s", ω_gnd_min[] > 0.0)
check("no reversal: hub-ring ω stays > 0 over 20 s", ω_hub_min[] > 0.0)
check("still turning forward at 20 s", u[6N + Nr + 1] > 0.0)

ef = KiteTurbineDynamics.capture_extended(u, sys, pc, WINDOW_S, wf, lift)
@printf("  P_mean=%.2f kW  FoS_min=%.2f\n", ef.base.P_kw, minimum(ef.ring_fos))
check("delivers power (P_mean > 0)", ef.base.P_kw > 0.0)

println()
if isempty(failures)
    println("ALL J·θ REGRESSION TESTS PASS")
else
    println("FAILED: ", join(failures, ", "))
    error("FAILED: " * join(failures, ", "))
end
