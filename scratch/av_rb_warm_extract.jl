#!/usr/bin/env julia --project=.
# av_rb_warm_extract.jl — post-fix warm-path extract on the three winners
# (bankderate2 islands 1..3). W5 fix-branch deliverable: the fresh rows the
# register signs for the NR-013 update after the rope-break gate placement fix.
#
# Records per island: the evaluator-level result (status, line_broken, P_mean,
# P_end, FoS_min, ω_eq, twist) plus a 10 ms warm trace CSV.
#
# Read-only w.r.t. src/. Usage: scripts/ktd-julia scratch/av_rb_warm_extract.jl
using KiteTurbineDynamics, Printf, DelimitedFiles
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const WINDOW_S = 40.0
const RELAX_S = 10.0

const REPO = dirname(@__DIR__)
const RESULTS = joinpath(REPO, "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_bankderate2")
const OUTDIR = joinpath(@__DIR__, "av_rb_warm_extract")

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
    println("av_rb_warm_extract.jl | HEAD ", h)
    mkpath(OUTDIR)
    p_base = params_at_length(18.8)
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
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    )
    @printf("mode=warm | breaks_arm_s=%s (relax boundary) | tree %s\n", string(RELAX_S), h[1:min(8, length(h))])
    println("TARGET | status | broken | P_mean kW | P_end kW | FoS_min | fitness | omega_eq | twist | T_lift N | wall s")

    summary_rows = String[]
    for island in 1:3
        v = vec(readdlm(joinpath(RESULTS, "island_$island/best_vector.csv"), ',', Float64))
        rows = Ref(Tuple{Float64,Float64,Float64,Float64,Bool}[])
        hub_ri = Ref(0)
        next_t = Ref(0.0)
        function trace_cb(u, t, s, ctx)
            hub_ri[] == 0 && (hub_ri[] = (ctx.sys.nodes[ctx.sys.rotor.node_id]::KiteTurbineDynamics.RingNode).ring_idx)
            if t >= next_t[]
                next_t[] = t + 0.01
                N = ctx.sys.n_total
                Nr = ctx.sys.n_ring
                wg = u[6N + Nr + 1]
                wh = u[6N + Nr + hub_ri[]]
                tau, _ = KiteTurbineDynamics.get_generator_torque(
                    u, ctx.sys, ctx.pc, t, ctx.wf; brake_engaged=ctx.sys.brake_engaged[],
                )
                # roped P: generator torque × ground-ring rate, kW
                push!(rows[], (t, wg, wh, tau * wg / 1000.0, ctx.sys.any_broken[]))
            end
        end
        t0 = time()
        r = KiteTurbineDynamics.evaluate_windowed(
            v, PROFILE_ELLIPTICAL, p_base, cfg;
            start_mode=:warm,
            lift_device=lift_for,
            trace_callback=trace_cb,
            fitness_fn=(P, F, c, m) -> KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m),
        )
        wall = round(time() - t0, digits=1)
        @printf("island %d | %s | %s | %8.3f | %8.3f | %7.3f | %8.3f | %8.3f | %5.3f | %7.1f | %6.1f\n",
            island, r.status, r.line_broken, r.P_mean, r.P_end, r.FoS_min, r.fitness,
            r.ω_eq, r.twist_ratio, r.T_lift, wall)
        flush(stdout)
        push!(summary_rows, @sprintf(
            "island %d | %s | %s | %8.3f | %8.3f | %7.3f | %8.3f | %8.3f | %5.3f | %7.1f | %6.1f",
            island, r.status, r.line_broken, r.P_mean, r.P_end, r.FoS_min, r.fitness,
            r.ω_eq, r.twist_ratio, r.T_lift, wall))
        csvpath = joinpath(OUTDIR, "island_$(island)_warm_10ms.csv")
        open(csvpath, "w") do io
            println(io, "# av_rb_warm_extract / island_$(island)_warm_10ms.csv")
            println(io, "# Post-fix warm run (rope-break detection armed at the relax boundary, 2026-09-16 ruling).")
            println(io, "# circuit: scratch/av_rb_warm_extract.jl | tree ", h[1:min(8, length(h))], " | start_mode=:warm | k=", cfg.k_mppt)
            println(io, "# result: status=", r.status, " line_broken=", r.line_broken,
                " P_mean=", r.P_mean, " P_end=", r.P_end, " omega_eq=", r.ω_eq)
            println(io, "t,omega_gnd,omega_hub,P_gen_kw,any_broken")
            for (t, wg, wh, pk, brk) in rows[]
                @printf(io, "%.6f,%.9f,%.9f,%.9f,%d\n", t, wg, wh, pk, Int(brk))
            end
        end
        println("  csv: ", csvpath, " (", length(rows[]), " rows)")
    end
    println("\nSUMMARY (warm, post-fix):")
    for s in summary_rows
        println("  ", s)
    end
    println("\nPre-fix reference (NR-013): :warm rejects all three winners — rope-break gate (broken=true), transient line over-strain during relax.")
end

main()
