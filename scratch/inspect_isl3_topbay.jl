# scratch/inspect_isl3_topbay.jl  (v3 — 2026-09-22)
#
# Decisive experiment for the island-3 top-bay 602 kN question.
# v2 established: after settle AND after 30 s of window-style dynamics the top
# bay reads a sane ~510-600 N (no broken flags).  The 602 kN appears only in
# the gate runner's window, i.e. AFTER the full 120 s relax walk.
#
# This version mirrors the runner: settle (n_op=300_000) -> 120 s relax
# (lin_damp=0.05, breaks off) -> 30 s window-style (breaks on), and between
# phases prints the full top-bay geometry:
#   hub/bearing lateral + bearing error + tilt angle used by BOTH force and
#   reader paths; ring 9/10/11 centers, radii, gap; alpha per ring; per-line
#   top-bay reconstructed chord; per-sub-seg L0, reconstructed L, T, broken.
#
# Usage: julia --project=. scratch/inspect_isl3_topbay.jl [island_dir]

using KiteTurbineDynamics, LinearAlgebra, Statistics, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const ISLAND_DIR = length(ARGS) >= 1 ? ARGS[1] : "island_3"
const CSV = joinpath(@__DIR__, "..", "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_physlift", ISLAND_DIR, "best_vector.csv")

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

N, Nr = sys.n_total, sys.n_ring
n_seg = Nr - 1
pos(uu, g) = uu[(3 * (g - 1) + 1):(3 * g)]

u = settle_to_operational_state(
    sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000)
dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
@printf("settle done. dt=%.6e  n_lines(pc)=%d  n_seg=%d\n", dt, pc.n_lines, n_seg)

shaft_of = (uu) -> begin
    hp = pos(uu, sys.rotor.node_id)
    n = norm(hp)
    n > 0.1 ? hp ./ n : [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
end
lat_of = (uu, g) -> begin
    v = pos(uu, g)
    s = shaft_of(uu)
    norm(v .- dot(v, s) .* s)
end

function probe_state(tag::String, uu)
    println("════ $(tag) ════")
    hub = sys.rotor.node_id
    bear = sys.bearing_id
    sd = shaft_of(uu)
    err = pos(uu, bear) .- pos(uu, hub)
    eperp = norm(err .- dot(err, sd) .* sd)
    @printf("hub_lat=%.4f bear_lat=%.4f bearing_err_perp=%.4f m tilt=%.4f rad (%.2f deg)\n",
        lat_of(uu, hub), lat_of(uu, bear), eperp, min(eperp * 0.1, pi / 6),
        rad2deg(min(eperp * 0.1, pi / 6)))
    g10 = sys.ring_ids[Nr - 1]
    g11 = sys.ring_ids[Nr]
    c10 = pos(uu, g10)
    c11 = pos(uu, g11)
    r10 = (sys.nodes[g10]::RingNode).radius
    r11 = (sys.nodes[g11]::RingNode).radius
    @printf("ring10 R=%.4f ctr=(%.4f,%.4f,%.4f)\n", r10, c10...)
    @printf("ring11 R=%.4f ctr=(%.4f,%.4f,%.4f)\n", r11, c11...)
    @printf("centre distance = %.6f m\n", norm(c11 .- c10))
    al = uu[(6N + 1):(6N + Nr)]
    @printf("alpha 9/10/11 = %.4f %.4f %.4f\n", al[Nr - 2], al[Nr - 1], al[Nr])
    hub_gid = hub
    hub_ri = (sys.nodes[hub]::RingNode).ring_idx
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(uu, sys, hub_gid, hub_ri)
    for j in 1:pc.n_lines
        idx = (n_seg - 1) * pc.n_lines * 4 + (j - 1) * 4 + 1
        ss1 = sys.sub_segs[idx]
        ss4 = sys.sub_segs[idx + 3]
        pa = KiteTurbineDynamics.attachment_point(pos(uu, g10), r10, al[Nr - 1],
            j, pc.n_lines, pp1, pp2)
        pb = KiteTurbineDynamics.attachment_point(pos(uu, g11), r11, al[Nr],
            j, pc.n_lines, pp1, pp2)
        @printf("  line %d: chord=%.4f m (L0_bay=%.4f)\n", j, norm(pb .- pa),
            4 * ss1.length_0)
    end
    @printf("broken: sum=%d any=%s\n", sum(sys.broken_lines), sys.any_broken[])
    for j in 1:pc.n_lines, sub in 1:4
        idx = (n_seg - 1) * pc.n_lines * 4 + (j - 1) * 4 + sub
        ss = sys.sub_segs[idx]
        T = KiteTurbineDynamics.get_segment_tension(uu, sys, pc, n_seg, j; sub_idx=sub)
        @printf("  j=%d sub=%d idx=%3d L0=%.6f T=%14.4f impliedL=%.6f brk=%s\n",
            j, sub, idx, ss.length_0, T, ss.length_0 * (1 + T / ss.EA),
            sys.broken_lines[idx] ? "BROKEN" : "-")
    end
    flush(stdout)
end

probe_state("AFTER SETTLE", u)

nrelax = round(Int, 120.0 / dt)
for chunk_s in (60.0, 60.0)
    n = round(Int, chunk_s / dt)
    KiteTurbineDynamics.run_canonical_sim!(u, sys, pc, wf, n, dt;
        lift_device=lift, lin_damp=0.05)
    probe_state(@sprintf("RELAX +%ds (ld 0.05, breaks off)", Int(chunk_s)), u)
end

n30 = round(Int, 30.0 / dt)
KiteTurbineDynamics.run_canonical_sim!(u, sys, pc, wf, n30, dt;
    lift_device=lift, lin_damp=0.05, breaks_enabled=true)
probe_state("WINDOW +30s (breaks on)", u)
println("=== done ===")
