#!/usr/bin/env julia --project=.
# av_f3_warm_diag.jl — why does the warm path reject the winner?
#
# Replicates evaluate_windowed's entry chain for the F3 winner:
#   decode -> size_beams_closed_form -> (if omega_eq==0) the equilibrium scan.
# Prints every decisive internal so the warm rejection branch is named.
# Read-only: builds no CSV, runs no window (unless the guard passes).
#
# USAGE  scripts/ktd-julia scratch/av_f3_warm_diag.jl
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const RELAX_S = 10.0
const WINDOW_S = 40.0
const MIN_WALL_M = 2.0e-3
const LENGTH = 18.8

const REPO = dirname(@__DIR__)
const WINNER = joinpath(
    REPO, "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_bankderate2",
    "island_3", "best_vector.csv",
)

lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(
        p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades,
    )
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(
        p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev,
    )
    back = BackLineSpec(
        p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout,
    )
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

function main()
    h = try
        strip(read(`git rev-parse HEAD`, String))
    catch
        "unknown"
    end
    println("av_f3_warm_diag.jl | HEAD ", h)

    x = [parse(Float64, tok) for tok in split(strip(read(WINNER, String)), ",")]
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    println("xr = ", xr)

    p_base = params_at_length(LENGTH)
    println("p_base.k_mppt = ", p_base.k_mppt, "  (the evaluator cfg k = ", K_MPPT_5KW_HONEST, ")")

    cfg = ObjectiveConfig(;
        power_W=PW, v_rated=V_RATED,
        p_floor_kw=5.0, p_ceiling_kw=5.0,
        relax_s=RELAX_S, window_s=WINDOW_S,
        fos_target=2.5, fos_hard=2.5,
        power_stat=:tail5, penalize_ceiling=false,
        kickstart_s=0.0,
        k_mppt=K_MPPT_5KW_HONEST,
        tether_diameter=p_base.tether_diameter,
        rotor_count_mode=true,
        power_split=0.6,
        cone_slope_deg=22.0,
        rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        min_wall_m=MIN_WALL_M,
    )
    println("cfg.t_over_D = ", cfg.t_over_D)

    x_canon = KiteTurbineDynamics.canonical_v10(xr)
    result = KiteTurbineDynamics.design_from_vector_v10(
        x_canon, PROFILE_ELLIPTICAL, p_base;
        power_W=cfg.power_W, v_rated=cfg.v_rated,
        cylinder_cone=true,
        rotor_count_mode=cfg.rotor_count_mode,
        power_split=cfg.power_split,
        cone_slope_deg=cfg.cone_slope_deg,
        rotor_spacing_frac=cfg.rotor_spacing_frac,
        blocking_factor=cfg.blocking_factor,
        beam_t_over_D=cfg.t_over_D,
    )
    println("result.n_active = ", result.n_active, "  result.n_rings = ", result.n_rings)
    println("design: n_lines=", result.design.n_lines, " tether_length=", result.design.tether_length,
        " r_hub=", result.design.r_hub, " r_bottom=", result.design.r_bottom)
    println("radii = ", result.radii)
    println("zs    = ", result.zs)
    println("rotors:")
    for rot in result.rotors
        println("  ", rot)
    end

    sizing = KiteTurbineDynamics.size_beams_closed_form(result, p_base, cfg)
    println("\nsizing.omega_eq = ", sizing.omega_eq)
    println("sizing.Do_per_ring = ", sizing.Do_per_ring)
    println("sizing.fos_per_ring = ", sizing.fos_per_ring)

    rotors = result.rotors
    n_rings_tot = length(result.radii)
    n_lines = result.design.n_lines
    exp_params = KiteTurbineDynamics.expansion_params_from_rotors(rotors, n_rings_tot, n_lines)
    P_per_rotor = result.n_active > 0 ? cfg.power_W / result.n_active : cfg.power_W
    v_ref_rotor = isempty(rotors) ? cfg.v_rated : rotors[1].v_wind
    bank_ref = isempty(rotors) ? 0.0 : rotors[1].bank_angle_deg
    λ_eff = isempty(rotors) ? 1.0 : rotors[1].blade_scale
    k_mppt_eff = p_base.k_mppt * λ_eff^2
    p_scaled = override_params(p_base; k_mppt=k_mppt_eff)
    println("exp_params = ", exp_params)
    println("P_per_rotor = ", P_per_rotor, "  v_ref_rotor = ", v_ref_rotor,
        "  bank_ref = ", bank_ref, "  λ_eff = ", λ_eff)
    println("k_mppt_eff = p_base.k_mppt*λ² = ", k_mppt_eff)

    f_proj = KiteTurbineDynamics.BEM.projection_factor(bank_ref, π / 6)
    r0 = KiteTurbineDynamics.BEM.rotor_radius_for_power(
        P_per_rotor, v_ref_rotor, n_lines; f=f_proj,
    )
    println("f_proj = ", f_proj, "  r_hub_rotor (first iter) = ", r0)

    ω_solved, R_solved = KiteTurbineDynamics.solve_equilibrium_self_consistent(
        result.design, exp_params, p_scaled, n_lines, result.radii, result.zs;
        P_per_rotor=P_per_rotor, v_wind=cfg.v_rated, elev_rad=π / 6, bank_deg=bank_ref,
    )
    println("solve_equilibrium_self_consistent -> ω = ", ω_solved, "  R = ", R_solved)

    ω_only = KiteTurbineDynamics.solve_equilibrium_omega(
        result.design, exp_params, p_scaled, n_lines, result.radii, result.zs, r0;
        P_rated=P_per_rotor * (1 + length(exp_params)),
        v_wind=cfg.v_rated, elev_rad=π / 6, bank_deg=bank_ref,
    )
    println("solve_equilibrium_omega (first-iter r0, p_scaled) -> ", ω_only)

    # ── Replicate the scan to show WHERE the crossing fails ──────────────
    println("\n-- scan replication (r0 = ", r0, ") --")
    rho = p_base.rho
    elev_deg = 30.0
    ω_min = 1.0 * 2π / 60
    ω_max = 300.0 * 2π / 60
    ω_scan = exp.(range(log(ω_min), log(ω_max); length=30))
    thrust_per_ring = zeros(Float64, n_rings_tot)
    thrust_per_ring[1] = KiteTurbineDynamics.peak_hub_thrust(
        r0, π / 6; v=cfg.v_rated, CT=KiteTurbineDynamics.OPT_CT_RATED,
    )
    cumulative_thrust = cumsum(thrust_per_ring)
    P_net_k_eff = zeros(30)
    P_net_k_224 = zeros(30)
    for (j, ω) in enumerate(ω_scan)
        λ = clamp(ω * r0 / cfg.v_rated, 0.0, 12.0)
        cp = KiteTurbineDynamics.BEM.cp_bem(n_lines, λ)
        P_aero_hub = 0.5 * rho * cfg.v_rated^3 * π * r0^2 * cp * f_proj
        P_exp_net = 0.0
        for er in exp_params
            ri = er.ring_idx
            (ri > n_rings_tot || ri < 1) && continue
            r_nom = result.radii[ri]
            (r_nom <= 0.0 || !isfinite(r_nom)) && continue
            T_above = ri > 1 ? cumulative_thrust[ri - 1] / n_lines : 0.0
            try
                _, _, tau_net, _, _ = KiteTurbineDynamics.expansion_rotor_forces(
                    er, rho, cfg.v_rated, ω, elev_deg, r_nom, T_above, n_lines,
                )
                isfinite(tau_net) && (P_exp_net += tau_net * ω)
            catch
                continue
            end
        end
        P_aero_total = P_aero_hub + P_exp_net
        _, _, _, P_par = KiteTurbineDynamics.parasitic_drag_power(
            result.design, exp_params, p_scaled;
            omega=ω, n_lines=n_lines, radii=result.radii, zs=result.zs,
            v_wind=cfg.v_rated, elev_rad=π / 6,
        )
        P_net_k_eff[j] = P_aero_total - P_par - k_mppt_eff * ω^3
        P_net_k_224[j] = P_aero_total - P_par - 2.24 * ω^3
        @printf("  j=%2d ω=%7.3f  P_aero=%9.2f  P_par=%8.2f  P_net(k_eff=%6.3f)=%10.2f  P_net(k=2.24)=%10.2f\n",
            j, ω, P_aero_total, P_par, k_mppt_eff, P_net_k_eff[j], P_net_k_224[j])
    end
    function best_idx_of(P::Vector{Float64})
        b = 0
        for j in 1:length(P)
            P[j] >= 0.0 && (b = j)
        end
        return b
    end
    println("best_idx (k_eff)  = ", best_idx_of(P_net_k_eff), " of 30")
    println("best_idx (k=2.24) = ", best_idx_of(P_net_k_224), " of 30")

    # ── If the guard PASSED (omega_eq > 0), test the settle branch ───────
    if sizing.omega_eq > 0.0
        k_mppt = clamp(cfg.k_mppt, 0.01, 1e6)
        sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
            result, 1.0, k_mppt;
            tether_diameter=cfg.tether_diameter,
            base_params=p_base,
            min_wall_m=cfg.min_wall_m,
            beam_sizing=sizing,
        )
        function wf(pos, t)
            z = max(pos[3], 1.0)
            return [KiteTurbineDynamics.wind_at_altitude(p_base.v_wind_ref, p_base.h_ref, z), 0.0, 0.0]
        end
        lift_dev = lift_for(sys, pc)
        t0 = time()
        u_settled = KiteTurbineDynamics.settle_to_equilibrium(
            sys, u0, pc; wind_fn=wf, lift_device=lift_dev,
        )
        t_settle = time() - t0
        bad = any(isnan.(u_settled)) || any(isinf.(u_settled))
        @printf("settle_to_equilibrium: wall=%.2f s  any(NaN|Inf)=%s\n", t_settle, bad)
        if !bad
            @printf("  u_settled[6N+Nr+1] (ground ω after settle) = %.15f\n",
                u_settled[6 * sys.n_total + sys.n_ring + 1])
        end
    end
end

main()
