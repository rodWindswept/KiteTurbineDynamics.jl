#!/usr/bin/env julia --project=.
#= run_length_variants.jl — the discrete-L variant sweep for the 5 kW rung.

One candidate genome (default: `seed_genome(5.0)`; `--genome island3` for the
current campaign winner; or `--genome <best_vector.csv>` for any 10-D vector)
is decoded at each L in the discrete set (default 18.8 / 21.2 / 25.0 / 30.0 /
40.0 m — the 2026-10-03 discrete-L ruling; override with `--lengths`), then,
per L:

  1. Design-side TRPT realisability gauges (bare, no preload-floor enforcement —
     same convention as `test/test_trpt_realisability.jl` section A):
       F_ax        = design_axial_preload(…; realisability_margin=1.0)   [built placement u0]
       place       = trpt_matched_place(…; raise_on_unrealisable=false)  [ω = settled ω_gnd]
       demand_max  = maximum(place.demand)                [sin Δα demand; 1.0 = cliff]
       cross_bare  = max_segment_cross_ratio(place, sys)  [geometric crossing]
       gate_ratio  = max(demand_max, cross_bare) · TRPT_REALISABILITY_TENSION_MARGIN
                     (refused when > TRPT_REALISABILITY_MAX_PRELOAD_FACTOR = 1.5;
                      the printed "needs X.XX×" is this ratio — cf. the L/r 2.0
                      verdict "1.6897 → needs 1.774×").

  2. ODE gate (settle 30k → 10 s relax → 30 s window in 5 s chunks, breaks ON
     over the window, mirroring scripts/ode_gate_v13.jl's protocol):
       P_gen_final / P_gen_mean, ω_hub / ω_gnd, ODE twist ratio (twist_report),
       crossed, line_broken, tip-speed sanity, clearance.
     Plus end-of-window SimFrame reads: T_max, fos_tether, fos_ring, tsr, V_hub.

WIND — site spec, not a literal.  The closure is the evaluator's own
(objective_evaluator.jl:768): wind_at_altitude(v_wind_ref, h_ref, z) with the
shear exponent read from SITE_DAISY.shear_exp (1/7, Tulloch/Daisy measured).
NOTE: scripts/ode_gate_v13.jl still flies FLAT 11.0 m/s; this runner follows
the evaluator closure, which is the one the frozen-anchor length lever and the
campaign telemetry are defined in.  (Script-tier cleanup flagged separately.)

SIZING BASIS — HEAD = measured fixed-chord Rf surface for cp_bem/ct_bem sizing
(a82cafd, 2026-10-05); the p.cp=0.16 floor bar is untouched.  Every row here is
stamped to the HEAD basis so that re-pricing cannot be silent.

Usage:
  scripts/ktd-julia scripts/run_length_variants.jl [--genome seed|island3|<csv>]
      [--lengths 18.8,21.2,25.0,30.0,40.0] [--window 30.0] [--tag seed] [--quick]

  --quick: smoke mode (5k-step settle, 2 s relax, 5 s window) — NOT quotable.

Output: scripts/results/length_variants_<tag>/variants.csv (+ trace/meta/genome).
=#

using KiteTurbineDynamics, Printf, LinearAlgebra

const ROOT = dirname(@__DIR__)
# ode_gate_v13.jl brings the shared helpers: decode_winner, twist_report,
# lift_for, params_at_length, the gate constants — and includes compute_seeds.jl
# (seed_genome, K_MPPT_5KW_HONEST, BLOCKING_WIND_FACTOR_5KW) itself.
include(joinpath(@__DIR__, "ode_gate_v13.jl"))

const GIT = try
    strip(read(`git -C $ROOT rev-parse --short HEAD`, String))
catch
    "unknown"
end
const RUN_ISO = try
    strip(read(`date -u +%Y-%m-%dT%H:%MZ`, String))
catch
    "unknown"
end

const WINNER_CSV = joinpath(
    @__DIR__, "results", "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv"
)

# ── CLI ─────────────────────────────────────────────────────────────────────

function parse_cli()
    genome = "seed"
    lengths = [18.8, 21.2, 25.0, 30.0, 40.0]
    window_s = 30.0
    tag = ""
    quick = false
    i = 1
    while i <= length(ARGS)
        a = ARGS[i]
        if a == "--genome" && i < length(ARGS)
            genome = ARGS[i+1]; i += 2
        elseif a == "--lengths" && i < length(ARGS)
            lengths = parse.(Float64, split(ARGS[i+1], ",")); i += 2
        elseif a == "--window" && i < length(ARGS)
            window_s = parse(Float64, ARGS[i+1]); i += 2
        elseif a == "--tag" && i < length(ARGS)
            tag = ARGS[i+1]; i += 2
        elseif a == "--quick"
            quick = true; i += 1
        else
            error("unknown arg: $a")
        end
    end
    if isempty(tag)
        tag = genome == "seed" ? "seed" : genome == "island3" ? "island3" : "custom"
    end
    return (genome=genome, lengths=lengths, window_s=window_s, tag=tag, quick=quick)
end

function load_genome(spec::String)
    spec == "seed" && return seed_genome(5.0)
    path = spec == "island3" ? WINNER_CSV : spec
    isfile(path) || error("genome file not found: $path")
    for line in eachline(path)
        s = strip(line)
        (isempty(s) || startswith(s, "#")) && continue
        toks = split(s, ",")
        length(toks) >= 10 || continue
        vals = tryparse.(Float64, strip.(toks[1:10]))
        all(!isnothing, vals) && return Float64.(vals)
    end
    error("no 10-gene float row found in $path")
end

# ── One candidate at one L ──────────────────────────────────────────────────

function variant_case(x::Vector{Float64}, L::Float64; window_s::Float64=30.0, quick::Bool=false)
    d = decode_winner(x; L=L, KW=5.0)
    p, k_mp, bf, dec = d.p, d.k_mp, d.bf, d.dec

    clearance = KiteTurbineDynamics.lowest_rotor_clearance(
        dec; ground_offset=GROUND_OFFSET, elevation_deg=rad2deg(ELEV))

    cfg = KiteTurbineDynamics.ObjectiveConfig(;
        power_W=5000.0, v_rated=11.0, p_floor_kw=5.0,
        fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
        rotor_count_mode=true, power_split=0.6, blocking_factor=bf)
    sizing = KiteTurbineDynamics.size_beams_closed_form(dec, p, cfg)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, k_mp;
        tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3,
        beam_sizing=sizing)
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
    lift = lift_for(sys, pc)

    # Site-spec wind closure — the evaluator's form, exponent from SITE_DAISY.
    α_h = SITE_DAISY.shear_exp
    wf = (pos, t) -> begin
        z = max(pos[3], 1.0)
        [wind_at_altitude(p.v_wind_ref, p.h_ref, z; hellmann_exponent=α_h), 0.0, 0.0]
    end

    N, Nr = sys.n_total, sys.n_ring
    n_op = quick ? 5_000 : 30_000
    relax_chunks = quick ? 1 : 2
    relax_s = quick ? 2.0 : 5.0
    win_s = quick ? 5.0 : window_s

    row = (; L=L, verdict="", ok=false,
        n_lines=dec.design.n_lines, rings=dec.n_rings, n_active=dec.n_active,
        r_hub=dec.design.r_hub, clearance=clearance, dt=dt,
        P_final=NaN, P_mean=NaN, w_hub=NaN, w_gnd=NaN,
        twist_ode_max=NaN, crossed_ode=true, line_broken=false, tip_ok=false,
        T_max=NaN, fos_tether=NaN, fos_ring=NaN, tsr=NaN, V_hub=NaN, dalpha_deg=NaN,
        demand_max=NaN, cross_bare=NaN, gate_ratio=NaN,
        realisability="n/a", settle=false)

    u = try
        settle_to_operational_state(sys, copy(u0), pc, 60.0;
            lift_device=lift, wind_fn=wf, n_op=n_op)
    catch e
        @warn "L=$(L) m: settle refused an unrealisable design point" exception = e
        return merge(row, (verdict="REFUSED(settle)",)), NamedTuple[]
    end
    sys.k_mppt_ref[] = k_mp

    hub_ri = (sys.nodes[sys.rotor.node_id]::RingNode).ring_idx
    gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx

    for _ in 1:relax_chunks
        run_canonical_sim!(u, sys, pc, wf, max(round(Int, relax_s / dt), 1), dt;
            lift_device=lift, lin_damp=0.05)
    end

    trace = Vector{NamedTuple{(:L, :t, :w_hub, :w_gnd, :P_gen, :crossed, :twist_max),
        Tuple{Float64,Float64,Float64,Float64,Float64,Bool,Float64}}}()
    t = 0.0
    nchunks = max(round(Int, win_s / 5.0), 1)
    chunk_s = quick ? win_s : win_s / nchunks
    for _ in 1:nchunks
        run_canonical_sim!(u, sys, pc, wf, max(round(Int, chunk_s / dt), 1), dt;
            lift_device=lift, lin_damp=0.05, breaks_enabled=true)
        t += chunk_s
        w_hub = u[6N + Nr + hub_ri]
        w_gnd = u[6N + Nr + gnd_ri]
        tau_gen, _ = get_generator_torque(u, sys, p, t, wf; brake_engaged=sys.brake_engaged[])
        P_gen = tau_gen * w_gnd / 1000.0
        tr = twist_report(u, sys, N, Nr)
        push!(trace, (L=L, t=t, w_hub=w_hub, w_gnd=w_gnd, P_gen=P_gen,
            crossed=tr.crossed, twist_max=tr.max_ratio))
    end

    frame = capture_frame(u, sys, pc, t, wf, lift)
    fin = trace[end]

    # ── Design-side realisability gauges (bare margin=1.0; fixture convention) ──
    demand_max = NaN; cross_bare = NaN; gate_ratio = NaN
    w_eq = fin.w_gnd
    F_ax = try
        design_axial_preload(sys, pc, lift, u0;
            omega_eq=w_eq, wind_fn=wf, realisability_margin=1.0)
    catch e
        @warn "L=$(L) m: bare preload solve failed" exception = e
        Float64[]
    end
    if !isempty(F_ax)
        place = try
            trpt_matched_place(sys, pc, F_ax, sys.k_mppt_ref[] * w_eq^2, w_eq, wf;
                raise_on_unrealisable=false)
        catch e
            @warn "L=$(L) m: matched-place failed" exception = e
            nothing
        end
        if place !== nothing
            demand_max = maximum(place.demand)
            cross_bare = KiteTurbineDynamics.max_segment_cross_ratio(place, sys)
            gate_ratio = max(demand_max, cross_bare) *
                         KiteTurbineDynamics.TRPT_REALISABILITY_TENSION_MARGIN
        end
    end
    realisability = if !isfinite(gate_ratio)
        "n/a"
    elseif gate_ratio <= 1.0
        "under-bare"
    elseif gate_ratio <= KiteTurbineDynamics.TRPT_REALISABILITY_MAX_PRELOAD_FACTOR
        "repair-within-cap"
    else
        @sprintf("needs %.2f×", gate_ratio)
    end

    # ── Gate verdict (same thresholds as ode_gate_v13.jl) ──
    tip_ok = tip_speed_sanity_ok(u, sys)
    line_broken = sys.any_broken[]
    ok = (fin.P_gen >= MIN_P_GEN_KW) && (fin.w_gnd > MIN_W_GND) &&
         (!fin.crossed) && (clearance >= MIN_CLEARANCE) && (!line_broken) && tip_ok
    reasons = String[]
    fin.P_gen < MIN_P_GEN_KW && push!(reasons, @sprintf("P<%.1f", MIN_P_GEN_KW))
    fin.w_gnd <= MIN_W_GND && push!(reasons, "ω_gnd")
    fin.crossed && push!(reasons, "crossed")
    clearance < MIN_CLEARANCE && push!(reasons, "clearance")
    line_broken && push!(reasons, "line-break")
    !tip_ok && push!(reasons, "tip-speed")
    verdict = ok ? "PASS" : "FAIL(" * join(reasons, "+") * ")"

    row = merge(row, (; verdict=verdict, ok=ok,
        P_final=fin.P_gen, P_mean=sum(r.P_gen for r in trace) / length(trace),
        w_hub=fin.w_hub, w_gnd=fin.w_gnd,
        twist_ode_max=fin.twist_max, crossed_ode=fin.crossed,
        line_broken=line_broken, tip_ok=tip_ok,
        T_max=frame.T_max, fos_tether=frame.fos_tether, fos_ring=frame.fos_ring,
        tsr=frame.tsr, V_hub=frame.V_hub, dalpha_deg=frame.delta_alpha_deg,
        demand_max=demand_max, cross_bare=cross_bare, gate_ratio=gate_ratio,
        realisability=realisability, settle=true))
    return row, trace
end

# ── Main ────────────────────────────────────────────────────────────────────

function main()
    cli = parse_cli()
    x = load_genome(cli.genome)
    outdir = joinpath(@__DIR__, "results", "length_variants_$(cli.tag)")
    mkpath(outdir)

    println("=== run_length_variants.jl — discrete-L variant sweep ===")
    println("  genome:  ", cli.genome, "   (", length(x), " genes)")
    println("  lengths: ", join(cli.lengths, " / "), " m")
    println("  window:  ", cli.quick ? "QUICK SMOKE (not quotable)" : "$(cli.window_s) s, breaks ON")
    println("  wind:    site shear via SITE_DAISY.shear_exp = ", SITE_DAISY.shear_exp,
            "  (evaluator closure)")
    println("  git:     ", GIT, "   era: post-D1 sizing, bank-derate, frozen anchor")
    println()

    rows = NamedTuple[]
    traces = NamedTuple[]
    t0 = time()
    for L in cli.lengths
        print("  L = ", L, " m ... ")
        flush(stdout)
        r, tr = variant_case(x, L; window_s=cli.window_s, quick=cli.quick)
        push!(rows, r)
        append!(traces, tr)
        @printf("P=%.2f kW  fos_tether=%.2f  twist=%.2f  cross=%.3f  demand=%.3f  gate=%.3f  %s\n",
            r.P_final, r.fos_tether, r.twist_ode_max, r.cross_bare, r.demand_max,
            r.gate_ratio, r.verdict)
        flush(stdout)
    end
    elapsed = time() - t0

    # ── variants.csv ──
    csvpath = joinpath(outdir, "variants.csv")
    open(csvpath, "w") do io
        println(io, "# run_length_variants.jl — discrete-L variant sweep")
        println(io, "# git=", GIT, "  date=", RUN_ISO, "  quick=", cli.quick,
            "  window_s=", cli.quick ? 5.0 : cli.window_s)
        println(io, "# genome=", cli.genome)
        println(io, "# wind=wind_at_altitude(v_wind_ref, h_ref, z; hellmann_exponent=SITE_DAISY.shear_exp=",
            SITE_DAISY.shear_exp, ") — evaluator closure (ode_gate_v13.jl flies flat; flagged)")
        println(io, "# basis=HEAD cp_bem(n_lines,λ) sizing; floor bar p.cp=0.16 untouched (landed a82cafd: measured fixed-chord Rf surface, cp_bem/ct_bem)")
        println(io, "# realisability=bare margin=1.0 preload at built placement; ω=settled ω_gnd; gate_ratio=max(demand,cross)·",
            KiteTurbineDynamics.TRPT_REALISABILITY_TENSION_MARGIN, " vs cap ",
            KiteTurbineDynamics.TRPT_REALISABILITY_MAX_PRELOAD_FACTOR)
        println(io, "L,verdict,ok,n_lines,rings,n_active,r_hub,clearance_m,dt_s,",
            "P_final_kW,P_mean_kW,w_hub,w_gnd,twist_ode_max,crossed_ode,line_broken,tip_ok,",
            "T_max_N,fos_tether,fos_ring,tsr,V_hub,dalpha_deg,demand_max,cross_bare,gate_ratio,realisability")
        for r in rows
            @printf(io, "%.1f,%s,%d,%d,%d,%d,%.4f,%.3f,%.2e,%.4f,%.4f,%.4f,%.4f,%.4f,%d,%d,%d,%.2f,%.3f,%.3f,%.4f,%.4f,%.2f,%.4f,%.4f,%.4f,%s\n",
                r.L, r.verdict, r.ok ? 1 : 0, r.n_lines, r.rings, r.n_active, r.r_hub,
                r.clearance, r.dt, r.P_final, r.P_mean, r.w_hub, r.w_gnd,
                r.twist_ode_max, r.crossed_ode ? 1 : 0, r.line_broken ? 1 : 0,
                r.tip_ok ? 1 : 0, r.T_max, r.fos_tether, r.fos_ring, r.tsr,
                r.V_hub, r.dalpha_deg, r.demand_max, r.cross_bare, r.gate_ratio,
                r.realisability)
        end
    end

    # ── variants_trace.csv (5 s chunks) ──
    open(joinpath(outdir, "variants_trace.csv"), "w") do io
        println(io, "# per-chunk trace; git=", GIT, " quick=", cli.quick)
        println(io, "L,t,w_hub,w_gnd,P_gen_kW,crossed,twist_max")
        for r in traces
            @printf(io, "%.1f,%.1f,%.4f,%.4f,%.4f,%d,%.4f\n",
                r.L, r.t, r.w_hub, r.w_gnd, r.P_gen, r.crossed ? 1 : 0, r.twist_max)
        end
    end

    # ── genome_used.csv ──
    open(joinpath(outdir, "genome_used.csv"), "w") do io
        println(io, join(x, ","))
    end

    println()
    println("  wrote ", csvpath, "  (", length(rows), " rows, ", round(elapsed; digits=1), " s)")
    if any(r -> r.ok, rows)
        println("  PASS at: ", join([string(r.L) for r in rows if r.ok], " / "), " m")
    else
        println("  no PASS in this set")
    end
    return rows
end

if abspath(PROGRAM_FILE) == (@__FILE__) || get(ENV, "KTD_SWEEP_FORCE_MAIN", "") == "1"
    main()
end
