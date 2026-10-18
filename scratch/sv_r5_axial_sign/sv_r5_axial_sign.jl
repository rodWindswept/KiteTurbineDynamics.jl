# sv_r5_axial_sign.jl — science-validator seat: sign the R5 signed-axial-force row.
#
# WHY: T3-6 landed the sentence "R5 carries pure axial tension, not no load".
# NR-021 holds only the clipped shares (util_axial = max(N, 0) / N_crit on the
# worst-utilisation beam), so a zero axial share proves "not compression" only.
# The aero counter-read (b0972c0) re-ran the capture and proposed a sibling row
# carrying the signed N range. This is MY OWN run through the shipped library:
# the same evaluator chain as scripts/extract_pair_capture.jl, a per-beam print
# block added, and the run asserts the recorded cold re-eval parity bit-exact.
#
# DATASET   v13_5kw_masslift_len18.8_rotorcount_bankderate2 (data commit dd3cc6a;
#           launch a76c5e9; physics era: post-95c385d_wind-authority).
# CAPTURE   the final integration step of the measurement run (end of the 40 s
#           honest window), same as extract_pair_capture.jl.
#
# USAGE     scripts/ktd-julia scratch/sv_r5_axial_sign/sv_r5_axial_sign.jl
# WRITES    scratch/sv_r5_axial_sign/sv_r5_axial_sign.log

using KiteTurbineDynamics, Printf, LinearAlgebra, Dates
include(joinpath(@__DIR__, "..", "..", "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const WINDOW_S = 40.0
const RELAX_S = 10.0
const MIN_WALL_M = 2.0e-3
const GROUND_OFFSET = 1.0
const ELEV = pi / 6
const LENGTH = 18.8

const REPO = dirname(dirname(@__DIR__))
const OUTDIR = joinpath(REPO, "scratch", "sv_r5_axial_sign")
const WINNER = joinpath(
    REPO, "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_bankderate2",
    "island_3", "best_vector.csv",
)

# Full-precision cold re-eval values from the recorded re-eval
# (scratch/sv_p0_winner_reeval.txt) — the parity certificate for this run.
const EXPECTED = Dict{Symbol,Float64}(
    :fitness => 27.3635412663488,
    :P_mean => 5.3087794439367935,
    :P_end => 5.314113662272673,
    :FoS_min => 14.971791422208508,
    :util_a => 0.06679174086635262,
    :util_b => 5.334714158942919e-7,
    :T_lift => 324.1250954336462,
    :twist_ratio => 0.4393474253185575,
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

function git_out(args...)
    return strip(read(Cmd(String["git", "-C", REPO, args...]), String))
end

function main()::Bool
    mkpath(OUTDIR)
    logpath = joinpath(OUTDIR, "sv_r5_axial_sign.log")
    io = open(logpath, "w")
    say(x...) = (println(io, x...); println(x...); flush(io))

    say("sv_r5_axial_sign / signed axial force per ring (science-validator seat)")
    say("generated: ", now())
    say("dataset: v13_5kw_masslift_len18.8_rotorcount_bankderate2 | data commit dd3cc6a | launch a76c5e9")
    say("physics era: post-95c385d_wind-authority")
    say("computing commit: ", git_out("rev-parse", "HEAD"))

    total_n_r = Ref(-1)
    dt_r = Ref(NaN)
    ctx_r = Ref{Any}(nothing)
    samples = NamedTuple{(:t, :s, :u),Tuple{Float64,Int,Vector{Float64}}}[]  # final-step + 1 Hz decimation
    function tap(uc, tc, s, ctx)
        if total_n_r[] < 0
            dt_r[] = KiteTurbineDynamics.stable_dt_for_system(ctx.sys, ctx.pc)
            total_n_r[] = round(Int, (RELAX_S + WINDOW_S) / dt_r[])
            ctx_r[] = ctx
            say("tap first call: s=", s, " t=", tc, " | dt=", dt_r[], " total_n=", total_n_r[])
        end
        if s == total_n_r[] || tc - (isempty(samples) ? -Inf : samples[end].t) >= 0.999
            push!(samples, (; t=tc, s=s, u=copy(uc)))
        end
    end

    x = [parse(Float64, tok) for tok in split(strip(read(WINNER, String)), ",")]
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    say("genome (raw)       = ", x)
    say("genome (evaluated) = ", xr)

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

    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p_base; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true,
        power_split=cfg.power_split, cone_slope_deg=cfg.cone_slope_deg,
        rotor_spacing_frac=cfg.rotor_spacing_frac, blocking_factor=cfg.blocking_factor)
    clearance = KiteTurbineDynamics.lowest_rotor_clearance(
        dec; ground_offset=GROUND_OFFSET, elevation_deg=rad2deg(ELEV))
    say("decoded: n_lines=", dec.design.n_lines, " rings=", dec.n_rings,
        " n_active=", dec.n_active, " r_hub=", dec.design.r_hub, " r_bot=", dec.design.r_bottom)
    say("clearance = ", clearance, " m")

    t0 = time()
    r = KiteTurbineDynamics.evaluate_windowed(
        xr, PROFILE_ELLIPTICAL, p_base, cfg;
        start_mode=:cold,
        lift_device=lift_for,
        trace_callback=tap,
        fitness_fn=(P, F, c, m) -> KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m),
    )
    say("eval wall = ", round(time() - t0, digits=1), " s")

    say("")
    say("== parity certificate vs recorded cold re-eval (scratch/sv_p0_winner_reeval.txt) ==")
    parity_ok = true
    for f in (:fitness, :P_mean, :P_end, :FoS_min, :util_a, :util_b, :T_lift, :twist_ratio, :ω_eq)
        got = getfield(r, f)
        ex = EXPECTED[f]
        d = got - ex
        d == 0.0 || (parity_ok = false)
        say("  ", rpad(String(f), 12), " got=", got, " expected=", ex, " |diff|=", abs(d),
            " ", d == 0.0 ? "EXACT" : "MISMATCH")
    end
    parity_ok || error("parity certificate failed — do not sign from this run")
    say("parity: BIT-EXACT ON ALL NINE FIELDS")

    finalidx = findlast(sm -> sm.s == total_n_r[], samples)
    cap = finalidx === nothing ? samples[end] : samples[finalidx]
    say("capture: s = ", cap.s, ", t = ", cap.t, " s",
        finalidx === nothing ? "  (WARNING: exact final step not found — used last sample)" : "  (final integration step of the measurement run)")

    u = cap.u
    ctx = ctx_r[]
    sys = ctx.sys
    pc = ctx.pc
    wf = ctx.wf
    lift_dev = ctx.lift_device
    N = sys.n_total
    Nr = sys.n_ring
    @assert length(u) == 6 * N + 2 * Nr
    alpha = u[(6 * N + 1):(6 * N + Nr)]

    ef = KiteTurbineDynamics.capture_extended(u, sys, pc, cap.t, wf, lift_dev;
        brake_engaged=sys.brake_engaged[])
    rea = KiteTurbineDynamics.ring_element_analysis(u, alpha, sys, pc, cap.t, wf)

    say("")
    say("== signed axial force per ring (compression +ve; ring_element_analysis.jl line 20) ==")
    for (kk, ref) in enumerate(rea)
        Ns = [b.N for b in ref.beams]
        sh = [b.N / b.N_crit for b in ref.beams]
        say("R", kk + 1, " | N_min=", minimum(Ns), " N_max=", maximum(Ns),
            " | N/Ncrit_min=", minimum(sh), " N/Ncrit_max=", maximum(sh),
            " | beams=", length(Ns))
    end

    say("")
    say("== R5 per-beam signed values (full precision) ==")
    r5 = rea[4]
    @assert length(r5.beams) == 3
    for (bi, b) in enumerate(r5.beams)
        say("R5 beam ", bi, " | N=", b.N, " | N_crit=", b.N_crit, " | N/Ncrit=", b.N / b.N_crit)
    end
    @assert all(b -> b.N < 0.0, r5.beams)  # all three beams in tension

    say("k_mppt_ref at capture = ", sys.k_mppt_ref[])
    say("SV_R5_AXIAL_DONE")
    return true
end

ok = main()
exit(ok ? 0 : 1)
