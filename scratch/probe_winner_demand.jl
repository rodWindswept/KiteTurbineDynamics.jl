# scratch/probe_winner_demand.jl
#
# 2026-09-19.  Does the equilibrium realisability correction actually fire on the
# v13 campaign winner, and does it move the equilibrium tension?  Compares
# corrections=0 vs 2 and prints the worst-segment demand measured AT the
# equilibrium (the quantity the correction gates on).

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0; const L18 = 18.8
const WINNER = joinpath(@__DIR__, "..", "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount", "best_vector.csv")

function build_winner()
    p = params_at_length(params_daisy(), L18, KW)
    xv = [parse(Float64, s) for s in split(strip(read(WINNER, String)), ",")]
    xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
    xv[10] = Float64(round(Int, clamp(xv[10], 1, 3)))
    bf = BLOCKING_WIND_FACTOR_5KW
    dec = design_from_vector_v10(xv, PROFILE_ELLIPTICAL, p; power_W=KW * 1000.0,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=bf)
    cfg = KiteTurbineDynamics.ObjectiveConfig(;
        power_W=KW * 1000.0, v_rated=11.0, p_floor_kw=KW, fos_target=2.5,
        fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055, rotor_count_mode=true,
        power_split=0.6, blocking_factor=bf)
    sizing = KiteTurbineDynamics.size_beams_closed_form(dec, p, cfg)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3,
        beam_sizing=sizing)
    return p, xv, sys, u0, pc
end

function main()
    for ncorr in (0, 2)
        p, xv, sys, u0, pc = build_winner()
        wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
        lift = lift_for(sys, pc)
        N, Nr = sys.n_total, sys.n_ring
        u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
            lift_device=lift, wind_fn=wind_fn,
            polish_realisability_max_corrections=ncorr)
        ω = u[6N + Nr + 1]
        τ_eq = sys.k_mppt_ref[] * ω^2
        dem = KiteTurbineDynamics._trpt_equilibrium_demand(sys, pc, u, τ_eq, ω, wind_fn)
        ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wind_fn, lift)
        tr = KiteTurbineDynamics.twist_collapse_check(u, sys)
        @printf("\n=== corrections=%d  ω=%.4f  τ_eq=%.2f ===\n", ncorr, ω, τ_eq)
        @printf("  demand AT EQUILIBRIUM = %.4f   (target %.4f)   crossed=%s ratio=%.4f\n",
            dem, 1.0 / KiteTurbineDynamics.TRPT_REALISABILITY_TENSION_MARGIN, tr.crossed, tr.max_ratio)
        for s in 1:(Nr - 1)
            @printf("    seg %d  T=%.2f N  twist=%.2f deg\n", s,
                ef.segment_tension[s], ef.segment_twist_deg[s])
        end
    end
    println("=== done ===")
end

main()
