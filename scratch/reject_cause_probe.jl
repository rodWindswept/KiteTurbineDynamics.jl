#!/usr/bin/env julia
# scratch/reject_cause_probe.jl
# Classify WHY each FoS=Inf reject row failed, using the evaluator's own checks.
#
# The telemetry status column collapses several distinct hard-failure paths
# into one "reject" bucket. This probe re-runs each FoS=Inf reject genome
# through evaluate_windowed with a trace callback that latches, in the
# evaluator's RETURN-priority order, the first failure signature:
#   rope_break -> sys.any_broken[]            (also result.line_broken)
#   twist      -> twist_collapse_check crossed (also result.twist_crossed)
#   nonfinite  -> NaN/Inf anywhere in the state (garbage / empty P_samples)
#   hub_tip    -> !tip_speed_sanity_ok (non-finite omega or past ceiling)
#   betz       -> any per-rotor rotor_betz_ok failure
#
# Cheap checks (nonfinite, hub/tip) run EVERY step. The expensive
# capture_extended / Betz check runs only at ~1 Hz in the window, mirroring
# the evaluator's own sample cadence — so probe cost ≈ evaluator cost.
#
# Run:  julia --project=. scratch/reject_cause_probe.jl [--limit N] [--all]

using KiteTurbineDynamics
import KiteTurbineDynamics
import Printf

const KW = 5.0
const PW = KW * 1000.0
const ELEV = π / 6
const V_RATED = 11.0
const LENGTH = 18.8

# ---- reproduce the runner's params + cfg EXACTLY (run_v13_5kw_masslift.jl) ----
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

p_base = params_at_length(LENGTH)
beam_profile = PROFILE_ELLIPTICAL
lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

cfg = ObjectiveConfig(;
    power_W = PW, v_rated = V_RATED,
    p_floor_kw = 5.0, p_ceiling_kw = 5.0,
    relax_s = 10.0, window_s = 40.0,
    fos_target = 2.5, fos_hard = 2.5,
    power_stat = :tail5, penalize_ceiling = false,
    kickstart_s = 0.0,
    k_mppt = 2.24,   # K_MPPT_5KW_HONEST
    tether_diameter = p_base.tether_diameter,
    rotor_count_mode = true,
    power_split = 0.6,
    cone_slope_deg = 22.0,
    rotor_spacing_frac = 0.8,
    blocking_factor = 0.85^(1 / 3),
    min_wall_m = 2e-3,
)

# ---- load reject rows from the three island telemetry CSVs ----
# A row is kept if status==reject AND FoS is "Inf" (the mystery rows whose
# failure reason the telemetry does not record). "--all" also re-runs the
# finite-FoS rejects (those are already explained as under-floor, but re-run
# for completeness).
reject_rows = []
for isl in 1:3
    f = joinpath("scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2",
                 "island_$isl", "telemetry.csv")
    open(f) do io
        lines = readlines(io)
        hdr = split(strip(lines[2]), ',')
        for ln in lines[3:end]
            d = Dict(zip(hdr, split(strip(ln), ',')))
            d["status"] == "reject" || continue
            x = [parse(Float64, d["x$j"]) for j in 1:10]
            n_lines = parse(Int, d["n_lines"])
            n_active = parse(Int, d["n_active"])
            push!(reject_rows, (island=isl, gen=parse(Int, d["gen"]), idx=parse(Int, d["idx"]),
                                 x=x, fos=d["FoS"], pend=d["P_end"],
                                 n_lines=n_lines, n_active=n_active,
                                 r_hub=parse(Float64, d["r_hub"]),
                                 r_bot=parse(Float64, d["r_bot"]),
                                 blade_top=parse(Float64, d["blade_scale_top"])))
        end
    end
end

ALL = "--all" in ARGS
filter!(r -> ALL || r.fos == "Inf", reject_rows)

LIMIT = (function()
    i = findfirst(==("--limit"), ARGS)
    i === nothing ? length(reject_rows) : parse(Int, ARGS[i + 1])
end)()
n_probe = min(LIMIT, length(reject_rows))

println("FoS=Inf reject rows: $(length(reject_rows)); probing $n_probe")

# ---- pre-settle gates (cheap: decode only, no ODE) ----
# Replicates evaluate_windowed lines 730-780: n_active==0, spacing_ok==false,
# n_rings<1.  The annulus gate (rotor_annulus_ok) needs a built system, so it
# is NOT checked here; if these three pass and the window still never ran, the
# settle itself threw (torsional realisability cliff) or the annulus gate bit.
function pre_settle_gate(xr::Vector{Float64})
    x_canon = KiteTurbineDynamics.canonical_v10(xr)
    result = KiteTurbineDynamics.design_from_vector_v10(
        x_canon, beam_profile, p_base;
        power_W=cfg.power_W, v_rated=cfg.v_rated,
        cylinder_cone=true, rotor_count_mode=cfg.rotor_count_mode,
        power_split=cfg.power_split, cone_slope_deg=cfg.cone_slope_deg,
        rotor_spacing_frac=cfg.rotor_spacing_frac,
        blocking_factor=cfg.blocking_factor, beam_t_over_D=cfg.t_over_D,
    )
    result.n_active == 0 && return :no_active
    haskey(result, :spacing_ok) && !result.spacing_ok && return :spacing
    result.n_rings < 1 && return :rings
    return :ok
end

# ---- classify one genome ----
function classify(x::Vector{Float64})
    # replicate the runner's rounding (eval_v13)
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))

    gate = pre_settle_gate(xr)
    gate == :ok || return gate

    latch = Ref{Symbol}(:none)
    callback_fired = Ref(false)
    got = Ref{Any}(nothing)
    last_betz = Ref(-Inf)

    function tc(uc, t, step, ctx)
        callback_fired[] = true
        if latch[] != :none
            return
        end
        sys = ctx.sys
        # cheap, every step: non-finite state -> garbage
        if any(!isfinite, uc)
            latch[] = :nonfinite
            return
        end
        # cheap, every step: hub/tip divergence (non-finite omega included)
        if !KiteTurbineDynamics.tip_speed_sanity_ok(uc, sys)
            latch[] = :hub_tip
            return
        end
        # expensive Betz check, ~1 Hz in the window only
        if t > cfg.relax_s && (t - last_betz[]) >= 1.0
            last_betz[] = t
            ef = KiteTurbineDynamics.capture_extended(uc, sys, ctx.pc, t, ctx.wf, ctx.lift_device;
                                                     brake_engaged=sys.brake_engaged[])
            n_er = length(sys.expansion_rotors)
            for (i, pa_kw) in enumerate(ef.rotor_aero_power)
                A_i = if i == 1
                    KiteTurbineDynamics.main_rotor_bank_projected_area(sys)
                elseif i - 1 <= n_er
                    er = sys.expansion_rotors[i - 1]
                    ri = er.ring_idx
                    r_ring = (1 <= ri <= sys.n_ring) ? (sys.nodes[sys.ring_ids[ri]]::RingNode).radius : 0.0
                    KiteTurbineDynamics.expansion_annulus_area(er, r_ring)
                else
                    0.0
                end
                if A_i > 0.0 && !KiteTurbineDynamics.rotor_betz_ok(pa_kw, A_i, V_RATED)
                    latch[] = :betz
                    return
                end
            end
        end
    end

    r = try
        KiteTurbineDynamics.evaluate_windowed(
            xr, beam_profile, p_base, cfg;
            start_mode = :cold,
            lift_device = lift_for,
            trace_callback = tc,
            fitness_fn = (P, F, c, m) -> KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m),
        )
    catch e
        got[] = e
        nothing
    end

    if r === nothing
        return got[] === nothing ? :error : :exception
    elseif r.line_broken
        return :rope_break
    elseif r.twist_crossed
        return :twist
    elseif latch[] != :none
        return latch[]
    elseif !callback_fired[]
        return :settle_fail   # settle threw (torsional realisability cliff) or returned nothing
    else
        return :under_floor   # window ran, finite FoS, but scored below power floor
    end
end

results = Dict{Symbol,Int}()
rows_out = []
for (k, row) in enumerate(reject_rows[1:n_probe])
    reason = try
        classify(row.x)
    catch
        :error
    end
    results[reason] = get(results, reason, 0) + 1
    push!(rows_out, (reason=reason, n_lines=row.n_lines, n_active=row.n_active,
                     r_hub=row.r_hub, r_bot=row.r_bot, blade_top=row.blade_top))
    println(Printf.@sprintf("  [%d/%d] island=%d gen=%d idx=%d  %s", k, n_probe, row.island, row.gen, row.idx, reason))
end

println("\n=== reject-cause classification ===")
for (reason, n) in sort(collect(results), by = x -> -x[2])
    println(Printf.@sprintf("  %-16s %d", reason, n))
end
println("total: ", sum(values(results)))

# ---- design-condition cross-tab for the dominant classes ----
println("\n=== n_lines distribution by cause ===")
for (reason, _) in sort(collect(results), by = x -> -x[2])
    sub = [r.n_lines for r in rows_out if r.reason == reason]
    isempty(sub) && continue
    println(Printf.@sprintf("  %-16s n_lines: min=%d max=%d mean=%.1f", reason, minimum(sub), maximum(sub), sum(sub) / length(sub)))
end
println("\n=== n_active (rotor count) distribution by cause ===")
for (reason, _) in sort(collect(results), by = x -> -x[2])
    sub = [r.n_active for r in rows_out if r.reason == reason]
    isempty(sub) && continue
    println(Printf.@sprintf("  %-16s n_active: %s", reason, join(sort(unique(sub)), ",")))
end
