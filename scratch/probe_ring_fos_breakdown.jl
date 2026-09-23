# scratch/probe_ring_fos_breakdown.jl
#
# Task 4.1 & 4.2: Static & Dynamic Per-Ring FoS & Stress Breakdown
#
# Analyzes the structural margins of each ring in a campaign candidate:
#   1. Closed-form beam sizing audit: Do, t_wall, t/D, Euler FoS, binding floors.
#   2. Settle-equilibrium static stress decomposition: N, N_crit, M_ip, M_oop, M_el,
#      axial utilisation, bending utilisation, and static FoS.
#   3. Dynamic window trace: track per-ring FoS over time to isolate the exact
#      ring, time, and mechanism (bending vs axial compression) of the FoS trough.
#
# Usage:
#   scripts/ktd-julia scratch/probe_ring_fos_breakdown.jl [island_dir] [sim_seconds] [attach_cfg]
#   e.g.:
#   scripts/ktd-julia scratch/probe_ring_fos_breakdown.jl island_1 2.0
#   scripts/ktd-julia scratch/probe_ring_fos_breakdown.jl island_3 2.0
#   scripts/ktd-julia scratch/probe_ring_fos_breakdown.jl island_1 2.0 noexp_aero

using KiteTurbineDynamics, LinearAlgebra, Statistics, Printf

include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KTD = KiteTurbineDynamics
const RESDIR = joinpath(@__DIR__, "..", "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_physlift")
const ISLAND = length(ARGS) >= 1 ? ARGS[1] : "island_1"
const SIM_S  = length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : 2.0
const ATTACH_CFG = length(ARGS) >= 3 ? ARGS[3] : ""

pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]

if !isempty(ATTACH_CFG)
    b = if ATTACH_CFG == "default"
        KTD.RingAttachmentPhysics()
    elseif ATTACH_CFG == "noexp_aero"
        KTD.RingAttachmentPhysics(; expansion_aero=false)
    elseif ATTACH_CFG == "ring9only"
        KTD.RingAttachmentPhysics(; expansion_aero_off=[8])
    elseif ATTACH_CFG == "ring8only"
        KTD.RingAttachmentPhysics(; expansion_aero_off=[9])
    elseif ATTACH_CFG == "tilt_hub_only"
        KTD.RingAttachmentPhysics(; tilt_scope=:hub)
    elseif ATTACH_CFG == "notilt"
        KTD.RingAttachmentPhysics(; tilt_enabled=false)
    elseif ATTACH_CFG == "notorque"
        KTD.RingAttachmentPhysics(; bridle_axial_torque=false)
    else
        error("unknown attach config: $ATTACH_CFG")
    end
    KTD.set_ring_attachment!(b)
    @printf("Configured ring attachment physics: %s -> %s\n", ATTACH_CFG, b)
end

function main()
    println("="^80)
    @printf("PER-RING FoS & STRESS BREAKDOWN: %s (sim_s=%.1f, cfg=%s)\n", ISLAND, SIM_S, isempty(ATTACH_CFG) ? "canonical" : ATTACH_CFG)
    println("="^80)

    csv_path = joinpath(RESDIR, ISLAND, "best_vector.csv")
    if !isfile(csv_path)
        error("File not found: $csv_path")
    end

    raw_tokens = split(strip(read(csv_path, String)), ",")
    xv = [parse(Float64, s) for s in raw_tokens]

    # Handle 10-D vs 14-D genome properly
    if length(xv) >= 14
        xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
        xv[10] = Float64(round(Int, clamp(xv[10], 1, 3)))
    else
        xv[4] = Float64(round(Int, clamp(xv[4], 3, 16))) # n_lines
        xv[6] = Float64(round(Int, clamp(xv[6], 1, 3))) # rotor_count
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

    # ── Task 4.2: Closed-form Beam Sizing Audit ───────────────────────────────
    sizing = KTD.size_beams_closed_form(dec, p0, cfg)

    println("\n[1] CLOSED-FORM BEAM SIZING AUDIT (size_beams_closed_form):")
    @printf("  Airborne Mass: %.2f kg | n_lines: %d | n_rings: %d | n_rotors: %d\n",
        KTD._closed_form_airborne_mass(sizing.Do_per_ring, dec, p0, cfg.t_over_D, cfg),
        dec.design.n_lines, dec.n_rings, dec.n_active
    )
    println("-"^80)
    @printf("%4s %7s %7s %7s %7s %7s %7s %8s %8s %8s %8s\n",
        "Ring", "z (m)", "r (m)", "L (m)", "Do (mm)", "t (mm)", "t/D", "Ncomp(N)", "Pcrit(N)", "EulerFoS", "Flags"
    )
    println("-"^80)

    n_rings_tot = length(dec.radii)
    for i in 1:n_rings_tot
        r = dec.radii[i]
        z = dec.zs[i]
        L = 2.0 * r * sin(π / dec.design.n_lines)
        Do = sizing.Do_per_ring[i]
        t_wall = KTD.tube_wall_thickness(Do, cfg.t_over_D; min_wall_m=cfg.min_wall_m)
        t_over_D = t_wall / Do
        P_crit = KTD.strut_properties(KTD.CircularTube(Do, t_over_D), L, KTD.FixedFixedEnds()).P_crit
        N_comp = sizing.N_comp_per_ring[i]
        efos = sizing.fos_per_ring[i]

        flags = String[]
        if abs(t_wall - cfg.min_wall_m) < 1e-6
            push!(flags, "t_floor")
        end
        if abs(Do - KTD.MIN_RING_DO_M) < 1e-6
            push!(flags, "Do_floor")
        end
        flag_str = join(flags, ",")

        @printf("%4d %7.2f %7.3f %7.3f %7.2f %7.2f %7.4f %8.1f %8.1f %8.2f %8s\n",
            i, z, r, L, Do*1000, t_wall*1000, t_over_D, N_comp, P_crit, efos, flag_str
        )
    end
    println("-"^80)

    # ── Build & Settle System ────────────────────────────────────────────────
    println("\n[2] BUILDING & SETTLING OPERATIONAL SYSTEM:")
    sys, u0, pc = KTD.build_system_from_v10(
        dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p0.tether_diameter, base_params=p0, min_wall_m=2e-3,
        beam_sizing=sizing
    )
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    lift = lift_for(sys, pc)
    wf = (r, t) -> [pc.v_wind_ref, 0.0, 0.0]

    N = sys.n_total
    Nr = sys.n_ring
    hub_gid = sys.rotor.node_id
    bear_gid = sys.bearing_id
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx

    println("  Settling system to operational state (n_op=300,000)...")
    t_settle = @elapsed u = settle_to_operational_state(
        sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
    )
    @printf("  Settled in %.2f s wall time.\n", t_settle)

    # ── Task 4.1: Settle-Equilibrium Static Stress Decomposition ──────────────
    println("\n[3] EQUILIBRIUM STATIC STRESS DECOMPOSITION (t = 0.0 s):")
    alpha_vec = u[(6N + 1):(6N + Nr)]
    rea = KTD.ring_element_analysis(u, collect(alpha_vec), sys, pc, 0.0, wf)

    println("-"^95)
    @printf("%4s %4s %7s %7s %8s %8s %7s %7s %7s %7s %7s %7s %7s\n",
        "Ring", "GID", "r (m)", "mass(kg)", "N (N)", "Ncrit(N)", "Util_A", "Mip(Nm)", "Moop(Nm)", "Mel(Nm)", "Util_B", "UtilTot", "StatFoS"
    )
    println("-"^95)

    # Note: rea contains rings 2:end (airborne rings)
    for (idx, ref) in enumerate(rea)
        ring_gid = sys.ring_ids[idx + 1]
        node = sys.nodes[ring_gid]::RingNode
        r = node.radius
        m = node.mass

        if isempty(ref.beams)
            @printf("%4d %4d %7.3f %7.2f   [EMPTY BEAMS]\n", idx + 1, ring_gid, r, m)
            continue
        end

        worst = ref.beams[1]
        for b in ref.beams
            if b.utilisation >= worst.utilisation
                worst = b
            end
        end

        wA = max(worst.N, 0.0) / max(worst.N_crit, 1e-9)
        M_comb = sqrt(worst.M_ip^2 + worst.M_oop^2)
        wB = M_comb / max(worst.M_el, 1e-9)
        wtot = worst.utilisation
        sfos = wtot > 1e-9 ? 1.0 / wtot : Inf

        @printf("%4d %4d %7.3f %7.2f %8.1f %8.1f %7.4f %7.2f %7.2f %7.2f %7.4f %7.4f %7.2f\n",
            idx + 1, ring_gid, r, m, worst.N, worst.N_crit, wA, worst.M_ip, worst.M_oop, worst.M_el, wB, wtot, sfos
        )
    end
    println("-"^95)

    # ── Task 4.1: Dynamic Window Trace ────────────────────────────────────────
    println("\n[4] DYNAMIC WINDOW TRACE (0.0 to $(SIM_S) s):")
    dt = KTD.stable_dt_for_system(sys, pc)
    steps = round(Int, SIM_S / dt)
    sample_every = max(1, round(Int, 0.01 / dt)) # sample every ~10 ms

    n_airborne = length(rea)
    min_fos_per_ring = fill(Inf, n_airborne)
    worst_time_per_ring = zeros(n_airborne)
    worst_wA_per_ring = zeros(n_airborne)
    worst_wB_per_ring = zeros(n_airborne)
    mean_fos_per_ring = zeros(n_airborne)
    n_samples = 0

    cone_min_tension = Inf
    max_hub_lat = 0.0
    shaft_nom = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]

    chunk_steps = max(1, round(Int, 0.01 / dt)) # advance 10 ms at a time
    n_chunks = round(Int, SIM_S / (chunk_steps * dt))
    t_cur = 0.0

    for ch in 1:n_chunks
        run_canonical_sim!(u, sys, pc, wf, chunk_steps, dt; lift_device=lift, lin_damp=0.0)
        t_cur += chunk_steps * dt
        n_samples += 1

            # Hub lateral
            h_pos = pos(u, hub_gid)
            h_lat = norm(h_pos .- dot(h_pos, shaft_nom) .* shaft_nom)
            max_hub_lat = max(max_hub_lat, h_lat)

            # Bridle cone tension
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
            cone_min_tension = min(cone_min_tension, T_cone)

            # Per-ring structural analysis
            alphas = u[(6N + 1):(6N + Nr)]
            dyn_rea = KTD.ring_element_analysis(u, collect(alphas), sys, pc, t_cur, wf)
            for (idx, ref) in enumerate(dyn_rea)
                if isempty(ref.beams)
                    continue
                end
                worst_b = ref.beams[1]
                for b in ref.beams
                    if b.utilisation >= worst_b.utilisation
                        worst_b = b
                    end
                end
                u_tot = worst_b.utilisation
                rfos = u_tot > 1e-9 ? 1.0 / u_tot : Inf
                mean_fos_per_ring[idx] += rfos
                if rfos < min_fos_per_ring[idx]
                    min_fos_per_ring[idx] = rfos
                    worst_time_per_ring[idx] = t_cur
                    worst_wA_per_ring[idx] = max(worst_b.N, 0.0) / max(worst_b.N_crit, 1e-9)
                    worst_wB_per_ring[idx] = sqrt(worst_b.M_ip^2 + worst_b.M_oop^2) / max(worst_b.M_el, 1e-9)
                end
            end
    end

    if n_samples > 0
        mean_fos_per_ring ./= n_samples
    end

    println("-"^90)
    @printf("%4s %4s %7s %10s %10s %8s %8s %8s %8s\n",
        "Ring", "GID", "r (m)", "Min DynFoS", "Mean DynFoS", "t_worst(s)", "Worst_uA", "Worst_uB", "Mode"
    )
    println("-"^90)

    bottleneck_idx = argmin(min_fos_per_ring)
    for idx in 1:n_airborne
        ring_gid = sys.ring_ids[idx + 1]
        node = sys.nodes[ring_gid]::RingNode
        r = node.radius
        min_f = min_fos_per_ring[idx]
        mean_f = mean_fos_per_ring[idx]
        tw = worst_time_per_ring[idx]
        wa = worst_wA_per_ring[idx]
        wb = worst_wB_per_ring[idx]
        mode = wa > wb ? "Axial/Buckling" : "Bending"

        marker = (idx == bottleneck_idx) ? " <-- MIN TROUGH" : ""
        @printf("%4d %4d %7.3f %10.4f %10.4f %8.3f %8.4f %8.4f %15s%s\n",
            idx + 1, ring_gid, r, min_f, mean_f, tw, wa, wb, mode, marker
        )
    end
    println("-"^90)

    @printf("\nOVERALL BOTTLENECK: Ring %d (GID %d) hitting FoS = %.4f at t = %.3f s\n",
        bottleneck_idx + 1, sys.ring_ids[bottleneck_idx + 1], min_fos_per_ring[bottleneck_idx], worst_time_per_ring[bottleneck_idx]
    )
    @printf("Failure Share: Axial util = %.4f (%.1f%%) | Bending util = %.4f (%.1f%%)\n",
        worst_wA_per_ring[bottleneck_idx],
        100.0 * worst_wA_per_ring[bottleneck_idx] / (worst_wA_per_ring[bottleneck_idx] + worst_wB_per_ring[bottleneck_idx]),
        worst_wB_per_ring[bottleneck_idx],
        100.0 * worst_wB_per_ring[bottleneck_idx] / (worst_wA_per_ring[bottleneck_idx] + worst_wB_per_ring[bottleneck_idx])
    )
    @printf("Window Metrics: Max Hub Lateral = %.4f m | Min Cone Tension = %.2f N\n", max_hub_lat, cone_min_tension)
    println("="^80)
end

main()
