using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const L18 = 18.8
const SEED_LR15_FROZEN = [2.4, 0.5751086853804245, 1.5, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]

println("Testing e_modulus sweep with standard diameter (0.003 m base):")
for E_gpa in [0.5, 0.8, 1.0, 1.2, 1.5, 2.0, 3.0, 5.0]
    p_mod = override_params(params_daisy(); e_modulus=E_gpa * 1e9)
    p = params_at_length(p_mod, L18, KW)
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
            sys, pc, lift, u0; omega_eq=13.452, wind_fn=wind_fn
        )
        can_settle = true
    catch e
        err_msg = sprint(showerror, e)
    end

    EA = pc.e_modulus * pi * (pc.tether_diameter / 2)^2
    T_break = EA * KiteTurbineDynamics.ROPE_BREAK_STRAIN
    @printf(
        "E = %4.1f GPa | EA = %7.1f N | T_break = %6.1f N/line | can_preload = %s | err = %s\n",
        E_gpa,
        EA,
        T_break,
        can_settle ? "YES" : "NO ",
        err_msg[1:min(end, 40)]
    )
end
