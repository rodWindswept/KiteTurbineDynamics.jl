#!/usr/bin/env julia
#= scripts/dashboard_prototype_per_rotor.jl
Prototype: per-rotor power metrics for KTD.jl dashboard redesign.

Shows:
1. How to extend SimFrame to capture per-rotor data
2. A concentric-gauge panel: outer ring = aero power, inner ring = power to ground
3. Gauges arranged in physical turbine order (hub → expansion rotors top-to-bottom)

Does NOT modify any KTD.jl source.  Run standalone to validate the data paths.
=#

using KiteTurbineDynamics
using GLMakie
using LinearAlgebra
using Printf

# ══════════════════════════════════════════════════════════════════════════════
# 1. Extended capture — per-rotor power
# ══════════════════════════════════════════════════════════════════════════════

"""
    capture_rotor_powers(u, sys, p, t, wind_fn, lift_device)
        -> (rotor_labels, P_aero, P_to_ground, omegas)

Returns per-rotor aerodynamic power and power transmitted to ground.
Order: hub rotor first, then expansion rotors in ascending ring-index order.
"""
function capture_rotor_powers(
    u::AbstractVector,
    sys::KiteTurbineSystem,
    p::SystemParams,
    t::Float64,
    wind_fn::Function,
    lift_device::Union{Nothing,LiftDevice}=nothing,
)
    N = sys.n_total
    Nr = sys.n_ring

    hub_gid = sys.rotor.node_id
    hub_ctr = u[(3*(hub_gid-1)+1):(3*hub_gid)]
    hub_z = max(hub_ctr[3], 1.0)

    v_vec = wind_fn(hub_ctr, t)
    V_hub = max(sqrt(v_vec[1]^2 + v_vec[2]^2), 0.1)

    omega_hub = u[6N + Nr + Nr]    # hub ring ω (ring_idx = Nr)
    omega_gnd = u[6N + Nr + 1]     # ground ring ω (ring_idx = 1)

    labels   = String[]
    P_aero   = Float64[]
    P_ground = Float64[]
    omegas   = Float64[]

    # ── Hub rotor ──────────────────────────────────────────────────────────
    lambda = clamp(abs(omega_hub) * sys.rotor.radius / V_hub, 0.0, 12.0)
    cp = cp_at_tsr(lambda)
    P_aero_hub = 0.5 * p.rho * V_hub^3 * π * sys.rotor.radius^2 *
                 cp * cos(p.elevation_angle)^2.65

    # Power to ground = generator electrical power
    tau_gen, _ = get_generator_torque(u, sys, p, t, wind_fn;
                                     brake_engaged=sys.brake_engaged[])
    P_kw = tau_gen * abs(omega_gnd) / 1000.0

    push!(labels, "Hub")
    push!(P_aero, P_aero_hub / 1000.0)      # kW
    push!(P_ground, P_kw)                    # kW (already in kW)
    push!(omegas, abs(omega_hub))

    # ── Expansion rotors ───────────────────────────────────────────────────
    if !isempty(sys.expansion_rotors)
        elev_deg = rad2deg(p.elevation_angle)

        for er in sys.expansion_rotors
            ri = er.ring_idx
            if ri < 1 || ri > Nr; continue; end

            ring_gid = sys.ring_ids[ri]
            ring_pos = u[(3*(ring_gid-1)+1):(3*ring_gid)]
            ring_omega = abs(u[6N + Nr + ri])
            r_nom = (sys.nodes[ring_gid]::RingNode).radius

            vw = wind_fn(ring_pos, t)
            v_mag = max(sqrt(vw[1]^2 + vw[2]^2), 0.1)

            # Tether tension estimate for force model
            hub_node = sys.nodes[hub_gid]::RingNode
            hub_ri = hub_node.ring_idx
            perp1, perp2 = _tilted_ring_basis(u, sys, hub_gid, hub_ri)
            T_est = 0.0
            for j in 1:p.n_lines
                T_est += get_segment_tension(u, sys, p, ri-1, j)
            end
            T_est = max(T_est / p.n_lines, 100.0)

            F_radial, F_axial, tau_net, r_eff, _ = expansion_rotor_forces(
                er, p.rho, v_mag, ring_omega, elev_deg,
                r_nom, T_est, p.n_lines
            )

            P_aero_i = tau_net * ring_omega / 1000.0       # kW
            P_ground_i = tau_net * abs(omega_gnd) / 1000.0  # kW via ground

            push!(labels, "R$(ri)")
            push!(P_aero, P_aero_i)
            push!(P_ground, max(0.0, P_ground_i))  # clamp negative = 0
            push!(omegas, ring_omega)
        end
    end

    return labels, P_aero, P_ground, omegas
end

# ══════════════════════════════════════════════════════════════════════════════
# 2. Concentric gauge panel — horizontal row, one gauge per rotor
# ══════════════════════════════════════════════════════════════════════════════

"""
    rotor_gauge!(gp, P_aero, P_ground, P_rated, label; max_radius=0.45)

Draw a single concentric-ring rotor power gauge in grid position `gp`.
- Outer ring (cyan): aerodynamic power captured
- Inner ring (green): power transmitted to ground
- Centre text: label + efficiency %
- Rings scaled so full sweep = P_rated per rotor
"""
function rotor_gauge!(gp, P_aero_kw, P_ground_kw, P_rated_kw, label::String;
                       max_radius=0.42)
    ax = Axis(gp; aspect=DataAspect(),
              backgroundcolor=RGBf(0.071, 0.086, 0.114),
              xgridvisible=false, ygridvisible=false)
    hidedecorations!(ax); hidespines!(ax)
    limits!(ax, -0.55, 0.55, -0.55, 0.55)

    # --- Outer ring: aero power (cyan) ---
    θ0 = deg2rad(225.0)
    sweep = deg2rad(270.0)
    n_pts = 80

    # Track ring (faint)
    θ_track = range(θ0, θ0 - sweep; length=n_pts)
    lines!(ax, max_radius .* cos.(θ_track), max_radius .* sin.(θ_track);
           color=RGBf(0.133, 0.165, 0.208), linewidth=6)

    # Aero power arc (cyan, outer ring)
    frac_aero = clamp(P_aero_kw / max(P_rated_kw, 0.1), 0.0, 1.0)
    n_aero = max(2, round(Int, n_pts * frac_aero))
    θ_aero = range(θ0, θ0 - sweep * frac_aero; length=n_aero)
    lines!(ax, max_radius .* cos.(θ_aero), max_radius .* sin.(θ_aero);
           color=RGBf(0.224, 0.816, 0.847), linewidth=6)  # A1_ACCENT cyan

    # --- Inner ring: ground power (green, smaller radius) ---
    inner_r = max_radius * 0.65
    frac_ground = clamp(P_ground_kw / max(P_rated_kw, 0.1), 0.0, 1.0)
    n_ground = max(2, round(Int, n_pts * frac_ground))
    θ_ground = range(θ0, θ0 - sweep * frac_ground; length=n_ground)
    lines!(ax, inner_r .* cos.(θ_ground), inner_r .* sin.(θ_ground);
           color=RGBf(0.2, 0.8, 0.3), linewidth=6)  # A1_GREEN

    # Efficiency % in centre
    eff = P_aero_kw > 0.01 ? P_ground_kw / P_aero_kw * 100.0 : 0.0
    eff_str = P_aero_kw > 0.01 ? @sprintf("%.0f%%", eff) : "—"
    text!(ax, 0, 0.06; text=eff_str, align=(:center, :center),
          fontsize=16, color=RGBf(0.910, 0.933, 0.965), font=:bold)

    # Label below
    text!(ax, 0, -0.32; text=label, align=(:center, :center),
          fontsize=11, color=RGBf(0.604, 0.655, 0.714))

    # Power numbers: aero above, ground below
    aero_str = @sprintf("%.1f kW", P_aero_kw)
    gnd_str  = @sprintf("%.1f kW", P_ground_kw)
    text!(ax, 0.05, 0.23; text=aero_str, align=(:center, :center),
          fontsize=8, color=RGBf(0.224, 0.816, 0.847))
    text!(ax, 0.05, -0.20; text=gnd_str, align=(:center, :center),
          fontsize=8, color=RGBf(0.2, 0.8, 0.3))

    return ax
end

"""
    rotor_power_panel!(grid_row, grid_col_start, labels, P_aero, P_ground, P_rated)

Place a row of concentric rotor power gauges starting at `grid_row, grid_col_start`.
One gauge per rotor, arranged left-to-right in physical turbine order.
"""
function rotor_power_panel!(fig, grid_row, grid_col_start,
                            labels, P_aero, P_ground, P_rated_kw)
    n = length(labels)
    for i in 1:n
        gp = fig[grid_row, grid_col_start + i - 1]
        P_rated_per = P_rated_kw / max(n, 1)
        rotor_gauge!(gp, P_aero[i], P_ground[i], P_rated_per, labels[i])
    end
end

# ══════════════════════════════════════════════════════════════════════════════
# 3. Demo — synthetic data to show the panel layout
# ══════════════════════════════════════════════════════════════════════════════

println("=== Per-Rotor Power Gauge Prototype ===")
println()
println("Data sources identified:")
println("  Hub rotor:  cp_at_tsr(lambda) × ½ρV³πR² — already in capture_frame()")
println("  Expansion:  expansion_rotor_forces() → tau_net × ω_ring  — called in ring_forces.jl every frame")
println("  Ground:     tau_net × ω_gnd  — power reaching generator from each rotor")
println()
println("To integrate: extend SimFrame with rotor_aero_power::Vector{Float64}")
println("              and rotor_ground_power::Vector{Float64}.")
println("              Add capture_rotor_powers() call in capture_frame().")
println()

# Show gauge arrangement for a 4-rotor configuration (V10 Tight)
A1_BG    = RGBf(0.039, 0.047, 0.063)
A1_INK   = RGBf(0.910, 0.933, 0.965)
A1_ACCENT = RGBf(0.224, 0.816, 0.847)

fig = Figure(size=(900, 300), backgroundcolor=A1_BG)

# Title
Label(fig[1, 1:4], "ROTOR POWER — Concentric Gauges  (outer = aero, inner = to ground)";
      fontsize=14, font=:bold, color=A1_ACCENT, halign=:center)

# Synthetic data: 4 rotors (hub + 3 expansion)
labels   = ["Hub", "R3", "R5", "R7"]
P_aero   = [8.5, 3.2, 2.1, 1.4]     # kW aero power per rotor
P_ground = [7.8, 2.4, 1.3, 0.6]     # kW to ground per rotor
P_rated  = 15.0                      # kW total rated (50 kW scaled for demo)

rotor_power_panel!(fig, 2, 1, labels, P_aero, P_ground, P_rated)

display(fig)
println("✓ Gauge panel rendered")
println()
println("Next: integrate capture_rotor_powers() into SimFrame")
println("      Wire gauges to live Observables in dashboard HUD")
