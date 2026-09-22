# scratch/probe_cone_state_compare.jl  (v2 — 2026-09-22)
#
# Cross-machine comparison of the bridle-cone state for the three Item 4
# candidates, at TWO states: after settle, and after the 120 s relax walk
# (ld 0.00).  Question: island 1's cone is loaded at settle (~66-88 N/line).
# Does it die during the bow walk?
#
# v1 fix: the bridle filter also caught the cyan sub-seg (bearing -> sky
# anchor); require the far end to be a ring.
#
# Usage: julia --project=. scratch/probe_cone_state_compare.jl [island_dir]
#        (no argument = run all three; one argument = only that island)

using KiteTurbineDynamics, LinearAlgebra, Statistics, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const RESDIR = joinpath(@__DIR__, "..", "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_physlift")
const ONLY = length(ARGS) >= 1 ? ARGS[1] : ""

pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]

function build_and_settle(island_dir)
    csv = joinpath(RESDIR, island_dir, "best_vector.csv")
    p0 = params_at_length(params_daisy(), 18.8, 5.0)
    bf = BLOCKING_WIND_FACTOR_5KW
    xv = [parse(Float64, s) for s in split(strip(read(csv, String)), ",")]
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
    u = settle_to_operational_state(
        sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000)
    return sys, u, pc, lift, wf, dec
end

function print_state(tag, sys, u, pc, lift, wf, dec)
    N, Nr = sys.n_total, sys.n_ring
    @printf("──── %s ────\n", tag)
    du = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du, u, (sys, pc, wf, lift), 0.0)
    accs = [norm(du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N]
    st = [g for g in 1:N if sys.nodes[g] isa RingNode || g == sys.bearing_id ||
                            g == sys.sky_anchor_id]
    @printf("handoff: acc_struct %.2f m/s2  max_force %.2f N\n",
        maximum(accs[g] for g in st), maximum(sys.nodes[g].mass * accs[g] for g in 1:N))

    hub = sys.rotor.node_id
    bear = sys.bearing_id
    s_design = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
    hp = pos(u, hub)
    lat = norm(hp .- dot(hp, s_design) .* s_design)
    err = pos(u, bear) .- hp
    hn = norm(hp)
    eperp = norm(err .- dot(err, hp ./ hn) .* (hp ./ hn))
    @printf("hub lateral from design axis = %.4f m; bearing perp offset = %.4f m\n",
        lat, eperp)

    hub_ri = (sys.nodes[hub]::RingNode).ring_idx
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, hub_ri)
    alpha = @view u[(6N + 1):(6N + Nr)]
    total = 0.0
    n_active_lines = 0
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
        T = ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
        total += T
        T > 1.0 && (n_active_lines += 1)
        @printf("  bridle_l%d: L0=%.5f  L=%.5f  strain=%+.5f  T=%8.3f N\n",
            j, ss.length_0, L, (L - ss.length_0) / ss.length_0, T)
    end
    cyan = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == sys.sky_anchor_id && nb == sys.bearing_id) ||
         (na == sys.bearing_id && nb == sys.sky_anchor_id)) || continue
        L = norm(pos(u, nb) .- pos(u, na))
        cyan += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    @printf("  cone total = %.3f N (%d/%d lines active)   cyan = %.3f N\n",
        total, n_active_lines, pc.n_lines, cyan)
    flush(stdout)
end

function run_island(island_dir)
    sys, u, pc, lift, wf, dec = build_and_settle(island_dir)
    @printf("════ %s  (lines=%d rings=%d n_active=%d r_hub=%.2f) ════\n",
        island_dir, pc.n_lines, sys.n_ring, dec.n_active, dec.design.r_hub)
    print_state("AFTER SETTLE", sys, u, pc, lift, wf, dec)

    dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
    n60 = round(Int, 60.0 / dt)
    for k in 1:2
        KiteTurbineDynamics.run_canonical_sim!(u, sys, pc, wf, n60, dt;
            lift_device=lift, lin_damp=0.0)
        print_state(@sprintf("RELAX +%d s (ld 0.00)", 60 * k), sys, u, pc, lift, wf, dec)
    end
    println()
end

for isd in ("island_1", "island_2", "island_3")
    (ONLY == "" || ONLY == isd) || continue
    run_island(isd)
end
println("=== done ===")
