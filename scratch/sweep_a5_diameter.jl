using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const L18 = 18.8
const SEED_LR15_FROZEN = [2.4, 0.5751086853804245, 1.5, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]

println("Testing diameter sweep for A5:")
for d_test in
    [0.00016, 0.00020, 0.00025, 0.00030, 0.00040, 0.00050, 0.00060, 0.00080, 0.0010]
    p_thin = override_params(params_daisy(); tether_diameter=d_test)
    # Check if settle succeeds
    p = params_at_length(p_thin, L18, KW)
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

    can_settle = false
    err_msg = ""
    try
        F_ax = KiteTurbineDynamics.design_axial_preload(
            sys, pc, lift, u0; omega_eq=15.63, wind_fn=wind_fn
        )
        can_settle = true
    catch e
        err_msg = sprint(showerror, e)
    end

    EA = pc.e_modulus * pi * (pc.tether_diameter / 2)^2
    # If it can settle, what is design tension / EA?
    design_strain = can_settle ? (1250.0 / 6.0) / EA : NaN
    @printf(
        "d = %.5f (built %.5f) | EA = %7.1f N | can_preload = %s | design_strain = %.4f | err = %s\n",
        d_test,
        pc.tether_diameter,
        EA,
        can_settle ? "YES" : "NO ",
        design_strain,
        err_msg[1:min(end, 40)]
    )
end
