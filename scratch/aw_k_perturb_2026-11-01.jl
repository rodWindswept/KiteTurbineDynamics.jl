# scratch/aw_k_perturb_2026-11-01.jl — aero-worker, 2026-11-01
#
# The two-point k structural re-eval (FEEDBACKBOT3 routing E, Phase 2).
# Winner: bankderate2 island-3 genome (NR-005, fitness 27.3635).
# Points: k = 2.24 (archive basis), 8.4 and 8.9 (the measured k* bracket).
#
# For each k: build the campaign machine, settle, run 200 s, sample every 5 s.
# Record the hub speed, the shaft power, the twist ratio and the minimum
# airborne ring FoS at t = 200 s. Then a static structural pass at the
# MEASURED hub speed gives min_torsional_fos (ungated, RF-20) and per-ring Do.
# Per-ring blade chord c and the air density rho print beside them.
#
# USAGE: scripts/ktd-julia scratch/aw_k_perturb_2026-11-01.jl

using KiteTurbineDynamics, Printf, LinearAlgebra
const KTD = KiteTurbineDynamics
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const LENGTH = 18.8
const MIN_WALL_M = 2.0e-3
const OUT = "scratch/aw_k_perturb_2026-11-01.csv"
const VEC = joinpath(
    @__DIR__, "..", "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate2", "best_vector.csv",
)
const KS = (K_MPPT_5KW_HONEST, 8.4, 8.9)

lift_for(sys, p) = KTD.sized_lifter_for(
    sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(
        p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades,
    )
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

function cfg_for(k::Float64, p)
    return KTD.ObjectiveConfig(;
        power_W=PW, v_rated=V_RATED,
        p_floor_kw=5.0, p_ceiling_kw=5.0,
        relax_s=10.0, window_s=40.0,
        fos_target=2.5, fos_hard=2.5,
        power_stat=:tail5, penalize_ceiling=false,
        kickstart_s=0.0,
        k_mppt=k,
        tether_diameter=p.tether_diameter,
        rotor_count_mode=true,
        power_split=0.6,
        cone_slope_deg=22.0,
        rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        min_wall_m=MIN_WALL_M,
    )
end

function main()
    git = strip(read(`git rev-parse --short HEAD`, String))
    println("=== aw_k_perturb_2026-11-01.jl   git=", git, " ===")
    p = params_at_length(LENGTH)
    x = [parse(Float64, s) for s in split(strip(read(VEC, String)), ",")]
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    println("  genome = ", xr)
    println("  size(x) = ", length(xr), "   K_MPPT_5KW_HONEST = ", K_MPPT_5KW_HONEST,
        "   v_wind_ref = ", p.v_wind_ref, "   rho = ", p.rho)

    open(OUT, "w") do io
        println(io, "k,t_s,omega_hub,omega_gnd,P_kw,twist_ratio,fos_min_ring")
    end

    summaries = Any[]
    for k in KS
        println("\n", "="^70)
        @printf("  k = %.2f\n", k)
        cfg = cfg_for(k, p)
        dec = KTD.design_from_vector_v10(
            KTD.canonical_v10(xr), PROFILE_ELLIPTICAL, p;
            power_W=cfg.power_W, v_rated=cfg.v_rated, cylinder_cone=true,
            rotor_count_mode=cfg.rotor_count_mode, power_split=cfg.power_split,
            cone_slope_deg=cfg.cone_slope_deg, rotor_spacing_frac=cfg.rotor_spacing_frac,
            blocking_factor=cfg.blocking_factor, beam_t_over_D=cfg.t_over_D,
        )
        sizing = KTD.size_beams_closed_form(dec, p, cfg)
        kk = clamp(k, 0.01, KTD.K_MPPT_MAX)
        sys, u0, pc = KTD.build_system_from_v10(
            dec, 1.0, kk;
            tether_diameter=cfg.tether_diameter, base_params=p,
            min_wall_m=cfg.min_wall_m, beam_sizing=sizing,
        )
        dt = KTD.stable_dt_for_system(sys, pc)
        lift_dev = lift_for(sys, pc)
        wf = (pos, t) -> [KTD.wind_at_altitude(p.v_wind_ref, p.h_ref, max(pos[3], 1.0)), 0.0, 0.0]
        N, Nr = sys.n_total, sys.n_ring
        @printf("  machine: n_lines=%d rings=%d n_active=%d dt=%.3e s  m_air=%.3f kg\n",
            dec.design.n_lines, Nr, dec.n_active, dt, KTD.expansion_airborne_mass(sys, pc))

        t0 = time()
        u = KTD.settle_to_operational_state(
            sys, copy(u0), pc, 60.0; wind_fn=wf, lift_device=lift_dev)
        @printf("  settle wall %.1f s   omega_settle(gnd) %.6f\n", time() - t0, u[6N + Nr + 1])

        steps = round(Int, 200.0 / dt)
        every = max(1, round(Int, 5.0 / dt))
        rows = NamedTuple{(:t, :wh, :wg, :P, :tw, :fos),Tuple{Float64,Float64,Float64,Float64,Float64,Float64}}[]
        cb = function (uc, tc, s)
            s % every == 0 || return nothing
            ef = KTD.capture_extended(uc, sys, pc, tc, wf, lift_dev; brake_engaged=sys.brake_engaged[])
            fok, _ = KTD.min_airborne_fos(ef.ring_fos)
            tr = KTD.twist_collapse_check(uc, sys)
            row = (t=tc, wh=uc[6N + Nr + Nr], wg=uc[6N + Nr + 1], P=ef.base.P_kw,
                   tw=tr.max_ratio, fos=fok)
            push!(rows, row)
            open(OUT, "a") do io
                @printf(io, "%.2f,%.1f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
                    k, row.t, row.wh, row.wg, row.P, row.tw, row.fos)
            end
            return nothing
        end
        t1 = time()
        KTD.run_canonical_sim!(
            u, sys, pc, wf, steps, dt;
            lift_device=lift_dev, lin_damp=0.05, spoke=nothing,
            callback=cb, breaks_enabled=true, breaks_arm_s=10.0,
        )
        @printf("  run wall %.1f s   samples %d   any_broken=%s\n",
            time() - t1, length(rows), sys.any_broken[])

        last = rows[end]
        P_end = sum(r.P for r in rows[(end - 4):end]) / 5
        wh_end = last.wh
        wg_end = last.wg
        tau = P_end * 1000.0 / wh_end

        # the static structural pass at the MEASURED speed (ungated, RF-20)
        sp = KTD.structural_pass_v10(
            xr, PROFILE_ELLIPTICAL, p, cfg; omega_rotor=wh_end, P_rated=P_end * 1000.0)

        println("  --- t = 200 s ---")
        @printf("  omega_hub %.6f  omega_gnd %.6f  P_kw %.6f  tau %.3f N m  twist %.6f  ringFoS %.4f\n",
            wh_end, wg_end, P_end, tau, last.tw, last.fos)
        @printf("  structural: valid=%s reason=%s min_torsional_fos=%.6f  ungated=%s\n",
            sp.valid, sp.reason, sp.min_torsional_fos, sp.torsion_ungated)
        @printf("  Do_per_ring (ground-first) = %s\n",
            join([@sprintf("%.5f", d) for d in sp.Do_per_ring], ", "))
        @printf("  fos_per_ring = %s\n",
            join([@sprintf("%.4f", f) for f in sp.fos_per_ring], ", "))

        # per-ring blade chord c and rho (the aero inputs at each rotor ring)
        radii = KTD.ring_radii(dec.design)
        chords = Float64[]
        for rot in dec.rotors
            push!(chords, rot.blade_chord)
        end
        @printf("  radii = %s\n", join([@sprintf("%.4f", r) for r in radii], ", "))
        @printf("  blade chord c per rotor = %s   rho = %.4f kg/m3\n",
            join([@sprintf("%.5f", c) for c in chords], ", "), p.rho)
        @printf("  OPT_RHO_CFRP = %.1f kg/m3   OPT_E_CFRP = %.3e Pa\n",
            KTD.OPT_RHO_CFRP, KTD.OPT_E_CFRP)

        push!(summaries, (k=k, wh=wh_end, wg=wg_end, P=P_end, tau=tau,
                          tw=last.tw, fos=last.fos, mfos=sp.min_torsional_fos,
                          Do=copy(sp.Do_per_ring), chords=copy(chords)))
    end

    println("\n", "="^70)
    println("  SUMMARY (t = 200 s)")
    @printf("  %6s %12s %12s %14s %12s %12s %12s\n",
        "k", "omega_hub", "omega_gnd", "P_kW", "tau_Nm", "twist", "min_tors_FoS")
    for s in summaries
        @printf("  %6.2f %12.6f %12.6f %14.6f %12.3f %12.6f %12.6f\n",
            s.k, s.wh, s.wg, s.P, s.tau, s.tw, s.mfos)
    end
    if length(summaries) >= 3
        a = summaries[2]; b = summaries[3]     # the 8.4 -> 8.9 bracket
        dk = b.k - a.k
        @printf("\n  two-point bracket 8.4 -> 8.9 (dk = %.2f):\n", dk)
        @printf("  dP/dk    = %+.6f kW per k unit   (%+.4f %% per k unit of P)\n",
            (b.P - a.P) / dk, 100 * (b.P - a.P) / dk / a.P)
        @printf("  dtau/dk  = %+.6f N m per k unit  (%+.4f %% per k unit of tau)\n",
            (b.tau - a.tau) / dk, 100 * (b.tau - a.tau) / dk / a.tau)
        @printf("  d(min_torsional_fos)/dk = %+.6f per k unit\n",
            (b.mfos - a.mfos) / dk)
        @printf("  bracket means: P %.6f kW  tau %.3f N m  min_torsional_fos %.6f\n",
            (a.P + b.P) / 2, (a.tau + b.tau) / 2, (a.mfos + b.mfos) / 2)
    end
    println("\n  samples -> ", OUT)
end

main()
