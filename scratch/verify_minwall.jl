# scratch/verify_minwall.jl — verify the min_wall_m swept knob + FoS alignment.
using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))
using KiteTurbineDynamics
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const L = 18.8
const KW = 5.0

function params_at_length(L)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

x = [0.03, 0.027724379068369474, 0.7880304550607653, 0.9836099040123638, 4.32,
     0.8626630280706367, 2.799241474826894, 3.0, 0.6978820732360798, 1.3831182070079888,
     19.94688644098879, 6.690368026101, 0.7008150303267114, 1.0]
x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
x[10] = Float64(round(Int, clamp(x[10], 1, 3)))

p_base = params_at_length(L)
dec = design_from_vector_v10(x, PROFILE_ELLIPTICAL, p_base; power_W=KW * 1000.0,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
    rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)

function build(min_wall)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p_base.tether_diameter, base_params=p_base, min_wall_m=min_wall)
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    return sys, u0, pc
end

sys2, u0_2, pc_2 = build(2e-3)
sys15, u0, pc = build(1.5e-3)
println("min_wall_m 2mm   = ", sys2.min_wall_m[])
println("min_wall_m 1.5mm = ", sys15.min_wall_m[])
println("ring_mass_total 2mm   = ", round(sys2.ring_mass_total[], digits=4), " kg")
println("ring_mass_total 1.5mm = ", round(sys15.ring_mass_total[], digits=4), " kg")
@assert sys15.min_wall_m[] ≈ 1.5e-3
@assert sys15.ring_mass_total[] < sys2.ring_mass_total[]
println("mass drop OK: ", round(sys2.ring_mass_total[] - sys15.ring_mass_total[], digits=4), " kg")

# FoS alignment: settle + relax + capture_extended (exercises ring_element_analysis).
function ring_fos_of(sys, u0_, pc_, label)
    lift = sized_lifter_for(sys, pc_; margin=1.5, v_ref=11.0, const_tension=true)
    wf = (r, t) -> [11.0, 0.0, 0.0]
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc_)
    u = settle_to_operational_state(sys, copy(u0_), pc_, 60.0; lift_device=lift, wind_fn=wf, n_op=30_000)
    for _ in 1:2
        run_canonical_sim!(u, sys, pc_, wf, round(Int, 5.0 / dt), dt; lift_device=lift, lin_damp=0.05)
    end
    ef = KiteTurbineDynamics.capture_extended(u, sys, pc_, 10.0, wf, lift)
    println("ring_fos ($label) = ", round.(ef.ring_fos, digits=2))
    return ef.ring_fos
end
r2 = ring_fos_of(sys2, u0_2, pc_2, "2mm")
r15 = ring_fos_of(sys15, u0, pc, "1.5mm")
@assert all(isfinite.(r2)) && all(isfinite.(r15))
println("VERIFY OK")
