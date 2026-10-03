#!/usr/bin/env julia
# scratch/hermes_winner_pack.jl — Hermes, 2026-10-02
#
# Rod's room request: for every island winner, present
#   (1) a component breakdown of the winning score, and
#   (2) a 3D and a 2D figure of the winning device for visual interrogation.
#
# 2026-10-02 revision (evg request): the tensile lines are now drawn in both
# figures — "would be good to see the lines there too".  TRPT shaft lines,
# bridles, cyan line, backline, and the lift kite at its steady elevation are
# all taken straight off the built system state (u0); nothing is re-derived.
#
# Score decomposition follows scratch/sv_probe_score_accounting.jl; the mass
# sub-terms follow scratch/av_probe_mass_terms.jl.  The LIVE scorer on the
# campaign path is `appropriate_mass_fitness` (run_v13_5kw_masslift.jl:265);
# the runner comment there names mass_min_fitness — the mismatch is recorded
# by the software-validator probe.
#
# TWIST NOTE (2026-10-02, corrected): the over-twist charge is LIVE.  It is not
# `appropriate_mass_fitness`'s twist_ratio keyword (the runner's 4-arg seam call
# leaves that at 0.0); it is added AFTER the seam in
# objective_evaluator.jl:1132-1134 as W_TWIST_KG·(tr/(1−tr))², using the ODE
# window's twist_ratio_max.  So the recorded fitness − (mass + over-power +
# utilisation) is the twist charge (stationarity ≈ 0 for these winners).  This
# script now prints it explicitly and back-computes the window's twist_ratio.
#
# No ODE.  Decode + build + render only.
#
# USAGE: scripts/ktd-julia scratch/hermes_winner_pack.jl [campaign_dir] [island]

using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics
using LinearAlgebra
using CairoMakie

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const CAMPAIGN = length(ARGS) >= 1 ? ARGS[1] :
    joinpath(ROOT, "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_bankderate")
const OUTDIR = joinpath(CAMPAIGN, "report")
mkpath(OUTDIR)

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const LENGTH = 18.8
const BF = BLOCKING_WIND_FACTOR_5KW
const P_CEIL = 5.0
const FOS_HARD = 2.5

# ── params at length (mirrors run_v13_5kw_masslift.jl + today's probes) ──────
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

const P_BASE = params_at_length(LENGTH)

# ── telemetry reader (manual — the file carries NaN/Inf as text) ─────────────
function parse_telemetry(path::String)
    lines = readlines(path)
    hdr = startswith(lines[1], "#") ? lines[2] : lines[1]
    dstart = startswith(lines[1], "#") ? 3 : 2
    header = split(hdr, ",")
    colidx = Dict(n => findfirst(==(n), header) for n in
        ("gen", "idx", "fitness", "status", "P_end", "FoS", "clearance",
         "n_lines", "rings", "n_active", "r_hub", "r_bot", "bank_top", "bank_bot",
         "blade_scale_top", "blade_scale_bottom", "twist_ratio"))
    rows = NamedTuple[]
    for ln in lines[dstart:end]
        isempty(strip(ln)) && continue
        f = split(ln, ",")
        length(f) < length(header) && continue
        push!(rows, (
            gen=parse(Int, f[colidx["gen"]]),
            idx=parse(Int, f[colidx["idx"]]),
            fitness=parse(Float64, f[colidx["fitness"]]),
            status=String(f[colidx["status"]]),
            p_end=parse(Float64, f[colidx["P_end"]]),
            fos=parse(Float64, f[colidx["FoS"]]),
            clearance=parse(Float64, f[colidx["clearance"]]),
            n_lines=parse(Int, f[colidx["n_lines"]]),
            rings=parse(Int, f[colidx["rings"]]),
            n_active=parse(Int, f[colidx["n_active"]]),
            r_hub=parse(Float64, f[colidx["r_hub"]]),
            r_bot=parse(Float64, f[colidx["r_bot"]]),
            twist_ratio=(ci = colidx["twist_ratio"]; ci === nothing ? NaN : parse(Float64, f[ci])),
            x=[parse(Float64, f[findfirst(==("x$j"), header)]) for j in 1:10],
        ))
    end
    return rows
end

# ── discrete-gene rounding (length-aware: sv_probe_escalation.jl correction) ─
function round_discrete!(x::Vector{Float64})
    xr = copy(x)
    if length(xr) >= 14
        xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))   # legacy n_lines
        xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))  # legacy rotor count
    else
        xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))   # canonical n_lines
        xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))    # canonical rotor count
    end
    return xr
end

# ── mass sub-terms (same decomposition as scratch/av_probe_mass_terms.jl) ────
function mass_terms(sys, pobj)
    m_tether = pobj.n_lines * pobj.tether_length *
               (KTD.DYNEEMA_DENSITY * π * (pobj.tether_diameter / 2)^2)
    m_rings = sys.ring_mass_total[] > 0.0 ? sys.ring_mass_total[] : (sys.n_ring - 1) * pobj.m_ring
    m_blades = pobj.n_blades * pobj.m_blade
    m_expansion = sum(er -> er.mass, sys.expansion_rotors; init=0.0)
    n_blade_nodes = pobj.n_blades + sum(er -> er.n_blades, sys.expansion_rotors; init=0)
    m_knuckles = n_blade_nodes * KTD.OPT_KNUCKLE_MASS_KG + sys.ring_knuckle_mass[]
    return (; m_tether, m_rings, m_blades, m_expansion, m_knuckles, m_lifter=5.0)
end

# ── geometry prep (from the BUILT system, as preview_genome_geometry.jl) ─────
function prep_geometry(dec, sys, u0, pc)
    pos(id) = u0[(3 * (id - 1) + 1):(3 * id)]
    centers = [pos(id) for id in sys.ring_ids]
    radii = [(sys.nodes[id]::RingNode).radius for id in sys.ring_ids]
    shaft = normalize(centers[end] .- centers[1])
    s = [dot(c .- centers[1], shaft) for c in centers]
    t_start = dec.taper_start_z
    t_harv = dec.design.tether_length - dec.harvest_length
    section = map(s) do si
        si <= t_start + 1e-6 ? :transmission : (si >= t_harv - 1e-6 ? :harvest : :cone)
    end
    rotors = NamedTuple[]
    push!(rotors, (ring_idx=length(sys.ring_ids), r_out=sys.rotor.radius,
                   r_in=sys.rotor.blade_hub_radius, is_hub=true))
    for er in sys.expansion_rotors
        r_ring = radii[er.ring_idx]
        push!(rotors, (ring_idx=er.ring_idx, r_out=r_ring + er.blade_tip_radius,
                       r_in=max(r_ring + er.blade_hub_radius, 0.0), is_hub=false))
    end

    # ── tensile line elements, straight off the built state (u0) ─────────────
    # Rope polylines reuse the dashboard's _rope_line_pts, so the drawn
    # attachments are exactly the built ones (same α + ring basis path).
    Nn = sys.n_total
    rotor_ri = (sys.nodes[sys.rotor.node_id]::RingNode).ring_idx
    pp1, pp2 = KTD._tilted_ring_basis(u0, sys, sys.rotor.node_id, rotor_ri)
    ring_angle(ri) = u0[6 * Nn + ri]
    hub_id = sys.ring_ids[end]
    hub_node = sys.nodes[hub_id]::RingNode
    ctr_hub = pos(hub_id)
    ropes = [KTD._rope_line_pts(u0, sys, pc, seg, j)
             for seg in 1:(sys.n_ring - 1) for j in 1:pc.n_lines]
    bridles = [(KTD.attachment_point(ctr_hub, hub_node.radius,
                                     ring_angle(hub_node.ring_idx), j, pc.n_lines, pp1, pp2),
                copy(pos(sys.bearing_id))) for j in 1:pc.n_lines]
    cyan_line = (copy(pos(sys.bearing_id)), copy(pos(sys.sky_anchor_id)))
    back_ax = pc.tether_length * cos(pc.elevation_angle) + pc.back_anchor_fwd_x
    backline = (copy(pos(sys.sky_anchor_id)), [back_ax, 0.0, 0.0])
    ground_anchor = [back_ax, 0.0, 0.0]
    # Lift kite — steady-lift schematic (dashboard-v2 convention, v_ref = 11 m/s).
    kite = try
        ld = KTD.sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
        sw = copy(pos(sys.sky_anchor_id))
        sh = sw ./ max(norm(sw), 1e-6)
        sh_h = [sh[1], sh[2], 0.0]
        sh_h = sh_h ./ max(norm(sh_h), 1e-6)
        _, _, elev_deg = KTD.lift_force_steady(ld, pc.rho, 11.0)
        th = deg2rad(clamp(elev_deg, 5.0, 89.0))
        ll = ld isa KTD.SingleKiteParams ? ld.line_length :
             (ld isa KTD.StackedKitesParams ? ld.spacing * ld.n_kites : ld.line_length)
        sw .+ ll .* (sh_h .* cos(th) .+ [0.0, 0.0, sin(th)])
    catch err
        @warn "lifter schematic position not computed — drawing without the kite" err
        nothing
    end
    return (; centers, radii, shaft, s, section, rotors, t_start, t_harv,
            ropes, bridles, cyan_line, backline, kite,
            bearing=copy(pos(sys.bearing_id)), sky_anchor=copy(pos(sys.sky_anchor_id)),
            ground_anchor)
end

const SECTION_COLOR = Dict(
    :transmission => RGBf(0.12, 0.56, 1.00),
    :cone => RGBf(1.00, 0.55, 0.00),
    :harvest => RGBf(0.18, 0.55, 0.34),
)
const ROTOR_COLOR  = RGBf(0.70, 0.13, 0.13)
const ROPE_COLOR   = RGBf(0.42, 0.45, 0.50)   # TRPT shaft lines
const BRIDLE_COLOR = RGBf(0.80, 0.60, 0.10)   # gold bridles
const CYAN_COLOR   = RGBf(0.00, 0.68, 0.80)   # cyan line / sky chain
const BACK_COLOR   = RGBf(0.55, 0.55, 0.55)   # backline

function circle_pts(center, radius, shaft_dir; n=48)
    e2 = cross(shaft_dir, [0.0, 1.0, 0.0])
    if norm(e2) < 1e-9
        e2 = cross(shaft_dir, [1.0, 0.0, 0.0])
    end
    normalize!(e2)
    e1 = cross(e2, shaft_dir)
    normalize!(e1)
    t = range(0, 2π; length=n + 1)
    x = [center[1] + radius * (cos(θ) * e1[1] + sin(θ) * e2[1]) for θ in t]
    y = [center[2] + radius * (cos(θ) * e1[2] + sin(θ) * e2[2]) for θ in t]
    z = [center[3] + radius * (cos(θ) * e1[3] + sin(θ) * e2[3]) for θ in t]
    return (x, y, z)
end

function render_3d(path::String, g, title::String, mstr::String)
    fig = Figure(size=(1000, 800))
    ax = Axis3(fig[1, 1]; xlabel="x (m)", ylabel="y (m)", zlabel="z (m)", title=title)
    for i in eachindex(g.radii)
        c = g.s[i] .* g.shaft
        x, y, z = circle_pts(c, g.radii[i], g.shaft)
        lines!(ax, x, y, z; color=SECTION_COLOR[g.section[i]], linewidth=2.2)
    end
    x, y, z = circle_pts(g.s[1] .* g.shaft, g.radii[1], g.shaft)
    lines!(ax, x, y, z; color=:black, linewidth=4.0)        # ground ring
    for rt in g.rotors
        c = g.s[rt.ring_idx] .* g.shaft
        xo, yo, zo = circle_pts(c, rt.r_out, g.shaft)
        lines!(ax, xo, yo, zo; color=ROTOR_COLOR, linewidth=2.0)
        xi, yi, zi = circle_pts(c, rt.r_in, g.shaft)
        lines!(ax, xi, yi, zi; color=ROTOR_COLOR, linestyle=:dash)
    end
    # ── tensile lines, as-built (the room's ask) ─────────────────────────────
    for (xs, ys, zs) in g.ropes
        lines!(ax, xs, ys, zs; color=ROPE_COLOR, linewidth=0.7)
    end
    for (pa, pb) in g.bridles
        lines!(ax, [pa[1], pb[1]], [pa[2], pb[2]], [pa[3], pb[3]];
               color=BRIDLE_COLOR, linewidth=1.0)
    end
    let (pa, pb) = g.cyan_line
        lines!(ax, [pa[1], pb[1]], [pa[2], pb[2]], [pa[3], pb[3]];
               color=CYAN_COLOR, linewidth=1.4)
    end
    let (pa, pb) = g.backline
        lines!(ax, [pa[1], pb[1]], [pa[2], pb[2]], [pa[3], pb[3]];
               color=BACK_COLOR, linewidth=1.2)   # solid: 3D dash rendering is unreliable
    end
    if g.kite !== nothing
        let (pa, pb) = (g.sky_anchor, g.kite)
            lines!(ax, [pa[1], pb[1]], [pa[2], pb[2]], [pa[3], pb[3]];
                   color=CYAN_COLOR, linewidth=1.2)   # solid (3D dashes unreliable)
        end
        # Kite marker drawn as a line asterisk: screen-space scatter/mesh markers
        # at this position do not render in CairoMakie 3D (probe: scratch/star_test*.png),
        # but line primitives always do.
        kx, ky, kz = g.kite
        ak = 1.4
        lines!(ax, [kx - ak, kx + ak], [ky, ky], [kz, kz]; color=CYAN_COLOR, linewidth=1.6)
        lines!(ax, [kx, kx], [ky - ak, ky + ak], [kz, kz]; color=CYAN_COLOR, linewidth=1.6)
        lines!(ax, [kx, kx], [ky, ky], [kz - ak, kz + ak]; color=CYAN_COLOR, linewidth=1.6)
    end
    scatter!(ax, [g.bearing[1]], [g.bearing[2]], [g.bearing[3]];
             color=:white, marker=:diamond, markersize=10, strokewidth=1.2, strokecolor=:black)
    scatter!(ax, [g.sky_anchor[1]], [g.sky_anchor[2]], [g.sky_anchor[3]];
             color=CYAN_COLOR, markersize=9)
    # Ground-anchor marker as a line asterisk (same reason as the kite note above).
    ga = g.ground_anchor
    ag = 0.9
    lines!(ax, [ga[1] - ag, ga[1] + ag], [ga[2], ga[2]], [ga[3], ga[3]]; color=:grey30, linewidth=1.5)
    lines!(ax, [ga[1], ga[1]], [ga[2] - ag, ga[2] + ag], [ga[3], ga[3]]; color=:grey30, linewidth=1.5)
    lines!(ax, [ga[1], ga[1]], [ga[2], ga[2]], [ga[3] - ag, ga[3] + ag]; color=:grey30, linewidth=1.5)
    smax = maximum(g.s)
    for b in (g.t_start, g.t_harv)
        (b <= 0.0 || b >= smax) && continue
        pb = b .* g.shaft
        scatter!(ax, [pb[1]], [pb[2]], [pb[3]]; color=:black, markersize=8)
    end
    ax.aspect = :data
    fig[2, 1] = Label(fig, mstr; fontsize=11, tellwidth=false)
    save(path, fig)
    return path
end

function render_2d(path::String, g, title::String, mstr::String)
    fig = Figure(size=(820, 1000))
    ax = Axis(fig[1, 1]; xlabel="radius (m)", ylabel="distance along shaft (m)",
              title=title, aspect=DataAspect())
    smax = maximum(g.s)
    lines!(ax, [0.0, 0.0], [0.0, smax]; color=:grey, linewidth=1.0, linestyle=:dash)
    for i in eachindex(g.radii)
        r = g.radii[i]
        si = g.s[i]
        lines!(ax, [-r, r], [si, si]; color=SECTION_COLOR[g.section[i]], linewidth=3.0)
    end
    lines!(ax, [-g.radii[1], g.radii[1]], [g.s[1], g.s[1]]; color=:black, linewidth=5.0)
    for rt in g.rotors
        si = g.s[rt.ring_idx]
        lines!(ax, [-rt.r_out, -rt.r_in], [si, si]; color=ROTOR_COLOR, linewidth=7.0)
        lines!(ax, [rt.r_in, rt.r_out], [si, si]; color=ROTOR_COLOR, linewidth=7.0)
    end
    # ── tensile lines, projected into the shaft frame (signed radius) ────────
    c1 = g.centers[1]
    sh = g.shaft
    side = normalize(cross([0.0, 1.0, 0.0], sh))
    function proj2(px, py, pz)
        dx = px - c1[1]; dy = py - c1[2]; dz = pz - c1[3]
        si = dx * sh[1] + dy * sh[2] + dz * sh[3]
        rx = dx - si * sh[1]; ry = dy - si * sh[2]; rz = dz - si * sh[3]
        return (rx * side[1] + ry * side[2] + rz * side[3], si)
    end
    for (xs, ys, zs) in g.ropes
        q = [proj2(xs[i], ys[i], zs[i]) for i in eachindex(xs)]
        lines!(ax, [t[1] for t in q], [t[2] for t in q]; color=ROPE_COLOR, linewidth=0.7)
    end
    for (pa, pb) in g.bridles
        qa = proj2(pa[1], pa[2], pa[3]); qb = proj2(pb[1], pb[2], pb[3])
        lines!(ax, [qa[1], qb[1]], [qa[2], qb[2]]; color=BRIDLE_COLOR, linewidth=1.0)
    end
    let (pa, pb) = g.cyan_line
        qa = proj2(pa[1], pa[2], pa[3]); qb = proj2(pb[1], pb[2], pb[3])
        lines!(ax, [qa[1], qb[1]], [qa[2], qb[2]]; color=CYAN_COLOR, linewidth=1.4)
    end
    let (pa, pb) = g.backline
        qa = proj2(pa[1], pa[2], pa[3]); qb = proj2(pb[1], pb[2], pb[3])
        lines!(ax, [qa[1], qb[1]], [qa[2], qb[2]]; color=BACK_COLOR, linewidth=1.0, linestyle=:dash)
    end
    if g.kite !== nothing
        let (pa, pb) = (g.sky_anchor, g.kite)
            qa = proj2(pa[1], pa[2], pa[3]); qb = proj2(pb[1], pb[2], pb[3])
            lines!(ax, [qa[1], qb[1]], [qa[2], qb[2]]; color=CYAN_COLOR, linewidth=1.0, linestyle=:dashdot)
        end
        let qk = proj2(g.kite[1], g.kite[2], g.kite[3])
            scatter!(ax, [qk[1]], [qk[2]]; color=CYAN_COLOR, marker=:star5, markersize=15,
                     strokewidth=1.2, strokecolor=:white)
        end
    end
    let qb = proj2(g.bearing[1], g.bearing[2], g.bearing[3])
        scatter!(ax, [qb[1]], [qb[2]]; color=:white, marker=:diamond, markersize=9,
                 strokewidth=1.2, strokecolor=:black)
    end
    let qs = proj2(g.sky_anchor[1], g.sky_anchor[2], g.sky_anchor[3])
        scatter!(ax, [qs[1]], [qs[2]]; color=CYAN_COLOR, markersize=8)
    end
    for b in (g.t_start, g.t_harv)
        (b > 0.0 && b < smax) && hlines!(ax, b; color=:grey, linestyle=:dot, linewidth=1.0)
    end
    fig[2, 1] = Label(fig, mstr; fontsize=11, tellwidth=false)
    save(path, fig)
    return path
end

# ══════════════════════════════════════════════════════════════════════════════
# Main — per island
# ══════════════════════════════════════════════════════════════════════════════
islands = sort([
    parse(Int, m.captures[1]) for d in readdir(CAMPAIGN)
    for m in [match(r"^island_(\d+)$", d)]
    if m !== nothing && isdir(joinpath(CAMPAIGN, d))
])
length(ARGS) >= 2 && (islands = [parse(Int, ARGS[2])])

println("═"^78)
println("  winner pack — campaign: $CAMPAIGN")
println("  islands: $islands   output: $OUTDIR")
println("═"^78)

for isl in islands
    idir = joinpath(CAMPAIGN, "island_$isl")
    genfile = joinpath(idir, "island_$(isl)_best.csv")
    metafile = joinpath(idir, "island_$(isl)_best_meta.txt")
    telefile = joinpath(idir, "telemetry.csv")
    if !(isfile(genfile) && isfile(metafile) && isfile(telefile))
        @warn "skip island $isl — missing files"
        continue
    end

    xraw = parse.(Float64, split(strip(read(genfile, String)), ","))
    metaline = chomp(read(metafile, String))
    fit_meta = parse(Float64, match(r"fitness=([0-9.eE+-]+)", metaline).captures[1])
    fg = match(r"found_gen=(\d+)", metaline)
    found_gen = fg === nothing ? -1 : parse(Int, fg.captures[1])

    rows = parse_telemetry(telefile)
    xr6 = round.(xraw, digits=6)
    best_row = nothing
    for r in rows
        if abs(r.fitness - fit_meta) <= 6e-4 && all(abs.(r.x .- xr6) .< 1e-6)
            best_row = r
            break
        end
    end
    if best_row === nothing
        @warn "island $isl — no telemetry row matches the best genome; skipping figures"
        continue
    end

    xesc = round_discrete!(xraw)
    dec = design_from_vector_v10(xesc, PROFILE_ELLIPTICAL, P_BASE; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=BF)
    cfg = KTD.ObjectiveConfig(;
        power_W=PW, v_rated=V_RATED, p_floor_kw=KW, fos_target=FOS_HARD, fos_hard=FOS_HARD,
        min_wall_m=2e-3, t_over_D=0.055,
        rotor_count_mode=true, power_split=0.6, blocking_factor=BF,
    )
    sizing = KTD.size_beams_closed_form(dec, P_BASE, cfg)
    sys, u0, pc = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=P_BASE.tether_diameter, base_params=P_BASE, min_wall_m=2e-3,
        beam_sizing=sizing)

    m_eval = KTD.expansion_airborne_mass(sys, pc)
    m_nolift = KTD.expansion_airborne_mass(sys, pc; include_lifter=false)
    t = mass_terms(sys, pc)

    P_score = best_row.p_end
    FoS = best_row.fos
    c_over = KTD.W_OVERPOWER_KG_PER_KW2 * max(P_score - P_CEIL, 0.0)^2
    c_util = KTD.W_UTILISATION_KG * (FOS_HARD / FoS)^2
    # Twist charge.  appropriate_mass_fitness's twist_ratio keyword is left at its
    # 0.0 default by the runner's 4-arg seam call, but objective_evaluator.jl:1132-1134
    # adds W_TWIST_KG·(tr/(1−tr))² AFTER the seam using the ODE window's
    # twist_ratio_max — so the twist channel is LIVE for every objective, not dead.
    # It is the only post-seam term besides stationarity (≈0 for these winners), so
    # the recorded fitness − (mass + over-power + utilisation) is exactly the twist
    # charge.  Prefer the exact window ratio now logged in telemetry
    # (r.twist_ratio, added 2026-10-02); fall back to back-computing it from the
    # fitness residual for telemetry files that predate that column (monotonic in tr).
    tr_logged = best_row.twist_ratio
    if isfinite(tr_logged)
        tr = tr_logged
        c_twist = KTD.W_TWIST_KG * (min(tr, 1.0) / max(1.0 - tr, 1e-6))^2
    else
        c_twist = fit_meta - m_eval - c_over - c_util
        tr = c_twist > 0.0 ? sqrt(c_twist / KTD.W_TWIST_KG) / (1.0 + sqrt(c_twist / KTD.W_TWIST_KG)) : 0.0
    end
    mass = m_eval                       # evaluator charges m_airborne = expansion_airborne_mass(sys, pc)
    pen = c_over + c_util + c_twist
    resid = fit_meta - (mass + pen)     # 0 by construction when twist is back-computed;
                                        # CSV P_end/FoS rounding when twist is logged
    pct(x) = 100.0 * x / fit_meta

    hub = dec.rotors[argmax([r.ring_idx for r in dec.rotors])]

    # ── print + write ────────────────────────────────────────────────────
    println()
    println("── island $isl winner ──────────────────────────────────────────")
    @printf("  fitness  = %.6f (meta)   recorded %.3f  found_gen %s of gen 30\n",
        fit_meta, best_row.fitness, fg === nothing ? "?" : string(found_gen))
    @printf("  recorded row: gen %d idx %d  status=%s\n", best_row.gen, best_row.idx, best_row.status)
    println("  decoded machine: n_lines=$(dec.design.n_lines)  rings=$(dec.n_rings)  n_active=$(dec.n_active)  ",
        "rotors=$(length(dec.rotors))  r_hub=$(round(dec.design.r_hub, digits=3)) m  r_bot=$(round(dec.design.r_bottom, digits=3)) m  ",
        "hub bank=$(round(hub.bank_angle_deg, digits=2))°  hub λ=$(round(hub.blade_scale, digits=3))")
    @printf("  score split: mass %.3f (%.1f%%) + over-power %.3f (%.1f%%) + twist %.3f (%.1f%%, ratio %.3f) + utilisation %.3f (%.1f%%) = %.3f kg-eq\n",
        mass, pct(mass), c_over, pct(c_over), c_twist, pct(c_twist), tr, c_util, pct(c_util), mass + pen)
    @printf("  P_end(tail5)=%.2f kW  FoS=%.2f  clearance=%.2f m\n", P_score, FoS, best_row.clearance)
    @printf("  masses (evaluator build path): expansion_airborne_mass(sys,pc)=%.4f kg (with lifter)  %.4f kg (no lifter)\n",
        m_eval, m_nolift)
    @printf("    sub-terms: tether %.3f + rings %.3f + blades %.3f + expansion %.3f + knuckles %.3f + lifter %.3f\n",
        t.m_tether, t.m_rings, t.m_blades, t.m_expansion, t.m_knuckles, t.m_lifter)

    g = prep_geometry(dec, sys, u0, pc)
    @printf("  lines drawn: %d rope polylines (%d lines × %d segments) · %d bridles · kite %s\n",
        length(g.ropes), pc.n_lines, sys.n_ring - 1, length(g.bridles),
        g.kite === nothing ? "NOT drawn" : "drawn (steady-lift schematic)")
    mstr = @sprintf(
        "score %.3f kg-eq = mass %.3f + over-power %.3f + twist %.3f (ratio %.2f) + utilisation %.3f\nP_end %.2f kW · FoS %.2f · clearance %.2f m · n_lines %d · rings %d · rotors %d · hub bank %.2f° (not drawn)\nshaft %.1f m at 30° · rings: blue/orange/green = transmission/cone/harvest, red = rotor annulus\nlines (as built): grey = %d TRPT lines/segment · gold = bridles · sky-blue = cyan line · grey = backline (dashed in 2D) · kite at top of lift line (schematic)",
        fit_meta, mass, c_over, c_twist, tr, c_util, P_score, FoS, best_row.clearance,
        dec.design.n_lines, dec.n_rings, length(dec.rotors), hub.bank_angle_deg, LENGTH,
        dec.design.n_lines)
    p3d = render_3d(joinpath(OUTDIR, "island_$(isl)_winner_3d.png"), g,
        "island $isl winner — built ODE geometry (3D)", mstr)
    p2d = render_2d(joinpath(OUTDIR, "island_$(isl)_winner_2d.png"), g,
        "island $isl winner — elevation (2D)", mstr)
    println("  figures: $p3d")
    println("           $p2d")

    # breakdown txt —
    telfile_hdr = readlines(telefile)[1]
    era = (m = match(r"era=(\S+)", telfile_hdr); m === nothing ? "?" : m.captures[1])
    git = (m = match(r"git=(\S+)", telfile_hdr); m === nothing ? "?" : m.captures[1])
    open(joinpath(OUTDIR, "island_$(isl)_score_breakdown.txt"), "w") do io
        println(io, "# island $isl winner — score breakdown")
        println(io, "campaign: $(basename(CAMPAIGN))")
        println(io, "generated by scratch/hermes_winner_pack.jl (2026-10-02; regenerated 2026-10-03 for D1 site-wind sizing, Hermes desktop)")
        println(io, "provenance: era=$era  telemetry git=$git")
        println(io, "")
        println(io, "meta: gen=30 found_gen=$(fg === nothing ? "?" : string(found_gen)) fitness=$fit_meta")
        println(io, "recorded row: gen $(best_row.gen) idx $(best_row.idx) fitness=$(best_row.fitness) status=$(best_row.status)")
        println(io, "genome (10-D): $(join(xraw, ","))")
        println(io, "")
        println(io, "decoded machine: n_lines=$(dec.design.n_lines) rings=$(dec.n_rings) n_active=$(dec.n_active) ",
            "rotors=$(length(dec.rotors)) r_hub=$(dec.design.r_hub) r_bot=$(dec.design.r_bottom) ",
            "hub bank=$(hub.bank_angle_deg)° hub λ=$(hub.blade_scale)")
        println(io, "recorded decode cross-check: n_lines $(dec.design.n_lines == best_row.n_lines ? "ok" : "MISMATCH")",
            " rings $(dec.n_rings == best_row.rings ? "ok" : "MISMATCH")",
            " n_active $(dec.n_active == best_row.n_active ? "ok" : "MISMATCH")",
            " r_hub $(isapprox(dec.design.r_hub, best_row.r_hub; atol=1e-3) ? "ok" : "MISMATCH")",
            " r_bot $(isapprox(dec.design.r_bottom, best_row.r_bot; atol=1e-3) ? "ok" : "MISMATCH")")
        println(io, "")
        println(io, "SCORE DECOMPOSITION — live scorer: appropriate_mass_fitness (src/objective_v12.jl:145-168)")
        println(io, "  twist is charged post-seam by objective_evaluator.jl:1132-1134 (W_TWIST_KG·(tr/(1−tr))²,")
        println(io, "  using the window's twist_ratio_max), NOT via the fitness kwarg (left at 0.0 by the runner).")
        @printf(io, "  fitness          = %.4f kg-eq\n", fit_meta)
        @printf(io, "  = mass           : %10.4f kg  (%.1f%%)   expansion_airborne_mass(sys, pc)\n", mass, pct(mass))
        @printf(io, "  + over-power     : %10.4f kg  (%.1f%%)   W_OVERPOWER=%.1f · max(P_end %.2f − %.1f, 0)²\n", c_over, pct(c_over), KTD.W_OVERPOWER_KG_PER_KW2, P_score, P_CEIL)
        @printf(io, "  + over-twist     : %10.4f kg  (%.1f%%)   W_TWIST=%.1f · (tr/(1−tr))²  → window twist_ratio ≈ %.3f\n", c_twist, pct(c_twist), KTD.W_TWIST_KG, tr)
        @printf(io, "  + utilisation    : %10.4f kg  (%.1f%%)   W_UTILISATION=%.1f · (%.1f / FoS %.2f)²\n", c_util, pct(c_util), KTD.W_UTILISATION_KG, FOS_HARD, FoS)
        @printf(io, "  (weights src/objective_v12.jl:114-116; hard gates: P ≥ %.1f kW, FoS ≥ %.1f)\n", P_CEIL, FOS_HARD)
        println(io, "")
        println(io, "MASS CROSS-CHECK — evaluator build path (mirrors scratch/av_probe_mass_terms.jl)")
        @printf(io, "  expansion_airborne_mass(sys, pc)                       = %.4f kg   [what objective_evaluator.jl:1082 charges]\n", m_eval)
        @printf(io, "  expansion_airborne_mass(sys, pc; include_lifter=false) = %.4f kg\n", m_nolift)
        @printf(io, "  sub-terms: tether %.4f + rings %.4f + blades %.4f + expansion %.4f + knuckles %.4f + lifter %.4f (hard-coded, expansion_analysis.jl:74)\n",
            t.m_tether, t.m_rings, t.m_blades, t.m_expansion, t.m_knuckles, t.m_lifter)
        @printf(io, "  twist source    : %s\n", isfinite(tr_logged) ? "logged window twist_ratio" : "back-computed from fitness residual")
        @printf(io, "  closure         : fitness − (mass + over-power + twist + utilisation) = %+.4f kg  [CSV P_end/FoS rounding; 0 by construction when back-computed]\n", resid)
        println(io, "")
        println(io, "BETZ BASIS — ZY wind-plane projection of the swept frustum (basis per Rod, 2026-10-02)")
        A_ax = try KTD.main_rotor_swept_area(sys)
               catch; π * (sys.rotor.radius^2 - sys.rotor.blade_hub_radius^2) end
        zf = abs(dot(g.shaft, [1.0, 0.0, 0.0]))
        @printf(io, "  A_axial = main_rotor_swept_area(sys) = %.4f m²   (π(r_out² − r_in²); r_out %.4f / r_in %.4f)\n",
            A_ax, sys.rotor.radius, sys.rotor.blade_hub_radius)
        @printf(io, "  |ŝ·x̂|   = cos(shaft elevation vs wind axis) = %.5f   (from the built shaft direction)\n", zf)
        @printf(io, "  A_ZY    = A_axial·|ŝ·x̂| = %.4f m²   ← Betz-relevant power basis (full blade spans, outer→inner tip sweep; pending @aero confirmation)\n",
            A_ax * zf)
        println(io, "")
        println(io, "FIGURES (2026-10-02 revision — tensile lines now drawn)")
        println(io, "  island_$(isl)_winner_3d.png — built ODE geometry: rings, rotors, TRPT lines, bridles, cyan, backline, lift kite (schematic)")
        println(io, "  island_$(isl)_winner_2d.png — elevation (side view); lines projected into the shaft frame")
    end
end

println()
println("done — outputs in $OUTDIR")
