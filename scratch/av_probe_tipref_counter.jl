#!/usr/bin/env julia --project=.
# av_probe_tipref_counter.jl — aero-validator counter-read (2026-10-11) of the
# tip-radius / swept-area basis behind NR-031, prompted by science-validator's
# sv_probe_winner_areas.jl.  Evidence receipt for NR-032 and NR-033; committed
# with the re-base follow-up.  The run log travels beside it as
# av_probe_tipref_counter.log.
#
# STATIC: rebuild the winner through the evaluator's own decode -> size -> build
# chain (objective_evaluator.jl:716-729, 751, 759-767) and print the main-rotor
# radii, the candidate areas, the code's own Betz-basis functions, and the
# ceiling candidates at the window-mean state.
# LIVE: repeat the recorded cold re-eval (evaluate_windowed :cold; parity
# target scratch/sv_p0_winner_reeval.txt fields) with a trace tap that samples
# at the evaluator's own window cadence (1 Hz over t > 10 s): delivered P_kw
# (tau_gen * omega_gnd — the NR-008 quantity) and the model's hub aero power in
# both variants (live-elevation, as ring_forces charges it; design-elevation,
# as capture_frame reports it), plus every-step fine means.
using KiteTurbineDynamics
using LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const WINDOW_S = 40.0
const RELAX_S = 10.0
const MIN_WALL_M = 2.0e-3
const LENGTH = 18.8

const REPO = dirname(@__DIR__)
const WINNER = joinpath(REPO, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate2", "island_3", "best_vector.csv")

const EXPECTED = Dict{Symbol,Float64}(
    :fitness => 27.3635412663488,
    :P_mean => 5.3087794439367935,
    :P_end => 5.314113662272673,
    :ω_eq => 10.169820334285198,
)

lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

function params_at_length(L::Float64)
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

function main()
    x = [parse(Float64, tok) for tok in split(strip(read(WINNER, String)), ",")]
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))

    p_base = params_at_length(LENGTH)
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

    # ── STATIC: rebuild through the evaluator chain ──
    xc = KiteTurbineDynamics.canonical_v10(xr)
    result = KiteTurbineDynamics.design_from_vector_v10(
        xc, PROFILE_ELLIPTICAL, p_base;
        power_W=cfg.power_W, v_rated=cfg.v_rated,
        cylinder_cone=true, rotor_count_mode=cfg.rotor_count_mode,
        power_split=cfg.power_split, cone_slope_deg=cfg.cone_slope_deg,
        rotor_spacing_frac=cfg.rotor_spacing_frac,
        blocking_factor=cfg.blocking_factor, beam_t_over_D=cfg.t_over_D,
    )
    (; design, rotors) = result
    hub = rotors[end]
    println("== static: decode ==")
    println("r_hub=", design.r_hub, "  r_bottom=", design.r_bottom, "  n_active=", result.n_active)
    println("hub rotor: blade_tip_offset=", hub.blade_tip_radius,
        "  blade_hub_offset=", hub.blade_hub_radius, "  blade_scale=", hub.blade_scale)
    span = hub.blade_tip_radius - hub.blade_hub_radius
    println("span = blade_tip - blade_hub = ", span)
    println("tip/span = ", hub.blade_tip_radius / span, "   hub/span = ", hub.blade_hub_radius / span)

    sizing = KiteTurbineDynamics.size_beams_closed_form(result, p_base, cfg)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
        result, 1.0, cfg.k_mppt;
        tether_diameter=cfg.tether_diameter,
        base_params=p_base,
        min_wall_m=cfg.min_wall_m,
        beam_sizing=sizing,
    )
    R_main = sys.rotor.radius
    r_in = sys.rotor.blade_hub_radius
    println("\n== static: built system ==")
    println("sys.rotor.radius (r_out)   = ", R_main)
    println("sys.rotor.blade_hub_radius = ", r_in)
    println("bank_angle_deg=", sys.rotor.bank_angle_deg, "  wind_factor=", sys.rotor.wind_factor)
    println("check r_hub+tip_offset = ", design.r_hub + hub.blade_tip_radius,
        "   |diff| vs r_out = ", abs(design.r_hub + hub.blade_tip_radius - R_main))
    println("check r_hub+hub_offset = ", design.r_hub + hub.blade_hub_radius,
        "   |diff| vs r_in = ", abs(max(design.r_hub + hub.blade_hub_radius, 0.0) - r_in))
    r_ring_unfold = 0.3 * R_main + 0.7 * r_in
    println("un-fold r_ring = 0.3*r_out + 0.7*r_in = ", r_ring_unfold,
        "   |diff| vs r_hub = ", abs(r_ring_unfold - design.r_hub))

    A_raw = KiteTurbineDynamics.main_rotor_swept_area(sys)
    A_bank = KiteTurbineDynamics.main_rotor_bank_projected_area(sys)
    A_zn = KiteTurbineDynamics.betz_wind_normal_area(sys, p_base)
    A_zy = A_raw * cos(p_base.elevation_angle)
    A_hubbot = π * (design.r_hub^2 - design.r_bottom^2)
    A_prim = KiteTurbineDynamics.BEM.annulus_area(design.r_hub, span; bank_deg=sys.rotor.bank_angle_deg)
    println("\n== static: areas ==")
    println("A_raw  (main_rotor_swept_area)         = ", A_raw)
    println("A_bank (main_rotor_bank_projected_area)= ", A_bank)
    println("A_zn   (betz_wind_normal_area)         = ", A_zn)
    println("A_zy   (A_raw * cos30, cross-check)    = ", A_zy)
    println("A_hub_bot (pi(r_hub^2 - r_bot^2))      = ", A_hubbot)
    println("annulus_area(r_hub, span; bank)        = ", A_prim,
        "   |diff| vs A_bank = ", abs(A_prim - A_bank))
    println("ratios: A_bank/A_raw = ", A_bank / A_raw, "   A_zy/A_zn = ", A_zy / A_zn)

    # ── window-mean state (NR-029/030, signed) ──
    w_gnd = 13.380259861740395
    w_hub = 13.380152462101652
    v_q = 11.01
    rho = p_base.rho
    println("\n== lambda and cp at the window mean (v=", v_q, ") ==")
    println("  tip, hub w: lam=", w_hub * R_main / v_q, "  cp=", cp_at_tsr(w_hub * R_main / v_q))
    println("  tip, gnd w: lam=", w_gnd * R_main / v_q, "  cp=", cp_at_tsr(w_gnd * R_main / v_q))
    println("  ring, hub w: lam=", w_hub * design.r_hub / v_q, "  cp=", cp_at_tsr(w_hub * design.r_hub / v_q))
    println("  ring, gnd w: lam=", w_gnd * design.r_hub / v_q, "  cp=", cp_at_tsr(w_gnd * design.r_hub / v_q))
    lam_tip = w_hub * R_main / v_q
    lam_ring = w_hub * design.r_hub / v_q
    println("cp_bem(3, lam_tip) = ", KiteTurbineDynamics.BEM.cp_bem(3, lam_tip),
        "   |diff| vs cp_at_tsr = ", abs(KiteTurbineDynamics.BEM.cp_bem(3, lam_tip) - cp_at_tsr(lam_tip)))

    proj = cos(π / 6)^2.65 * cosd(sys.rotor.bank_angle_deg)^2.65
    println("\n== hub aero power formula at the window mean ==")
    println("projection = cos30^2.65 * cosd(bank)^2.65 = ", proj)
    for (nm, lam) in (("tip ref", lam_tip), ("ring ref", lam_ring))
        P = 0.5 * rho * v_q^3 * A_raw * cp_at_tsr(lam) * proj
        println("  P_aero(", nm, ", A_raw) = ", P / 1000, " kW")
    end
    println("  P_mean recorded (NR-008) = 5.3087794439367935 kW")

    # ── ceilings at the window mean wind ──
    P_del = 5.3087794439367935
    half(A) = 0.5 * rho * A * v_q^3 / 1000.0
    println("\n== Betz ceiling candidates (kW) ==")
    println("  half*rho*A*v3: A_raw=", half(A_raw), "  A_zn=", half(A_zn),
        "  A_zy=", half(A_zy), "  A_hubbot=", half(A_hubbot))
    println("  code form 0.593*half(A_zn)              = ", 0.593 * half(A_zn),
        "   delivered share = ", P_del / (0.593 * half(A_zn)))
    println("  code form (16/27)*half(A_zn)            = ", (16 / 27) * half(A_zn),
        "   delivered share = ", P_del / ((16 / 27) * half(A_zn)))
    println("  SV form   (16/27)*half(A_raw)*cos^3(30) = ", (16 / 27) * half(A_raw) * cos(π / 6)^3,
        "   delivered share = ", P_del / ((16 / 27) * half(A_raw) * cos(π / 6)^3))
    println("  A_zy form (16/27)*half(A_zy)            = ", (16 / 27) * half(A_zy))
    println("  register form (16/27)*half(A_hubbot)*cos^3(30) = ",
        (16 / 27) * half(A_hubbot) * cos(π / 6)^3)
    println("  register arithmetic (A=63.9 rounded)   = ",
        (16 / 27) * (0.5 * rho * 63.9 * v_q^3 / 1000.0) * cos(π / 6)^3)
    println("  system coeff on A_raw = ", P_del / half(A_raw), "   on A_zn = ", P_del / half(A_zn))

    # ── LIVE run ──
    println("\n== live run (cold re-eval + window tap) ==")
    S = (; n=Ref(0), Pk=Ref(0.0), PaF=Ref(0.0), PaD=Ref(0.0), Wh=Ref(0.0), Wg=Ref(0.0),
        V=Ref(0.0), Lam=Ref(0.0), nf=Ref(0), Pkf=Ref(0.0), PaFf=Ref(0.0),
        nT=Ref(0), PkT=Ref(0.0), PaFT=Ref(0.0))
    idxr = Ref{Any}(nothing)
    dt_r = Ref(NaN)
    function tap(uc, tc, s, ctx)
        sysm = ctx.sys
        if idxr[] === nothing
            dt_r[] = KiteTurbineDynamics.stable_dt_for_system(sysm, ctx.pc)
            N = sysm.n_total
            Nr = sysm.n_ring
            hub_ri = sysm.nodes[sysm.rotor.node_id].ring_idx
            gnd_ri = sysm.nodes[sysm.ring_ids[1]].ring_idx
            idxr[] = (N, Nr, hub_ri, gnd_ri)
            println("tap armed at s=", s, " t=", tc, " dt=", dt_r[])
        end
        N, Nr, hub_ri, gnd_ri = idxr[]
        wh = uc[6N + Nr + hub_ri]
        wg = uc[6N + Nr + gnd_ri]
        hub_pos = @view uc[(3 * (sysm.rotor.node_id - 1) + 1):(3 * sysm.rotor.node_id)]
        v_wind = ctx.wf(hub_pos, tc)
        v_hub_mag = norm(v_wind) * sysm.rotor.wind_factor
        v_hub_h = max(sqrt(v_wind[1]^2 + v_wind[2]^2), 0.1)
        elev_live = atan(hub_pos[3], sqrt(hub_pos[1]^2 + hub_pos[2]^2))
        Am = KiteTurbineDynamics.main_rotor_swept_area(sysm)
        lam_l = abs(wh) * sysm.rotor.radius / v_hub_mag
        PaF = 0.5 * ctx.pc.rho * v_hub_mag^3 * Am * cp_at_tsr(lam_l) *
              cos(elev_live)^2.65 * cosd(sysm.rotor.bank_angle_deg)^2.65
        lam_d = abs(wh) * sysm.rotor.radius / v_hub_h
        PaD = 0.5 * ctx.pc.rho * v_hub_h^3 * Am * cp_at_tsr(lam_d) *
              cos(ctx.pc.elevation_angle)^2.65 * cosd(sysm.rotor.bank_angle_deg)^2.65
        tau_gen, _ = KiteTurbineDynamics.get_generator_torque(
            uc, sysm, ctx.pc, tc, ctx.wf; brake_engaged=false)
        Pkw = tau_gen * wg / 1000.0
        if tc > RELAX_S && isfinite(PaF) && isfinite(Pkw)
            S.nf[] += 1; S.Pkf[] += Pkw; S.PaFf[] += PaF
            if tc > RELAX_S + 0.95 * WINDOW_S
                S.nT[] += 1; S.PkT[] += Pkw; S.PaFT[] += PaF
            end
            if s % round(Int, 1.0 / dt_r[]) == 0
                S.n[] += 1; S.Pk[] += Pkw; S.PaF[] += PaF; S.PaD[] += PaD
                S.Wh[] += wh; S.Wg[] += wg; S.V[] += v_hub_mag; S.Lam[] += lam_l
            end
        end
        return
    end

    t0 = time()
    r = KiteTurbineDynamics.evaluate_windowed(
        xr, PROFILE_ELLIPTICAL, p_base, cfg;
        start_mode=:cold,
        lift_device=lift_for,
        trace_callback=tap,
        fitness_fn=(P, F, c, m) -> KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m),
    )
    println("eval wall = ", round(time() - t0, digits=1), " s")
    println("\n== parity vs recorded cold re-eval ==")
    for f in (:fitness, :P_mean, :P_end, :ω_eq)
        got = getfield(r, f); ex = EXPECTED[f]
        println("  ", f, " got=", got, " |diff|=", abs(got - ex))
    end
    println("\n== live window means ==")
    println("1 Hz samples n=", S.n[])
    println("  P_kw (delivered, tau_gen*w_gnd)      = ", S.Pk[] / S.n[])
    println("  P_aero (live-elev, ring_forces form) = ", S.PaF[] / S.n[] / 1000, " kW")
    println("  P_aero (design-elev, frame form)     = ", S.PaD[] / S.n[] / 1000, " kW")
    println("  omega_hub=", S.Wh[] / S.n[], "  omega_gnd=", S.Wg[] / S.n[])
    println("  v_hub_mag=", S.V[] / S.n[], "  lam_tip=", S.Lam[] / S.n[])
    println("every-step n=", S.nf[])
    println("  P_kw fine mean   = ", S.Pkf[] / S.nf[])
    println("  P_aero fine mean = ", S.PaFf[] / S.nf[] / 1000, " kW")
    println("tail 2 s n=", S.nT[])
    println("  P_kw tail mean   = ", S.PkT[] / S.nT[])
    println("  P_aero tail mean = ", S.PaFT[] / S.nT[] / 1000, " kW")
    println("gap 1 - P_del/P_aero (1 Hz)  = ", 1.0 - (S.Pk[] / S.n[]) / (S.PaF[] / S.n[] / 1000.0))
    println("gap 1 - P_del/P_aero (fine)  = ", 1.0 - (S.Pkf[] / S.nf[]) / (S.PaFf[] / S.nf[] / 1000.0))
    println("\nAV_TIPREF_COUNTER_DONE")
end

main()
