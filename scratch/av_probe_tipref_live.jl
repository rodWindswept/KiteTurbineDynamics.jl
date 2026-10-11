#!/usr/bin/env julia --project=.
# av_probe_tipref_live.jl — aero-validator follow-up to av_probe_tipref_counter.jl:
# live operating-point detail at the window mean.  Records the hub position,
# elevation, inflow wind, and the model's own hub aero charge + delivered power
# at the evaluator's window cadence.  Evidence receipt for the flown-basis edge
# note in the NR-032 to NR-034 block; committed with the re-base follow-up.
# The run log travels beside it as av_probe_tipref_live.log.
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

    S = (; n=Ref(0), x=Ref(0.0), y=Ref(0.0), z=Ref(0.0), e=Ref(0.0), v=Ref(0.0),
        w=Ref(0.0), Pk=Ref(0.0), PaF=Ref(0.0),
        zmin=Ref(Inf), zmax=Ref(-Inf), emin=Ref(Inf), emax=Ref(-Inf),
        nf=Ref(0), Pkf=Ref(0.0), PaFf=Ref(0.0))
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
            println("tap armed at s=", s, " t=", tc)
        end
        N, Nr, hub_ri, gnd_ri = idxr[]
        wh = uc[6N + Nr + hub_ri]
        wg = uc[6N + Nr + gnd_ri]
        hub_pos = @view uc[(3 * (sysm.rotor.node_id - 1) + 1):(3 * sysm.rotor.node_id)]
        v_wind = ctx.wf(hub_pos, tc)
        v_mag = norm(v_wind) * sysm.rotor.wind_factor
        z = hub_pos[3]
        xy = sqrt(hub_pos[1]^2 + hub_pos[2]^2)
        elev = atan(z, max(xy, 1e-9))
        lam = abs(wh) * sysm.rotor.radius / v_mag
        PaF = 0.5 * ctx.pc.rho * v_mag^3 * KiteTurbineDynamics.main_rotor_swept_area(sysm) *
              cp_at_tsr(lam) * cos(elev)^2.65 * cosd(sysm.rotor.bank_angle_deg)^2.65
        tau_gen, _ = KiteTurbineDynamics.get_generator_torque(
            uc, sysm, ctx.pc, tc, ctx.wf; brake_engaged=false)
        Pkw = tau_gen * wg / 1000.0
        if tc > RELAX_S && isfinite(PaF) && isfinite(Pkw)
            S.nf[] += 1; S.Pkf[] += Pkw; S.PaFf[] += PaF
            S.zmin[] = min(S.zmin[], z); S.zmax[] = max(S.zmax[], z)
            S.emin[] = min(S.emin[], elev); S.emax[] = max(S.emax[], elev)
            if s % round(Int, 1.0 / dt_r[]) == 0
                S.n[] += 1
                S.x[] += hub_pos[1]; S.y[] += hub_pos[2]; S.z[] += z
                S.e[] += rad2deg(elev); S.v[] += v_mag; S.w[] += wh
                S.Pk[] += Pkw; S.PaF[] += PaF
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
    println("\n== parity ==")
    for f in (:fitness, :P_mean, :P_end, :ω_eq)
        got = getfield(r, f); ex = EXPECTED[f]
        println("  ", f, " |diff|=", abs(got - ex))
    end
    n = S.n[]
    xbar = S.x[] / n; ybar = S.y[] / n; zbar = S.z[] / n
    ebar = S.e[] / n; vbar = S.v[] / n; wbar = S.w[] / n
    Pkbar = S.Pk[] / n; PaFbar = S.PaF[] / n / 1000
    println("\n== live window means (1 Hz, n=", n, ") ==")
    println("hub position mean: x=", xbar, " y=", ybar, " z=", zbar,
        "  (radial hypot=", hypot(xbar, ybar), ")")
    println("hub elevation mean = ", ebar, " deg   spread z: ", S.zmin[], " .. ", S.zmax[])
    println("            elev spread = ", rad2deg(S.emin[]), " .. ", rad2deg(S.emax[]), " deg")
    println("inflow wind mean = ", vbar, " m/s")
    println("omega_hub mean = ", wbar, "   tip speed = ", wbar * 5.629560432565964, " m/s")
    println("lambda_tip (live mean basis) = ", wbar * 5.629560432565964 / vbar)
    println("P_kw delivered (1 Hz mean) = ", Pkbar, " kW")
    println("P_aero hub charge (1 Hz mean) = ", PaFbar, " kW")
    println("gap delivered vs aero = ", 1.0 - Pkbar / PaFbar,
        "   (aero is ", (PaFbar / Pkbar - 1.0) * 100.0, " % above delivered)")
    println("fine (every-step) n=", S.nf[], "  P_kw=", S.Pkf[] / S.nf[],
        "  P_aero=", S.PaFf[] / S.nf[] / 1000, " kW")
    println("wind_at_altitude(v_ref, h_ref, zbar) = ",
        KiteTurbineDynamics.wind_at_altitude(p_base.v_wind_ref, p_base.h_ref, zbar))
    println("wind_at_altitude(v_ref, h_ref, 9.4117) = ",
        KiteTurbineDynamics.wind_at_altitude(p_base.v_wind_ref, p_base.h_ref, 9.411699279797105))
    println("static hub z if straight 18.8 m shaft from z0=1.0 at given elev: ",
        1.0 + 18.8 * sin(deg2rad(ebar)))
    println("\nAV_TIPREF_LIVE_DONE")
end

main()
