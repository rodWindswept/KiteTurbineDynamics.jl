using LinearAlgebra
using Statistics

# Helper used across multiple testsets: builds a modified copy of SystemParams.
# Defined at file scope so all testsets can access it.
function _modified_params(base::SystemParams; kwargs...)
    fnames = fieldnames(SystemParams)
    ftypes = fieldtypes(SystemParams)
    overrides = Dict{Symbol, Any}(kwargs)
    vals = ntuple(length(fnames)) do i
        return convert(ftypes[i], get(overrides, fnames[i], getfield(base, fnames[i])))
    end
    return SystemParams(vals...)
end

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
    p = params_10kw()
    sys, u0 = build_kite_turbine_system(p)

    v_target = 11.0    # rated wind (matches dashboard default)
    wind_fn = (pos, t) -> begin
        z = max(pos[3], 1.0)
        sh = (z / p.h_ref)^(1.0/7.0)
        [v_target * sh, 0.0, 0.0]
    end
    lift_device = rotary_lifter_default()
    ω_rated = cbrt(p.p_rated_w / p.k_mppt)

    u_start = settle_to_operational_state(
        sys, u0, p, ω_rated; lift_device=lift_device, wind_fn=wind_fn
    )

    N = sys.n_total
    hub_gid = sys.rotor.node_id
    bgid = sys.bearing_id

    hub_pos = u_start[(3 * (hub_gid - 1) + 1):(3 * hub_gid)]
    bearing_pos = u_start[(3 * (bgid - 1) + 1):(3 * bgid)]

    # Shaft axis = line through origin (ground anchor) and hub centre.
    # This matches `compute_rope_forces!` (rope_forces.jl:35-37) which derives
    # shaft_dir from the live hub position.
    hub_norm = norm(hub_pos)
    @test hub_norm > 1.0    # sanity: hub is not at origin
    shaft_dir = hub_pos ./ hub_norm

    # ── (a) Bearing-on-axis check ──────────────────────────────────────────
    # Project bearing position onto shaft axis; the perpendicular component
    # is the lateral wander we want to bound.
    bearing_perp_vec = bearing_pos .- dot(bearing_pos, shaft_dir) .* shaft_dir
    bearing_perp = norm(bearing_perp_vec)

    @info "bearing alignment" hub_pos bearing_pos shaft_dir bearing_perp

    @test bearing_perp < 0.5    # m — bearing within ~5° of shaft axis at 6 m

    # ── (b) Equal-length top bridle check ──────────────────────────────────
    # Bridles connect the bearing to the hub-ring vertices.  Walk sub_segs
    # to find them rather than assuming an index layout.  A bridle's end_a
    # is the bearing (non-ring) and end_b is the hub ring.
    hub_ring_idx = (sys.nodes[hub_gid]::RingNode).ring_idx
    α_hub = u_start[6N + hub_ring_idx]
    R_hub = (sys.nodes[hub_gid]::RingNode).radius

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

        attach = attachment_point(
            hub_pos, R_hub, α_hub, ss.end_b.line_idx, p.n_lines, perp1, perp2
        )
        push!(bridle_lengths, norm(bearing_pos .- attach))
    end

    @info "bridle lengths" count=length(bridle_lengths) lengths=bridle_lengths

    @test length(bridle_lengths) == p.n_lines    # found them all

    L_min = minimum(bridle_lengths)
    L_max = maximum(bridle_lengths)
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

        attach = attachment_point(
            hub_pos, R_hub, α_hub, ss.end_b.line_idx, p.n_lines, perp1, perp2
        )
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
    du = zeros(Float64, length(u_start))
    odepar = (sys, p, wind_fn, lift_device)
    multibody_ode!(du, u_start, odepar, 0.0)

    # d(vel)/dt = F/m  →  F = m * d(vel)/dt
    bm = (sys.nodes[bgid]::BearingNode).mass
    bv_idx = 3*N + 3*(bgid-1) + 1
    F_bearing = bm .* du[bv_idx:(bv_idx + 2)]
    F_horiz = norm([F_bearing[1], F_bearing[2]])

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
    p = params_10kw()
    sys, u0 = build_kite_turbine_system(p)

    # Rated wind speed (matches standard operational state)
    v_target = 11.0
    wind_fn = (pos, t) -> begin
        z = max(pos[3], 1.0)
        sh = (z / p.h_ref)^(1.0/7.0)
        [v_target * sh, 0.0, 0.0]
    end
    lift_device = rotary_lifter_default()
    ω_rated = cbrt(p.p_rated_w / p.k_mppt)

    # Settle to operational state
    u_start = settle_to_operational_state(
        sys, u0, p, ω_rated; lift_device=lift_device, wind_fn=wind_fn
    )

    N = sys.n_total
    hub_gid = sys.rotor.node_id
    bgid = sys.bearing_id

    # Apply a downward gravity sag to the hub ring (5 cm displacement)
    # This represents the hub ring sagging under gravity when rotor/shaft rigidity is low.
    u_sagged = copy(u_start)
    u_sagged[3 * (hub_gid - 1) + 3] -= 0.05

    hub_pos = u_sagged[(3 * (hub_gid - 1) + 1):(3 * hub_gid)]
    bearing_pos = u_sagged[(3 * (bgid - 1) + 1):(3 * bgid)]

    hub_norm = norm(hub_pos)
    shaft_dir = hub_pos ./ hub_norm
    perp1, perp2 = shaft_perp_basis(shaft_dir)

    hub_ring_idx = (sys.nodes[hub_gid]::RingNode).ring_idx
    α_hub = u_sagged[6N + hub_ring_idx]
    R_hub = (sys.nodes[hub_gid]::RingNode).radius

    # Compute tension and z-coordinate (height) of the attachment points
    bridle_data = []
    for ss in sys.sub_segs
        # Bridle: end_a = bearing (not a ring), end_b = hub ring node
        ss.end_a.is_ring && continue
        ss.end_a.node_id == bgid || continue
        ss.end_b.is_ring || continue
        ss.end_b.node_id == hub_gid || continue

        attach = attachment_point(
            hub_pos, R_hub, α_hub, ss.end_b.line_idx, p.n_lines, perp1, perp2
        )
        geom_len = norm(bearing_pos .- attach)
        strain = (geom_len - ss.length_0) / ss.length_0
        tension = max(0.0, ss.EA * strain)

        # Store bridle index, the attachment point z-coordinate, and its physical tension
        push!(
            bridle_data, (line_idx=ss.end_b.line_idx, attach_z=attach[3], tension=tension)
        )
    end

    # Sort the bridles by their attachment z-coordinate (lowest first)
    sort!(bridle_data, by=x -> x.attach_z)

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

@testset "Field IMU active damping control law" begin
    p = params_10kw()
    sys, u0 = build_kite_turbine_system(p)

    # Standard case: Field IMU active damping is off
    p_off = p # kp_elev defaults to ~0.0

    # Active case: Field IMU active damping is on
    p_on = _modified_params(p; kp_elev=1.0)

    # Set omega_gnd = 5.0 rad/s and omega_hub = 2.0 rad/s (rotor spinning, brake not engaged)
    u_test = copy(u0)
    N = sys.n_total
    Nr = sys.n_ring
    gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx # = 1
    hub_gid = sys.rotor.node_id
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx

    # Set the angular velocities in the state vector u_test
    # Ring angular velocities are stored at u[6N + Nr + ri]
    u_test[6N + Nr + gnd_ri] = 5.0
    u_test[6N + Nr + hub_ri] = 2.0

    du_off = zeros(Float64, length(u_test))
    wind_fn = (pos, t) -> [0.0, 0.0, 0.0]
    lift_device = rotary_lifter_default()

    multibody_ode!(du_off, u_test, (sys, p_off, wind_fn, lift_device), 0.0)

    du_on = zeros(Float64, length(u_test))
    multibody_ode!(du_on, u_test, (sys, p_on, wind_fn, lift_device), 0.0)

    # The acceleration of the ground ring is du[6N + Nr + gnd_ri]
    accel_off = du_off[6N + Nr + gnd_ri]
    accel_on = du_on[6N + Nr + gnd_ri]

    @info "Field IMU damping torque test" accel_off accel_on

    # With active damping ON, the ground ring deceleration must be much larger
    # (more negative acceleration) due to the extra damping torque
    @test accel_on < accel_off

    # Test 2: Mechanical brake engagement below 1.0 rad/s
    u_test_brake = copy(u0)
    u_test_brake[6N + Nr + gnd_ri] = 0.5 # below 1.0 rad/s threshold
    u_test_brake[6N + Nr + hub_ri] = 0.0

    du_brake_off = zeros(Float64, length(u_test_brake))
    multibody_ode!(du_brake_off, u_test_brake, (sys, p_off, wind_fn, lift_device), 0.0)

    du_brake_on = zeros(Float64, length(u_test_brake))
    multibody_ode!(du_brake_on, u_test_brake, (sys, p_on, wind_fn, lift_device), 0.0)

    accel_brake_off = du_brake_off[6N + Nr + gnd_ri]
    accel_brake_on = du_brake_on[6N + Nr + gnd_ri]

    @info "Ground station mechanical brake test" accel_brake_off accel_brake_on
    # With the brake decoupled from the Field IMU, it must engage in both cases
    @test accel_brake_on ≈ accel_brake_off
    @test accel_brake_on < -50.0

    # Test 3: Mechanical brake safety interlock (do NOT engage if both are fast)
    sys.brake_engaged[] = false
    u_test_interlock = copy(u0)
    u_test_interlock[6N + Nr + gnd_ri] = 2.0 # ground speed is fast
    u_test_interlock[6N + Nr + hub_ri] = 5.0 # sky rotor is fast!

    du_lock_off = zeros(Float64, length(u_test_interlock))
    multibody_ode!(du_lock_off, u_test_interlock, (sys, p_off, wind_fn, lift_device), 0.0)

    du_lock_on = zeros(Float64, length(u_test_interlock))
    multibody_ode!(du_lock_on, u_test_interlock, (sys, p_on, wind_fn, lift_device), 0.0)

    accel_lock_off = du_lock_off[6N + Nr + gnd_ri]
    accel_lock_on = du_lock_on[6N + Nr + gnd_ri]

    @info "Ground station mechanical brake safety interlock test" accel_lock_off accel_lock_on

    # Deceleration with brake ON at high rotor and ground speed should be small (no brake engaged)
    @test abs(accel_lock_on) < 2000.0

    # Test 4: Brake does NOT fire on PTO speed alone — flying rotor must reach < 1 rad/s.
    # Design intent: triggering on omega_gnd alone could fire the brake while the rotor
    # is still fast (e.g. TRPT is twisted), applying a torsional shock to the rope stack.
    # The rotor must slow to < 1 rad/s first so torsional energy is already low.
    sys.brake_engaged[] = false
    u_no_premature_brake = copy(u0)
    u_no_premature_brake[6N + Nr + gnd_ri] = 0.5 # PTO is slow
    u_no_premature_brake[6N + Nr + hub_ri] = 5.0 # rotor is still fast — brake must NOT fire

    du_no_premature = zeros(Float64, length(u_no_premature_brake))
    multibody_ode!(
        du_no_premature, u_no_premature_brake, (sys, p_on, wind_fn, lift_device), 0.0
    )
    accel_no_premature = du_no_premature[6N + Nr + gnd_ri]

    # Deceleration should be moderate (MPPT + active damping only), not a brake slam
    @info "No premature brake trigger test (PTO slow, rotor fast)" accel_no_premature
    @test abs(accel_no_premature) < 10000.0

    # Test 5: Torque Limiter Enforcement
    # Even if p.k_mppt is scaled to an extremely high value (e.g. 10000.0),
    # generator torque should be capped at tau_max_safe = 2500.0 * power_scale.
    p_extreme = _modified_params(p_on; k_mppt=10000.0) # extreme k_mppt
    u_extreme = copy(u0)
    u_extreme[6N + Nr + gnd_ri] = 2.0 # fast, no brake
    u_extreme[6N + Nr + hub_ri] = 2.0

    du_extreme = zeros(Float64, length(u_extreme))
    multibody_ode!(du_extreme, u_extreme, (sys, p_extreme, wind_fn, lift_device), 0.0)
    accel_extreme = du_extreme[6N + Nr + gnd_ri]

    # The maximum deceleration should be bounded by (tau_max_safe / i_pto) + small damping/inertial margin
    power_scale = (p_extreme.p_rated_w / 10000.0)^2
    tau_max_safe = 2500.0 * power_scale
    max_accel_safe = (tau_max_safe + 150.0) / p_extreme.i_pto
    @info "Torque limiter test" accel_extreme max_accel_safe
    @test abs(accel_extreme) <= max_accel_safe

    # Test 6: Decoupling verification
    # Once sys.brake_engaged[] is true, generator torque is overridden by tau_brake,
    # meaning k_mppt does not affect it.
    sys.brake_engaged[] = true
    p_high_k = _modified_params(p_on; k_mppt=5000.0)
    u_decoupled = copy(u0)
    u_decoupled[6N + Nr + gnd_ri] = 0.5
    u_decoupled[6N + Nr + hub_ri] = 2.0 # hub is fast

    du_low_k = zeros(Float64, length(u_decoupled))
    multibody_ode!(du_low_k, u_decoupled, (sys, p_on, wind_fn, lift_device), 0.0)

    du_high_k = zeros(Float64, length(u_decoupled))
    multibody_ode!(du_high_k, u_decoupled, (sys, p_high_k, wind_fn, lift_device), 0.0)

    # The accelerations should be identical because the generator has been decoupled
    # and only the mechanical brake is active!
    @test du_low_k[6N + Nr + gnd_ri] ≈ du_high_k[6N + Nr + gnd_ri] atol=1e-3
end

@testset "brake Euler velocity constraint" begin
    # Regression test for the forward-Euler numerical instability described in
    # apply_brake_constraint! (ring_forces.jl).
    #
    # The tanh(20·ω_gnd) brake model has a linearised stiffness ~508 000 rad/s²
    # near ω=0, which is ~250× beyond the Euler stability limit at dt=1 ms.
    # Without apply_brake_constraint!, small perturbations amplify into sign-flipping
    # oscillations — tau_gen swings wildly even though the HUD shows LOCKED.
    #
    # This test manually replicates the dashboard's Euler loop for 200 steps at
    # dt = 1 ms with the brake engaged and a residual TRPT torsional disturbance,
    # confirming that apply_brake_constraint! keeps omega_gnd exactly at zero.
    p = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    wind_fn = (pos, t) -> [0.0, 0.0, 0.0]
    lift_device = rotary_lifter_default()

    N = sys.n_total
    Nr = sys.n_ring
    hub_gid = sys.rotor.node_id
    gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx   # = 1
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx

    # Engage the brake and set a low hub speed (rotor nearly stopped)
    sys.brake_engaged[] = true
    p_brake = _modified_params(p; kp_elev=1.0)

    u = copy(u0)
    u[6N + Nr + gnd_ri] = 0.3   # PTO just above zero — brake fires, should clamp to zero
    u[6N + Nr + hub_ri] = 0.5   # hub also slow

    du = zeros(Float64, length(u))
    dt = 0.001   # 1 ms — standard dashboard timestep

    for step in 1:200
        fill!(du, 0.0)
        multibody_ode!(du, u, (sys, p_brake, wind_fn, lift_device), step * dt)

        # Replicate the dashboard Euler update
        @views u[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
        @views u[1:3N] .+= dt .* u[(3N + 1):6N]
        @views u[(6N + Nr + 1):(6N + 2Nr)] .+= dt .* du[(6N + Nr + 1):(6N + 2Nr)]

        # Apply the brake constraint (this is what the dashboard calls)
        apply_brake_constraint!(u, sys, N, Nr)

        @views u[(6N + 1):(6N + Nr)] .+= dt .* u[(6N + Nr + 1):(6N + 2Nr)]

        # Ground ring angular velocity must be exactly zero every step
        @test u[6N + Nr + gnd_ri] == 0.0
    end
end
