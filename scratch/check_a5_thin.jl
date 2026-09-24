using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const L18 = 18.8
const SEED_LR15_FROZEN = [2.4, 0.5751086853804245, 1.5, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]

p2 = override_params(params_daisy(); tether_diameter=0.00016)
p = params_at_length(p2, L18, KW)
k_mp = K_MPPT_5KW_HONEST
bf = BLOCKING_WIND_FACTOR_5KW
dec = design_from_vector_v10(
    SEED_LR15_FROZEN,
    PROFILE_ELLIPTICAL,
    p;
    power_W=KW * 1000.0,
    cylinder_cone=true,
    rotor_count_mode=true,
    power_split=0.6,
    cone_slope_deg=22.0,
    rotor_spacing_frac=0.8,
    blocking_factor=bf,
)
cfg_gate = KiteTurbineDynamics.ObjectiveConfig(;
    power_W=KW * 1000.0,
    v_rated=11.0,
    p_floor_kw=KW,
    fos_target=2.5,
    fos_hard=2.5,
    min_wall_m=2e-3,
    t_over_D=0.055,
    rotor_count_mode=true,
    power_split=0.6,
    blocking_factor=bf,
)
sizing = KiteTurbineDynamics.size_beams_closed_form(dec, p, cfg_gate)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
    dec,
    1.0,
    k_mp;
    tether_diameter=p.tether_diameter,
    base_params=p,
    min_wall_m=2e-3,
    beam_sizing=sizing,
)
lift = lift_for(sys, pc)
wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]

omega_eq = 15.63
τ_eq = sys.k_mppt_ref[] * omega_eq^2
d = KiteTurbineDynamics.lift_chain_design(
    sys,
    pc,
    lift,
    u0[(3 * (sys.rotor.node_id - 1) + 1):(3 * sys.rotor.node_id)];
    omega_eq=omega_eq,
)
F_top = d.T_top
F_top_bare = F_top
g_inc = pc.m_ring * 9.81 * sin(pc.elevation_angle)
F_ax = zeros(sys.n_ring - 1)
rebuild! = () -> begin
    F_ax[end] = F_top
    for i in (length(F_ax) - 1):-1:1
        F_ax[i] = F_ax[i + 1] + g_inc
    end
end
rebuild!()

target = 1.0 / 1.05
for iter in 1:12
    place = KiteTurbineDynamics.trpt_matched_place(
        sys, pc, F_ax, τ_eq, omega_eq, wind_fn; raise_on_unrealisable=false
    )
    worst = maximum(place.demand)
    cross = KiteTurbineDynamics.max_segment_cross_ratio(place, sys)
    @printf(
        "iter %2d: F_top=%.1f (%.2fx bare) | worst dem=%.4f (target %.4f) | cross=%.4f (target %.4f)\n",
        iter,
        F_top,
        F_top/F_top_bare,
        worst,
        target,
        cross,
        target
    )
    if worst <= target * (1.0 + 1e-9) && cross <= target * (1.0 + 1e-9)
        println("  -> CLEARED!")
        break
    end
    global F_top *= max(worst, cross) * 1.05
    rebuild!()
    if F_top > 1.5 * F_top_bare
        println("  -> HIT CAP 1.5x! (F_top = ", F_top, ", cap = ", 1.5*F_top_bare, ")")
        break
    end
end
