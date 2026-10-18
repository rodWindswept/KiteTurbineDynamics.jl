# sv_reject_sixclass_a76c5e9.jl — science-validator seat: re-derive the six-class
# 201-reject split at the PRODUCING commit.
#
# WHY: the draft (section 3.1 and section 5) prints the six-class breakdown of
# the 201 unlogged FoS=Inf rejects: 93 power floor, 37 realisability cliff,
# 36 rotor spacing, 29 line breaks, 3 Betz ceiling, 3 hub tip speed.
# NR-055 signs the three-way split only, so no signed row carries the six
# numbers. That is a release blocker (round-1 routing, hermes).
#
# BASIS: the routing prefers a re-derivation at the producing commit a76c5e9.
# The HEAD re-run (b65e9c8) classified 29 rows as rope_break, but 2bf76a3
# (2026-10-15) armed break detection at the relax boundary. At a76c5e9 the
# detector ran for the whole relax plus window run, so a relax-phase break
# latched as rope_break. A re-derivation at the producing commit reproduces
# the campaign's own gate behavior. The other five classes are static gates
# or window checks that do not depend on the arming change.
#
# RUN: this script runs INSIDE the detached worktree at a76c5e9
# (scratch/wt_reject_a76c5e9), whose src/ reads the producing commit's code.
# The telemetry CSVs are input data copied from the main tree, sha256-verified
# against the data commit dd3cc6a blobs.
#
# USAGE   scripts/ktd-julia scratch/sv_reject_sixclass_a76c5e9.jl
# WRITES  scratch/sv_reject_sixclass_a76c5e9.log

using KiteTurbineDynamics
import KiteTurbineDynamics
import Printf
import Dates

const KW = 5.0
const PW = KW * 1000.0
const ELEV = π / 6
const V_RATED = 11.0
const LENGTH = 18.8

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
lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

# The runner's own config (scripts/run_v13_5kw_masslift.jl at a76c5e9).
cfg = ObjectiveConfig(;
    power_W=PW, v_rated=V_RATED,
    p_floor_kw=5.0, p_ceiling_kw=5.0,
    relax_s=10.0, window_s=40.0,
    fos_target=2.5, fos_hard=2.5,
    power_stat=:tail5, penalize_ceiling=false,
    kickstart_s=0.0,
    k_mppt=2.24,
    tether_diameter=p_base.tether_diameter,
    rotor_count_mode=true,
    power_split=0.6,
    cone_slope_deg=22.0,
    rotor_spacing_frac=0.8,
    blocking_factor=0.85^(1 / 3),
    min_wall_m=2e-3,
)

const LIMIT = parse(Int, get(ENV, "SV_LIMIT", "0"))   # 0 = all rows; else classify the first N only (smoke test)
const SHARD = parse(Int, get(ENV, "SV_SHARD", "0"))   # 1-based shard index; 0 = no sharding
const NSHARDS = parse(Int, get(ENV, "SV_NSHARDS", "1"))  # shard count

# ---- load the FoS=Inf reject rows from the three island telemetry CSVs ----
reject_rows = NamedTuple{(:island, :gen, :idx, :x),Tuple{Int,Int,Int,Vector{Float64}}}[]
for isl in 1:3
    f = joinpath("scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_bankderate2",
                 "island_$isl", "telemetry.csv")
    open(f) do io
        lines = readlines(io)
        hdr = split(strip(lines[2]), ',')
        for ln in lines[3:end]
            d = Dict(zip(hdr, split(strip(ln), ',')))
            d["status"] == "reject" || continue
            d["FoS"] == "Inf" || continue
            x = [parse(Float64, d["x$j"]) for j in 1:10]
            push!(reject_rows, (island=isl, gen=parse(Int, d["gen"]),
                                idx=parse(Int, d["idx"]), x=x))
        end
    end
end
@assert length(reject_rows) == 201 "expected 201 FoS=Inf reject rows, got $(length(reject_rows))"

# ---- pre-settle gates (decode only, no ODE) ----
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

# ---- classify one genome with the evaluator's own gates ----
function classify(x::Vector{Float64})
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
        latch[] != :none && return
        sys = ctx.sys
        if any(!isfinite, uc)
            latch[] = :nonfinite
            return
        end
        if !KiteTurbineDynamics.tip_speed_sanity_ok(uc, sys)
            latch[] = :hub_tip
            return
        end
        if t > cfg.relax_s && (t - last_betz[]) >= 1.0
            last_betz[] = t
            ef = KiteTurbineDynamics.capture_extended(
                uc, sys, ctx.pc, t, ctx.wf, ctx.lift_device;
                brake_engaged=sys.brake_engaged[])
            n_er = length(sys.expansion_rotors)
            for (i, pa_kw) in enumerate(ef.rotor_aero_power)
                A_i = if i == 1
                    KiteTurbineDynamics.main_rotor_bank_projected_area(sys)
                elseif i - 1 <= n_er
                    er = sys.expansion_rotors[i - 1]
                    ri = er.ring_idx
                    r_ring = (1 <= ri <= sys.n_ring) ?
                             (sys.nodes[sys.ring_ids[ri]]::RingNode).radius : 0.0
                    KiteTurbineDynamics.expansion_annulus_area(er, r_ring)
                else
                    0.0
                end
                if A_i > 0.0 && !KiteTurbineDynamics.rotor_betz_ok(pa_kw, A_i, cfg.v_rated)
                    latch[] = :betz
                    return
                end
            end
        end
    end

    r = try
        KiteTurbineDynamics.evaluate_windowed(
            xr, beam_profile, p_base, cfg;
            start_mode=:cold,
            lift_device=lift_for,
            trace_callback=tc,
            fitness_fn=(P, F, c, m) -> KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m),
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
        return :settle_fail
    else
        return :under_floor
    end
end

# ---- static split for under_floor rows (no ODE) ----
function static_cp_floor(x::Vector{Float64})
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    x_canon = KiteTurbineDynamics.canonical_v10(xr)
    result = KiteTurbineDynamics.design_from_vector_v10(
        x_canon, beam_profile, p_base;
        power_W=cfg.power_W, v_rated=cfg.v_rated, cylinder_cone=true,
        rotor_count_mode=cfg.rotor_count_mode, power_split=cfg.power_split,
        cone_slope_deg=cfg.cone_slope_deg, rotor_spacing_frac=cfg.rotor_spacing_frac,
        blocking_factor=cfg.blocking_factor, beam_t_over_D=cfg.t_over_D,
    )
    sizing = KiteTurbineDynamics.size_beams_closed_form(result, p_base, cfg)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
        result, 1.0, clamp(cfg.k_mppt, 0.01, KiteTurbineDynamics.K_MPPT_MAX);
        tether_diameter=cfg.tether_diameter, base_params=p_base,
        min_wall_m=cfg.min_wall_m, beam_sizing=sizing,
    )
    return KiteTurbineDynamics.betz_cp_floor_kw(sys, p_base, cfg)
end

function main()
    logname = SHARD > 0 ? "sv_reject_sixclass_a76c5e9_s$(SHARD).log" : "sv_reject_sixclass_a76c5e9.log"
    io = open(joinpath(@__DIR__, logname), "w")
    say(x...) = (println(io, x...); println(x...); flush(io))

    say("sv_reject_sixclass_a76c5e9 — six-class 201-reject re-derivation at the producing commit")
    say("generated: ", Dates.now())
    say("code basis: src/ at commit a76c5e9 (producing commit, 2026-10-07)")
    say("input data: telemetry.csv island 1..3, data commit dd3cc6a, sha256-verified copies")
    say("FoS=Inf reject rows loaded: ", length(reject_rows))
    shard_rows = SHARD > 0 ? [r for (i, r) in enumerate(reject_rows) if mod(i - 1, NSHARDS) == SHARD - 1] : reject_rows
    rows = LIMIT > 0 ? shard_rows[1:LIMIT] : shard_rows
    say("classifying: ", length(rows), " rows (SHARD=", SHARD, "/", NSHARDS, " LIMIT=", LIMIT, ")")

    counts = Dict{Symbol,Int}()
    class_of = Symbol[]
    t_start = time()
    for (k, row) in enumerate(rows)
        reason = try
            classify(row.x)
        catch
            :error
        end
        counts[reason] = get(counts, reason, 0) + 1
        push!(class_of, reason)
        say(Printf.@sprintf("  [%3d/%d] island=%d gen=%d idx=%d  %s",
                            k, length(rows), row.island, row.gen, row.idx, reason))
    end
    say("classification wall: ", round(time() - t_start, digits=1), " s")

    if LIMIT > 0
        say("LIMIT set — smoke test only, census asserts skipped")
        close(io)
        return
    end

    say("")
    say("== raw latch census (pre-split) ==")
    for (reason, n) in sort(collect(counts), by=x -> -x[2])
        say(Printf.@sprintf("  %-16s %d", reason, n))
    end
    SHARD == 0 && @assert sum(values(counts)) == 201

    # ---- static split of the under_floor rows ----
    uf = get(counts, :under_floor, 0)
    say("")
    say("under_floor rows: ", uf)
    say("== static cp-floor split (betz_cp_floor_kw < 0.8 * p_floor) ==")
    cp_values = Float64[]
    n_bcf = 0
    n_bce = 0
    n_err = 0
    for (row, reason) in zip(rows, class_of)
        reason == :under_floor || continue
        cp = try
            static_cp_floor(row.x)
        catch
            -1.0
        end
        if cp < 0.0
            n_err += 1
            say(Printf.@sprintf("SPLIT island=%d gen=%d idx=%d class=error", row.island, row.gen, row.idx))
        elseif cp < cfg.p_floor_kw * 0.8
            n_bcf += 1
            push!(cp_values, cp)
            say(Printf.@sprintf("SPLIT island=%d gen=%d idx=%d class=betz_cp_floor cp_floor=%.9f", row.island, row.gen, row.idx, cp))
        else
            n_bce += 1
            say(Printf.@sprintf("SPLIT island=%d gen=%d idx=%d class=betz_ceiling cp_floor=%.9f", row.island, row.gen, row.idx, cp))
        end
    end
    say("betz_cp_floor: ", n_bcf, " | betz_ceiling: ", n_bce, " | split errors: ", n_err)
    SHARD == 0 && @assert n_bcf + n_bce + n_err == uf
    say("threshold (0.8 * floor): ", cfg.p_floor_kw * 0.8, " kW")
    if !isempty(cp_values)
        say(Printf.@sprintf("cp_floor range (betz_cp_floor class): %.3f .. %.3f kW",
                            minimum(cp_values), maximum(cp_values)))
    end

    say("")
    say("== six-class census (this shard) ==")
    final = Dict{Symbol,Int}(
        :betz_cp_floor => n_bcf,
        :settle_fail => get(counts, :settle_fail, 0),
        :spacing => get(counts, :spacing, 0),
        :rope_break => get(counts, :rope_break, 0),
        :betz_ceiling => n_bce,
        :hub_tip => get(counts, :hub_tip, 0),
    )
    for (reason, n) in sort(collect(final), by=x -> -x[2])
        say(Printf.@sprintf("  %-16s %d", reason, n))
    end
    say("shard six-class total: ", sum(values(final)), " (of ", length(rows), ")")
    if SHARD == 0
        other = sum(values(counts)) - counts[:under_floor] -
                counts[:settle_fail] - counts[:spacing] -
                counts[:rope_break] - counts[:hub_tip]
        say("other latch classes (must be 0): ", other)
        @assert sum(values(final)) == 201
        @assert n_err == 0
        say("SV_REJECT_SIXCLASS_DONE")
    else
        say("SV_SHARD_", SHARD, "_DONE")
    end
    close(io)
end

main()
