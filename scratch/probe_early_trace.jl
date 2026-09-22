# scratch/probe_early_trace.jl
#
# First-T seconds post-handoff trace at fine cadence (0.05 s) for an Item 4
# candidate.  Adjudicates the "instant bridle collapse" claim: records
# per-line bridle tension, cyan, top bay, hub lateral (design axis) from the
# settle handoff, at lin_damp = 0.0.
#
# Usage: julia --project=. scratch/probe_early_trace.jl <island_dir> [T_s]

using KiteTurbineDynamics, LinearAlgebra, Statistics, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const ISLAND = length(ARGS) >= 1 ? ARGS[1] : "island_1"
const T_S = length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : 20.0
const CAP_DT = 0.05
const RESDIR = joinpath(
    @__DIR__, "..", "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_physlift"
)
const CSV = joinpath(RESDIR, ISLAND, "best_vector.csv")

pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]

p0 = params_at_length(params_daisy(), 18.8, 5.0)
bf = BLOCKING_WIND_FACTOR_5KW
xv = [parse(Float64, s) for s in split(strip(read(CSV, String)), ",")]
xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
xv[10] = Float64(round(Int, clamp(xv[10], 1, 3)))
dec = design_from_vector_v10(xv, PROFILE_ELLIPTICAL, p0; power_W=5000.0,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=bf)
cfg = KiteTurbineDynamics.ObjectiveConfig(;
    power_W=5000.0, v_rated=11.0, p_floor_kw=5.0,
    fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
    rotor_count_mode=true, power_split=0.6, blocking_factor=bf)
sizing = KiteTurbineDynamics.size_beams_closed_form(dec, p0, cfg)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p0.tether_diameter, base_params=p0, min_wall_m=2e-3,
    beam_sizing=sizing)
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
lift = lift_for(sys, pc)
wf = (r, t) -> [p0.v_wind_ref, 0.0, 0.0]
u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift,
    wind_fn=wf, n_op=300_000)
N, Nr = sys.n_total, sys.n_ring
dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
@printf("=== early trace %s  (lines=%d rings=%d n_active=%d)  T=%.0f s  dt=%.4g ===\n",
    ISLAND, pc.n_lines, Nr, dec.n_active, T_S, dt)

hub = sys.rotor.node_id
bear = sys.bearing_id
s_design = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]

function bridle_lines_tension(u)
    hub_ri = (sys.nodes[hub]::RingNode).ring_idx
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, hub_ri)
    alpha = @view u[(6N + 1):(6N + Nr)]
    out = zeros(pc.n_lines)
    for ss in sys.sub_segs
        ss.end_a.node_id == sys.bearing_id || continue
        ss.end_b.is_ring || continue
        j = ss.end_a.line_idx
        ra = pos(u, ss.end_a.node_id)
        node_b = sys.nodes[ss.end_b.node_id]::RingNode
        rb = KiteTurbineDynamics.attachment_point(
            pos(u, ss.end_b.node_id), node_b.radius, alpha[node_b.ring_idx],
            ss.end_b.line_idx, pc.n_lines, pp1, pp2)
        L = norm(rb .- ra)
        out[j] = ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    return out
end

function cyan_tension(u)
    t = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == sys.sky_anchor_id && nb == sys.bearing_id) ||
         (na == sys.bearing_id && nb == sys.sky_anchor_id)) || continue
        L = norm(pos(u, nb) .- pos(u, na))
        t += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    return t
end

topbay(u) = sum(KiteTurbineDynamics.get_segment_tension(u, sys, pc, Nr - 1, j)
                for j in 1:pc.n_lines) / pc.n_lines

hub_lat(u) = begin
    hp = pos(u, hub)
    norm(hp .- dot(hp, s_design) .* s_design)
end

nsteps = round(Int, T_S / dt)
cap_every = max(1, round(Int, CAP_DT / dt))
nc = Ref(0)
csvpath = joinpath(@__DIR__, "..", ".julia_depot", "logs", "early_$(ISLAND).csv")
io = open(csvpath, "w")
println(io, "t,bridle_l1,bridle_l2,bridle_l3,cyan,topbay,hub_lat")
last_print = Ref(-1.0)
cb(u_, t_, step_) = begin
    if step_ % cap_every == 0
        nc[] += 1
        bl = bridle_lines_tension(u_)
        cy = cyan_tension(u_)
        tb = topbay(u_)
        hl = hub_lat(u_)
        @printf(io, "%.3f,%.4f,%.4f,%.4f,%.4f,%.4f,%.5f\n", t_, bl[1], bl[2], bl[3], cy, tb, hl)
        if t_ - last_print[] >= 1.0
            last_print[] = t_
            @printf("t=%5.1f  bridle=(%6.1f %6.1f %6.1f)  cyan=%6.1f  topbay=%6.1f  hub_lat=%.4f\n",
                t_, bl[1], bl[2], bl[3], cy, tb, hl)
            flush(stdout)
        end
    end
    return nothing
end

t0 = time()
KiteTurbineDynamics.run_canonical_sim!(u, sys, pc, wf, nsteps, dt;
    lift_device=lift, lin_damp=0.0, callback=cb)
close(io)
@printf("ran %.0f s in %.1f s wall; %d samples; csv=%s\n", T_S, time() - t0, nc[], csvpath)
println("=== done ===")
