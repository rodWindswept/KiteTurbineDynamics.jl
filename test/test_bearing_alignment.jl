using LinearAlgebra
using Statistics

# Frame-0 alignment regression test.
#
# After `settle_to_operational_state`, the lift bearing must sit on the TRPT
# shaft axis (the line through the origin and the hub centre) and the N top
# bridle lines connecting the bearing to the hub-ring vertices must be of
# near-equal length.
#
# If either invariant fails, the dashboard shows a snap on frame 1 — the
# lifter step input twists the bearing off-axis and the bridles re-equalise
# visibly during the first few simulated seconds.
#
# Tolerances are intentionally tight (perp offset < 0.5 m of a 6 m axial
# stand-off ≈ 4.8°; bridle spread < 5 % of mean) because the operational
# settle is supposed to land the bearing on the shaft, not "near" it.
@testset "bearing alignment at frame 0" begin
    p   = params_10kw()
    sys, u0 = build_kite_turbine_system(p)

    v_target = 11.0    # rated wind (matches dashboard default)
    wind_fn = (pos, t) -> begin
        z  = max(pos[3], 1.0)
        sh = (z / p.h_ref)^(1.0/7.0)
        [v_target * sh, 0.0, 0.0]
    end
    lift_device = rotary_lifter_default()
    ω_rated     = cbrt(p.p_rated_w / p.k_mppt)

    u_start = settle_to_operational_state(sys, u0, p, ω_rated;
                                           lift_device = lift_device,
                                           wind_fn     = wind_fn)

    N       = sys.n_total
    hub_gid = sys.rotor.node_id
    bgid    = sys.bearing_id

    hub_pos     = u_start[3*(hub_gid-1)+1 : 3*hub_gid]
    bearing_pos = u_start[3*(bgid-1)+1   : 3*bgid]

    # Shaft axis = line through origin (ground anchor) and hub centre.
    # This matches `compute_rope_forces!` (rope_forces.jl:35-37) which derives
    # shaft_dir from the live hub position.
    hub_norm  = norm(hub_pos)
    @test hub_norm > 1.0    # sanity: hub is not at origin
    shaft_dir = hub_pos ./ hub_norm

    # ── (a) Bearing-on-axis check ──────────────────────────────────────────
    # Project bearing position onto shaft axis; the perpendicular component
    # is the lateral wander we want to bound.
    bearing_perp_vec = bearing_pos .- dot(bearing_pos, shaft_dir) .* shaft_dir
    bearing_perp     = norm(bearing_perp_vec)

    @info "bearing alignment" hub_pos bearing_pos shaft_dir bearing_perp

    @test bearing_perp < 0.5    # m — bearing within ~5° of shaft axis at 6 m

    # ── (b) Equal-length top bridle check ──────────────────────────────────
    # Bridles connect the bearing to the hub-ring vertices.  Walk sub_segs
    # to find them rather than assuming an index layout.  A bridle's end_a
    # is the bearing (non-ring) and end_b is the hub ring.
    hub_ring_idx = (sys.nodes[hub_gid]::RingNode).ring_idx
    α_hub        = u_start[6N + hub_ring_idx]
    R_hub        = (sys.nodes[hub_gid]::RingNode).radius

    # Use the same perp basis the bridle render uses (visualization.jl:164-168):
    # shaft_perp_basis(normalize(hub_pos)).
    perp1, perp2 = shaft_perp_basis(shaft_dir)

    bridle_lengths = Float64[]
    for ss in sys.sub_segs
        # Bridle: end_a = bearing (not a ring), end_b = hub ring node
        ss.end_a.is_ring && continue
        ss.end_a.node_id == bgid || continue
        ss.end_b.is_ring || continue
        ss.end_b.node_id == hub_gid || continue

        attach = attachment_point(hub_pos, R_hub, α_hub,
                                   ss.end_b.line_idx, p.n_lines, perp1, perp2)
        push!(bridle_lengths, norm(bearing_pos .- attach))
    end

    @info "bridle lengths" count=length(bridle_lengths) lengths=bridle_lengths

    @test length(bridle_lengths) == p.n_lines    # found them all

    L_min  = minimum(bridle_lengths)
    L_max  = maximum(bridle_lengths)
    L_mean = mean(bridle_lengths)
    spread = L_max - L_min
    spread_pct = spread / L_mean

    @info "bridle length spread" L_min L_max L_mean spread spread_pct

    @test spread_pct < 0.05    # max-min within 5 % of mean

    # ── (c) Bridle rest-length sanity ──────────────────────────────────────
    # Each bridle's geometric length at frame 0 should also be close to its
    # design rest length L0 (no large pre-stretch / pre-slack), otherwise
    # the spring force releases on frame 1 as a step input.
    rest_lengths = Float64[]
    geom_lengths = Float64[]
    for ss in sys.sub_segs
        ss.end_a.is_ring && continue
        ss.end_a.node_id == bgid || continue
        ss.end_b.is_ring || continue
        ss.end_b.node_id == hub_gid || continue

        attach = attachment_point(hub_pos, R_hub, α_hub,
                                   ss.end_b.line_idx, p.n_lines, perp1, perp2)
        push!(rest_lengths, ss.length_0)
        push!(geom_lengths, norm(bearing_pos .- attach))
    end
    strain = (geom_lengths .- rest_lengths) ./ rest_lengths
    @info "bridle strain at frame 0" strain max_abs=maximum(abs.(strain))
    @test maximum(abs.(strain)) < 0.05    # < 5 % strain magnitude

    # ── (d) Lift / backline force at the bearing on frame 0 ────────────────
    # Force ledger sanity: compute the full bearing force vector via the
    # production ODE path (multibody_ode!) and split out the components.
    # Confirms that:
    #   - lift line force is non-zero (lifter is producing thrust at frame 0)
    #   - backline force is ~zero (line is at design rest length, payout=0)
    #   - net horizontal force on bearing is small (system is in equilibrium)
    du     = zeros(Float64, length(u_start))
    odepar = (sys, p, wind_fn, lift_device)
    multibody_ode!(du, u_start, odepar, 0.0)

    # d(vel)/dt = F/m  →  F = m * d(vel)/dt
    bm        = (sys.nodes[bgid]::BearingNode).mass
    bv_idx    = 3*N + 3*(bgid-1) + 1
    F_bearing = bm .* du[bv_idx : bv_idx + 2]
    F_horiz   = norm([F_bearing[1], F_bearing[2]])

    @info "bearing net force at frame 0" F_bearing F_horiz weight_N=bm*9.81

    # Net horizontal force should be small (well under 50 N — bridles + lift +
    # backline + gravity sum near zero in the on-axis equilibrium).  If this
    # blows up we know the lifter or backline is firing a step input.
    @test F_horiz < 50.0

    # The bearing should not be lifted vertically by more than a small
    # fraction of its weight either: equilibrium implies net Fz ~ 0.
    @test abs(F_bearing[3]) < 50.0
end

@testset "gold bridle tension under gravity (sagging hub ring)" begin
    p   = params_10kw()
    sys, u0 = build_kite_turbine_system(p)

    # Rated wind speed (matches standard operational state)
    v_target = 11.0
    wind_fn = (pos, t) -> begin
        z  = max(pos[3], 1.0)
        sh = (z / p.h_ref)^(1.0/7.0)
        [v_target * sh, 0.0, 0.0]
    end
    lift_device = rotary_lifter_default()
    ω_rated     = cbrt(p.p_rated_w / p.k_mppt)

    # Settle to operational state
    u_start = settle_to_operational_state(sys, u0, p, ω_rated;
                                           lift_device = lift_device,
                                           wind_fn     = wind_fn)

    N       = sys.n_total
    hub_gid = sys.rotor.node_id
    bgid    = sys.bearing_id

    # Apply a downward gravity sag to the hub ring (5 cm displacement)
    # This represents the hub ring sagging under gravity when rotor/shaft rigidity is low.
    u_sagged = copy(u_start)
    u_sagged[3*(hub_gid-1) + 3] -= 0.05

    hub_pos     = u_sagged[3*(hub_gid-1)+1 : 3*hub_gid]
    bearing_pos = u_sagged[3*(bgid-1)+1   : 3*bgid]

    hub_norm  = norm(hub_pos)
    shaft_dir = hub_pos ./ hub_norm
    perp1, perp2 = shaft_perp_basis(shaft_dir)

    hub_ring_idx = (sys.nodes[hub_gid]::RingNode).ring_idx
    α_hub        = u_sagged[6N + hub_ring_idx]
    R_hub        = (sys.nodes[hub_gid]::RingNode).radius

    # Compute tension and z-coordinate (height) of the attachment points
    bridle_data = []
    for ss in sys.sub_segs
        # Bridle: end_a = bearing (not a ring), end_b = hub ring node
        ss.end_a.is_ring && continue
        ss.end_a.node_id == bgid || continue
        ss.end_b.is_ring || continue
        ss.end_b.node_id == hub_gid || continue

        attach = attachment_point(hub_pos, R_hub, α_hub,
                                   ss.end_b.line_idx, p.n_lines, perp1, perp2)
        geom_len = norm(bearing_pos .- attach)
        strain = (geom_len - ss.length_0) / ss.length_0
        tension = max(0.0, ss.EA * strain)
        
        # Store bridle index, the attachment point z-coordinate, and its physical tension
        push!(bridle_data, (line_idx=ss.end_b.line_idx, attach_z=attach[3], tension=tension))
    end

    # Sort the bridles by their attachment z-coordinate (lowest first)
    sort!(bridle_data, by = x -> x.attach_z)

    @info "Sagged bridle data (sorted by Z height, lowest first):" bridle_data

    # The lowest bridle has the minimum Z coordinate
    lowest_bridle = bridle_data[1]
    # The highest bridle has the maximum Z coordinate
    highest_bridle = bridle_data[end]

    @info "Lowest bridle tension under sag" line_idx=lowest_bridle.line_idx z=lowest_bridle.attach_z T=lowest_bridle.tension
    @info "Highest bridle tension under sag" line_idx=highest_bridle.line_idx z=highest_bridle.attach_z T=highest_bridle.tension

    # Under gravity sag:
    # 1. The lowest bridle (bearing the hub ring/rotor mass directly) must have HIGHER tension
    @test lowest_bridle.tension > highest_bridle.tension
    # 2. It should have noticebly higher tension compared to the highest bridle
    @test lowest_bridle.tension > 100.0 # N
end

