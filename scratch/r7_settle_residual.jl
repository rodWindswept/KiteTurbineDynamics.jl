# scratch/r7_settle_residual.jl — measured static residual of today's settle.
#
# No behaviour change: builds the 5 kW / 18.8 m seed, runs
# settle_to_operational_state, then evaluates the ODE right-hand side at the
# returned state with the *running* velocity field (ring angle rates = ω_eq,
# rope nodes at their orbital velocity, ring/bearing/sky translations zero).
#
#   R_trans = du[3N+1 : 6N]        (translational accelerations, free nodes)
#   R_ang   = du[6N+Nr+1 : 6N+2Nr] (ring angular accelerations)
#
# Reports the baseline for the settle↔ODE-coherence acceptance criteria
# (docs/plans/2026-09-11-settle-ode-coherence.md, S1-S3) and the twist gap.
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

function params_5kw_188()
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        18.8, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return override_params(mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, 5.0);
                           tether_length=18.8)
end

p = params_5kw_188()
x = seed_genome(5.0)
x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
dec = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=5000.0,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
    rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)
cfg = ObjectiveConfig(; power_W=5000.0, v_rated=11.0, p_floor_kw=5.0, p_ceiling_kw=5.0,
    fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
    rotor_count_mode=true, power_split=0.6, blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    k_mppt=K_MPPT_5KW_HONEST)
sizing = size_beams_closed_form(dec, p, cfg)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3, beam_sizing=sizing)
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
N = sys.n_total
Nr = sys.n_ring

@printf("nodes N=%d  rings Nr=%d  dt=%.3e  k=%.3f  ω_rated=60\n", N, Nr, dt, K_MPPT_5KW_HONEST)

for n_op in (30_000, 150_000)
    t0 = time()
    u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
        lift_device=lift, wind_fn=wf, n_op=n_op)
    t_settle = time() - t0

    ω_eq = u[6N + Nr + 1]
    du = zeros(Float64, length(u))
    multibody_ode!(du, u, (sys, pc, wf, lift), 0.0)

    # Free nodes: everything except the fixed ground ring (ring_ids[1]).
    ground = sys.ring_ids[1]
    amag = [norm(du[3N + 3 * (i - 1) + 1 : 3N + 3 * i]) for i in 1:N]
    fmag = [amag[i] * sys.nodes[i].mass for i in 1:N]
    afree = [amag[i] for i in 1:N if i != ground]
    isrope = [sys.nodes[i] isa RopeNode for i in 1:N]
    arope = [amag[i] for i in 1:N if isrope[i]]
    aring = [amag[i] for i in 1:N if sys.nodes[i] isa RingNode && i != ground]
    dwdt = abs.(du[6N + Nr + 1 : 6N + 2Nr])
    # Ring torque residual = J_ring · dω/dt.
    Jring = [sys.nodes[sys.ring_ids[k]].inertia_z for k in 1:Nr]
    tres = Jring .* dwdt

    α = u[6N + 1 : 6N + Nr]
    dα = diff(α)
    ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wf, lift)

    # Ring lateral offsets from the shaft axis.
    hub_pos = u[3*(sys.rotor.node_id-1)+1 : 3*sys.rotor.node_id]
    sd = norm(hub_pos) > 0.1 ? hub_pos ./ norm(hub_pos) : [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
    laterals = Float64[]
    for k in 1:Nr
        gid = sys.ring_ids[k]
        r = u[3*(gid-1)+1 : 3*gid]
        push!(laterals, norm(r .- dot(r, sd) .* sd))
    end

    @printf("\n== n_op = %d  (settle wall %.1f s) ==\n", n_op, t_settle)
    @printf("  ω_eq pinned            = %.4f rad/s\n", ω_eq)
    @printf("  max|a| free nodes      = %.4e m/s²   (= %.3e · g)\n", maximum(afree), maximum(afree)/9.81)
    @printf("    rope nodes           = %.4e m/s²   (m_node = %.3e kg)\n",
        maximum(arope), sys.nodes[findfirst(isrope)].mass)
    @printf("    ring nodes           = %.4e m/s²\n", maximum(aring))
    @printf("  max|F| residual node   = %.4e N\n", maximum(fmag))
    @printf("  max|a| all nodes       = %.4e m/s²   (ground ring %.4e)\n",
        maximum(amag), amag[ground])
    @printf("  max|dω/dt| rings       = %.4e rad/s² (= %.3e · ω_eq)\n", maximum(dwdt), maximum(dwdt)/ω_eq)
    @printf("  max|τ| residual ring   = %.4e N·m    (τ_gen = %.2f)\n",
        maximum(tres), K_MPPT_5KW_HONEST * ω_eq^2)
    @printf("  ring J                 = %s\n", join(round.(Jring, digits=3), ", "))
    @printf("  cumulative Δα          = %.2f°   first-seg %.2f°   max per-seg ratio %.4f\n",
        sum(dα)*180/π, dα[1]*180/π, maximum(dα)/(π/2))
    @printf("  per-seg twist (deg)    = %s\n", join(round.(dα .* 180 ./ π, digits=2), ", "))
    @printf("  segment torque (N·m)   = %s\n",
        join(round.(ef.segment_torque, digits=0), ", "))
    @printf("  hub lateral offset     = %.4f m   (per-ring lat max %.4f)\n",
        laterals[end], maximum(laterals))
    @printf("  τ_gen = k·ω²           = %.2f N·m\n", K_MPPT_5KW_HONEST * ω_eq^2)
end
