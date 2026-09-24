using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))
const SEED_LR15_FROZEN = [2.4, 0.5751086853804245, 1.5, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]
function main()
    for d in (0.00025, 0.0005)
        p = override_params(params_daisy(); tether_diameter=d)
        dec = design_from_vector_v10(
            SEED_LR15_FROZEN,
            PROFILE_ELLIPTICAL,
            p;
            power_W=5000.0,
            cylinder_cone=true,
            rotor_count_mode=true,
            power_split=0.6,
            cone_slope_deg=22.0,
            rotor_spacing_frac=0.8,
            blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        )
        cfg = KiteTurbineDynamics.ObjectiveConfig(;
            power_W=5000.0,
            v_rated=11.0,
            p_floor_kw=5.0,
            fos_target=2.5,
            fos_hard=2.5,
            min_wall_m=2e-3,
            t_over_D=0.055,
            rotor_count_mode=true,
            power_split=0.6,
            blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        )
        sizing = KiteTurbineDynamics.size_beams_closed_form(dec, p, cfg)
        sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
            dec,
            1.0,
            K_MPPT_5KW_HONEST;
            tether_diameter=p.tether_diameter,
            base_params=p,
            min_wall_m=2e-3,
            beam_sizing=sizing,
        )
        lift = KiteTurbineDynamics.sized_lifter_for(
            sys, pc; margin=1.5, v_ref=11.0, const_tension=true
        )
        wfn(r, t) = [p.v_wind_ref, 0.0, 0.0]
        ω=12.983466
        try
            Fa = design_axial_preload(sys, pc, lift, u0; omega_eq=ω, wind_fn=wfn)
            EA = pc.e_modulus*pi*(pc.tether_diameter/2)^2
            strain = (Fa[end]/pc.n_lines)/EA
            @printf(
                "d=%.5f EA=%.0f F_top=%.1f T/line=%.1f -> strain=%.4f (break at %.3f)\n",
                d,
                EA,
                Fa[end],
                Fa[end]/pc.n_lines,
                strain,
                ROPE_BREAK_STRAIN
            )
        catch e
            @printf("d=%.5f REFUSED: %s\n", d, sprint(showerror, e)[1:min(end, 90)])
        end
    end
end
main()
