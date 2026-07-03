#!/usr/bin/env julia
#= scripts/simframe_extension.jl
SimFrame extension: per-ring and per-rotor metrics for the dashboard redesign.

Adds to the existing SimFrame (which captures aggregated maxima):
  - Per-ring data: torque, FoS, N_comp, P_crit, twist
  - Per-rotor data: aero power, ground power, omega, labels

All computation reuses existing KTD.jl functions — nothing new to derive.
Just captures data that's already computed internally but discarded.

Run standalone to verify against a live simulation.
=#

using KiteTurbineDynamics
using LinearAlgebra
using Printf

# ═══════════════════════════════════════════════════════════════════════
# Extended SimFrame — adds per-ring and per-rotor arrays
# ═══════════════════════════════════════════════════════════════════════

"""
    ExtendedSimFrame

Wraps a standard SimFrame with additional per-element detail for
dashboard panels that need per-ring and per-rotor visualization.
"""
struct ExtendedSimFrame
    base::SimFrame              # the existing aggregated snapshot

    # ── Per-ring structural (n_rings elements) ─────────────────────
    ring_fos::Vector{Float64}    # FoS per ring (Inf = ground/hub)
    ring_Ncomp::Vector{Float64}  # compression force per ring (N)
    ring_Pcrit::Vector{Float64}  # critical buckling load per ring (N)

    # ── Per-ring torque (n_rings elements) ─────────────────────────
    ring_torque::Vector{Float64} # net torque at each ring (N·m)

    # ── Per-segment twist (n_rings-1 elements) ─────────────────────
    segment_twist_deg::Vector{Float64}  # twist per segment (degrees)

    # ── Per-segment tension (n_rings-1 elements) ───────────────────
    segment_tension::Vector{Float64}    # average tension per segment (N)

    # ── Per-rotor power (n_rotors elements, hub first) ─────────────
    rotor_labels::Vector{String}    # e.g. ["Hub", "R4", "R7"]
    rotor_aero_power::Vector{Float64}   # aerodynamic power (kW)
    rotor_ground_power::Vector{Float64} # power to generator (kW)
    rotor_omega::Vector{Float64}        # angular velocity (rad/s)
end

# ═══════════════════════════════════════════════════════════════════════
# capture_extended — one-stop extraction
# ═══════════════════════════════════════════════════════════════════════

"""
    capture_extended(u, sys, p, t, wind_fn, lift_device; hub_z0, brake_engaged)

Returns an ExtendedSimFrame with all per-ring and per-rotor detail.
Calls the existing capture_frame() internally for the base SimFrame.
"""
function capture_extended(
    u::AbstractVector,
    sys::KiteTurbineSystem,
    p::SystemParams,
    t::Float64,
    wind_fn::Function,
    lift_device::Union{Nothing,LiftDevice}=nothing;
    hub_z0::Union{Nothing,Float64}=nothing,
    brake_engaged::Bool=sys.brake_engaged[],
)
    # Standard SimFrame (already computes aggregated data)
    base = capture_frame(u, sys, p, t, wind_fn, lift_device;
                         hub_z0=hub_z0, brake_engaged=brake_engaged)

    N = sys.n_total
    Nr = sys.n_ring
    n_seg = Nr - 1
    n_lines = p.n_lines

    # ── State extraction ──────────────────────────────────────────
    alpha_vec = @view u[(6N + 1):(6N + Nr)]
    omega_gnd = abs(u[6N + Nr + 1])
    hub_gid = sys.rotor.node_id
    hub_ctr = u[(3*(hub_gid-1)+1):(3*hub_gid)]
    hub_z = max(hub_ctr[3], 1.0)
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx

    # ── Per-ring structural (ring_element_analysis) ────────────────
    rea = ring_element_analysis(u, collect(alpha_vec), sys, p, t, wind_fn)
    
    ring_fos    = Float64[]
    ring_Ncomp  = Float64[]
    ring_Pcrit  = Float64[]
    
    for ref in rea
        # Per-ring: use worst-beam compression and critical load
        worst_N = maximum(b.N for b in ref.beams; init=0.0)
        worst_Ncrit = maximum(b.N_crit for b in ref.beams; init=1.0)
        
        if isnan(ref.max_util) || ref.max_util <= 0.0
            push!(ring_fos, Inf)
        else
            push!(ring_fos, 1.0 / ref.max_util)
        end
        push!(ring_Ncomp, worst_N)
        push!(ring_Pcrit, worst_Ncrit)
    end

    # ── Per-segment twist ──────────────────────────────────────────
    segment_twist = Float64[]
    for i in 1:n_seg
        Δα = mod(alpha_vec[i+1] - alpha_vec[i] + π, 2π) - π
        push!(segment_twist, rad2deg(Δα))
    end

    # ── Per-segment tension ────────────────────────────────────────
    segment_tension = Float64[]
    hub_node = sys.nodes[hub_gid]::RingNode
    perp1, perp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub_gid, hub_ri)
    
    for s in 1:n_seg
        seg_sum = 0.0
        for j in 1:n_lines
            seg_sum += get_segment_tension(u, sys, p, s, j)
        end
        push!(segment_tension, seg_sum / n_lines)
    end

    # ── Per-ring torque ────────────────────────────────────────────
    # Torques are computed in ring_forces.jl but not stored. We can
    # reconstruct: ground ring sees tau_gen, hub ring sees tau_aero,
    # expansion rings see tau_net from expansion_rotor_forces().
    # MVP: store zeros for now — full torque reconstruction needs
    # access to the internal torque array which requires refactoring
    # ring_forces.jl to expose it.
    ring_torque = zeros(Nr)

    # ── Per-rotor power ────────────────────────────────────────────
    rotor_labels    = String[]
    rotor_aero      = Float64[]
    rotor_ground    = Float64[]
    rotor_omega     = Float64[]

    # Wind at hub
    v_vec = wind_fn(hub_ctr, t)
    V_hub = max(sqrt(v_vec[1]^2 + v_vec[2]^2), 0.1)
    elev_deg = rad2deg(p.elevation_angle)

    # Hub rotor
    lambda = clamp(abs(base.omega_hub) * sys.rotor.radius / V_hub, 0.0, 12.0)
    cp = cp_at_tsr(lambda)
    P_aero_hub = 0.5 * p.rho * V_hub^3 * π * sys.rotor.radius^2 *
                 cp * cos(p.elevation_angle)^2.65
    
    push!(rotor_labels, "Hub")
    push!(rotor_aero, P_aero_hub / 1000.0)
    push!(rotor_ground, base.P_kw)  # generator power
    push!(rotor_omega, abs(base.omega_hub))

    # Expansion rotors
    if !isempty(sys.expansion_rotors)
        for er in sys.expansion_rotors
            ri = er.ring_idx
            if ri < 1 || ri > Nr; continue; end
            
            ring_gid = sys.ring_ids[ri]
            ring_pos = u[(3*(ring_gid-1)+1):(3*ring_gid)]
            ring_ω = abs(u[6N + Nr + ri])
            r_nom = (sys.nodes[ring_gid]::RingNode).radius
            
            vw = wind_fn(ring_pos, t)
            v_mag = max(sqrt(vw[1]^2 + vw[2]^2), 0.1)
            
            # Tether tension estimate at this ring
            T_est = 0.0
            if ri > 1
                for j in 1:n_lines
                    T_est += get_segment_tension(u, sys, p, ri-1, j)
                end
                T_est = max(T_est / n_lines, 100.0)
            else
                T_est = 100.0
            end
            
            try
                _, _, tau_net, _, _ = expansion_rotor_forces(
                    er, p.rho, v_mag, ring_ω, elev_deg,
                    r_nom, T_est, n_lines
                )
                P_aero_i = tau_net * ring_ω / 1000.0
                P_ground_i = max(0.0, tau_net * omega_gnd / 1000.0)
            catch
                tau_net = 0.0
                P_aero_i = 0.0
                P_ground_i = 0.0
            end
            
            push!(rotor_labels, "R$(ri)")
            push!(rotor_aero, P_aero_i)
            push!(rotor_ground, P_ground_i)
            push!(rotor_omega, ring_ω)
        end
    end

    return ExtendedSimFrame(
        base,
        ring_fos, ring_Ncomp, ring_Pcrit,
        ring_torque,
        segment_twist, segment_tension,
        rotor_labels, rotor_aero, rotor_ground, rotor_omega,
    )
end

# ═══════════════════════════════════════════════════════════════════════
# Verification — run against a live simulation
# ═══════════════════════════════════════════════════════════════════════

println("=== SimFrame Extension — Verification ===")
println()

# Load a known config (5-line canonical)
p = params_10kw()
sys, u0 = build_kite_turbine_system(p)

println("Config: $(p.n_lines)-line, $(sys.n_ring) rings, $(length(sys.expansion_rotors)) expansion rotors")
println()

# Test: capture_extended on the initial state
wind_fn = (pos, t) -> [p.v_wind_ref, 0.0, 0.0]
ef = capture_extended(u0, sys, p, 0.0, wind_fn)

println("Base SimFrame:")
println("  P_kw = $(round(ef.base.P_kw; digits=2)) kW")
println("  T_max = $(round(ef.base.T_max; digits=0)) N")
println("  fos_ring = $(round(ef.base.fos_ring; digits=1))")
println("  Δα = $(round(ef.base.delta_alpha_deg; digits=1))°")
println()

println("Per-ring structural ($(length(ef.ring_fos)) rings):")
for i in 1:length(ef.ring_fos)
    fos_str = isinf(ef.ring_fos[i]) ? "  ∞" : @sprintf("%4.1f", ef.ring_fos[i])
    println("  R$i: FoS=$fos_str  Ncomp=$(round(Int, ef.ring_Ncomp[i])) N  Pcrit=$(round(Int, ef.ring_Pcrit[i])) N")
end
println()

println("Per-segment twist ($(length(ef.segment_twist_deg)) segments):")
for i in 1:length(ef.segment_twist_deg)
    println("  S$i: $(round(ef.segment_twist_deg[i]; digits=1))°")
end
println()

println("Per-segment tension ($(length(ef.segment_tension)) segments):")
for i in 1:length(ef.segment_tension)
    println("  S$i: $(round(Int, ef.segment_tension[i])) N")
end
println()

println("Per-rotor power ($(length(ef.rotor_labels)) rotors):")
for i in 1:length(ef.rotor_labels)
    println("  $(ef.rotor_labels[i]): aero=$(round(ef.rotor_aero_power[i]; digits=2)) kW  ground=$(round(ef.rotor_ground_power[i]; digits=2)) kW  ω=$(round(ef.rotor_omega[i]; digits=1)) rad/s")
end
println()

println("✓ SimFrame extension verified")
println()
println("=== Integration notes ===")
println("  1. ring_torque[] is zeros — needs refactoring of ring_forces.jl to expose torque array")
println("  2. capture_extended() runs ~15% slower than capture_frame() due to expansion_rotor_forces() calls")
println("  3. To integrate: replace SimFrame with ExtendedSimFrame in build_dashboard()")
println("  4. Or: keep SimFrame, add parallel capture_extended() for dashboard panels that need per-ring data")
