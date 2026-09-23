# scratch/probe_mass_resonance.jl
#
# Task 4.3: Lumped Mass vs Column Dynamics (Resonance Probe)
#
# Tests whether concentrated masses at rings 8, 9, 10 drive the lateral whipping
# and column buckling on Island 1.
#
# Compares 3 mass conditions over a 5-second dynamic window:
#   A. Baseline: Full physical mass (er.mass on rings 8 & 9, m_rotor on ring 10).
#   B. Bare rings 8 & 9: Strip er.mass from rings 8 & 9 (set to bare ring mass).
#   C. Bare column: Strip expansion masses from rings 8 & 9 AND bare ring on hub.
#
# Usage:
#   scripts/ktd-julia scratch/probe_mass_resonance.jl [sim_seconds]

using KiteTurbineDynamics, LinearAlgebra, Statistics, Printf

include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KTD = KiteTurbineDynamics
const RESDIR = joinpath(@__DIR__, "..", "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_physlift")
const SIM_S  = length(ARGS) >= 1 ? parse(Float64, ARGS[1]) : 5.0

pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]

function build_case()
    csv_path = joinpath(RESDIR, "island_1", "best_vector.csv")
    raw_tokens = split(strip(read(csv_path, String)), ",")
    xv = [parse(Float64, s) for s in raw_tokens]

    if length(xv) >= 14
        xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
        xv[10] = Float64(round(Int, clamp(xv[10], 1, 3)))
    else
        xv[4] = Float64(round(Int, clamp(xv[4], 3, 16)))
        xv[6] = Float64(round(Int, clamp(xv[6], 1, 3)))
    end

    p0 = params_at_length(params_daisy(), 18.8, 5.0)
    bf = BLOCKING_WIND_FACTOR_5KW
    dec = design_from_vector_v10(
        xv, PROFILE_ELLIPTICAL, p0;
        power_W=5000.0, cylinder_cone=true, rotor_count_mode=true,
        power_split=0.6, cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=bf
    )
    cfg = KTD.ObjectiveConfig(;
        power_W=5000.0, v_rated=11.0, p_floor_kw=5.0,
        fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
        rotor_count_mode=true, power_split=0.6, blocking_factor=bf
    )
    sizing = KTD.size_beams_closed_form(dec, p0, cfg)
    sys, u0, pc = KTD.build_system_from_v10(
        dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p0.tether_diameter, base_params=p0, min_wall_m=2e-3,
        beam_sizing=sizing
    )
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    return sys, u0, pc
end

function run_variant(label::String, modify_sys_fn!)
    sys, u0, pc = build_case()
    modify_sys_fn!(sys, pc)

    lift = lift_for(sys, pc)
    wf = (r, t) -> [pc.v_wind_ref, 0.0, 0.0]

    N = sys.n_total
    Nr = sys.n_ring
    hub_gid = sys.rotor.node_id
    bear_gid = sys.bearing_id
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx

    println("\n" * "="^70)
    @printf("RUNNING VARIANT: %s\n", label)
    println("Ring masses on system:")
    for (idx, gid) in enumerate(sys.ring_ids[2:end])
        nd = sys.nodes[gid]::RingNode
        @printf("  Ring %2d (GID %2d, r=%.3fm): mass = %.3f kg, Iz = %.4f kg·m²\n",
            idx + 1, gid, nd.radius, nd.mass, nd.inertia_z
        )
    end
    println("="^70)

    t_s = @elapsed u = settle_to_operational_state(
        sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
    )
    @printf("Settled in %.2f s wall time.\n", t_s)

    dt = KTD.stable_dt_for_system(sys, pc)
    chunk_steps = max(1, round(Int, 0.01 / dt))
    n_chunks = round(Int, SIM_S / (chunk_steps * dt))

    shaft_nom = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
    hub_lats = Float64[]
    bear_lats = Float64[]
    cone_tensions = Float64[]
    min_fos_record = Float64[]
    t_record = Float64[]

    t_cur = 0.0
    for ch in 1:n_chunks
        run_canonical_sim!(u, sys, pc, wf, chunk_steps, dt; lift_device=lift, lin_damp=0.0)
        t_cur += chunk_steps * dt

        # Hub & bearing lateral
        h_pos = pos(u, hub_gid)
        h_lat = norm(h_pos .- dot(h_pos, shaft_nom) .* shaft_nom)
        b_pos = pos(u, bear_gid)
        b_lat = norm(b_pos .- dot(b_pos, shaft_nom) .* shaft_nom)
        push!(hub_lats, h_lat)
        push!(bear_lats, b_lat)
        push!(t_record, t_cur)

        # Cone tension
        pp1, pp2 = KTD._tilted_ring_basis(u, sys, hub_gid, hub_ri)
        node_hub = sys.nodes[hub_gid]::RingNode
        R_hub = isempty(sys.expansion_rotors) ? node_hub.radius : sys.effective_radii[node_hub.ring_idx]
        T_cone = 0.0
        for ss in sys.sub_segs
            na, nb = ss.end_a.node_id, ss.end_b.node_id
            if (na == hub_gid && nb == bear_gid) || (na == bear_gid && nb == hub_gid)
                ring_end = ss.end_a.is_ring ? ss.end_a : ss.end_b
                pa = attachment_point(h_pos, R_hub, u[6N + Nr], ring_end.line_idx, pc.n_lines, pp1, pp2)
                L_br = norm(pos(u, bear_gid) .- pa)
                T_cone += ss.EA * max(0.0, (L_br - ss.length_0) / ss.length_0)
            end
        end
        push!(cone_tensions, T_cone)

        # Min FoS
        alphas = u[(6N + 1):(6N + Nr)]
        dyn_rea = KTD.ring_element_analysis(u, collect(alphas), sys, pc, t_cur, wf)
        frame_min_fos = Inf
        for ref in dyn_rea
            for b in ref.beams
                if b.utilisation > 1e-9
                    frame_min_fos = min(frame_min_fos, 1.0 / b.utilisation)
                end
            end
        end
        push!(min_fos_record, frame_min_fos)
    end

    # Metrics
    hub_p2p = maximum(hub_lats) - minimum(hub_lats)
    hub_max = maximum(hub_lats)
    bear_max = maximum(bear_lats)
    cone_min = minimum(cone_tensions)
    cone_mean = mean(cone_tensions)
    fos_trough = minimum(min_fos_record)
    fos_mean = mean(min_fos_record)

    @printf("\nRESULTS FOR [%s]:\n", label)
    @printf("  Hub Lateral:     Peak = %.4f m | p2p = %.4f m (mean = %.4f m)\n", hub_max, hub_p2p, mean(hub_lats))
    @printf("  Bearing Lateral: Peak = %.4f m | mean = %.4f m\n", bear_max, mean(bear_lats))
    @printf("  Cone Tension:    Min = %.2f N | Mean = %.2f N\n", cone_min, cone_mean)
    @printf("  FoS:             Trough = %.4f | Mean = %.4f\n", fos_trough, fos_mean)
    println("-"^70)

    return (; label, hub_max, hub_p2p, bear_max, cone_min, cone_mean, fos_trough, fos_mean)
end

function main()
    println("="^80)
    @printf("TASK 4.3: LUMPED MASS RESONANCE PROBE (Island 1, SIM_S = %.1f s)\n", SIM_S)
    println("="^80)

    # Variant A: Baseline
    res_A = run_variant("A: Baseline Full Physical Mass", (sys, pc) -> nothing)

    # Variant B: Strip expansion rotor mass from rings 8 & 9 (bare ring mass)
    res_B = run_variant("B: Bare Ring Mass on Expansion Rings 8 & 9", (sys, pc) -> begin
        r8_gid = sys.ring_ids[8]
        r9_gid = sys.ring_ids[9]
        nd8 = sys.nodes[r8_gid]::RingNode
        nd9 = sys.nodes[r9_gid]::RingNode
        # Set to bare ring mass (1.530 kg, like transmission rings 2-7)
        sys.nodes[r8_gid] = RingNode(nd8.id, nd8.ring_idx, pc.m_ring, nd8.radius, nd8.inertia_z, nd8.is_fixed)
        sys.nodes[r9_gid] = RingNode(nd9.id, nd9.ring_idx, pc.m_ring, nd9.radius, nd9.inertia_z, nd9.is_fixed)
    end)

    # Variant C: Strip all expansion rotor masses AND reduce hub ring mass to bare ring
    res_C = run_variant("C: Uniform Bare Mass Column (Rings 2-10 all = 1.53 kg)", (sys, pc) -> begin
        for ri in 2:10
            gid = sys.ring_ids[ri]
            nd = sys.nodes[gid]::RingNode
            sys.nodes[gid] = RingNode(nd.id, nd.ring_idx, pc.m_ring, nd.radius, nd.inertia_z, nd.is_fixed)
        end
    end)

    println("\n" * "="^85)
    @printf("%-45s %10s %10s %10s %10s\n", "Configuration", "Hub p2p(m)", "Cone Min(N)", "FoS Trough", "Cone Mean(N)")
    println("="^85)
    for r in [res_A, res_B, res_C]
        @printf("%-45s %10.4f %10.2f %10.4f %10.2f\n", r.label, r.hub_p2p, r.cone_min, r.fos_trough, r.cone_mean)
    end
    println("="^85)
end

main()
