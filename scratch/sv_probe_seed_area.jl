# sv_probe_seed_area.jl — the campaign seed's rotor area at this revision.
# Mirrors test_physics_path_ode.jl's params_at_length + the settle_case_builders decode.
using KiteTurbineDynamics
const KTD = KiteTurbineDynamics
include(joinpath(dirname(@__DIR__), "scripts", "compute_seeds.jl"))  # only if run from test/

println("revision: ", read(`git -C $(dirname(@__DIR__)) rev-parse --short HEAD`, String))

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = KTD.GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius, L,
        p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = KTD.MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = KTD.AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = KTD.ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = KTD.BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, 5.0)
    return override_params(scaled; tether_length=L)
end

X = seed_genome(5.0)
P = params_at_length(18.8)
println("params: v_wind_ref=", P.v_wind_ref, "  h_ref=", P.h_ref)

dec = KTD.design_from_vector_v10(X, PROFILE_ELLIPTICAL, P;
    power_W=5000.0, cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)
sys, _u0, _pc = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=P.tether_diameter, base_params=P)

r = sys.rotor
A = pi * (r.radius^2 - r.blade_hub_radius^2)
println("seed rotor: r_out=", r.radius, "  r_in=", r.blade_hub_radius,
        "  span=", r.radius - r.blade_hub_radius)
println("seed raw annulus A = ", A)
