#!/usr/bin/env julia
# scripts/animate_torsional_collapse.jl
# Renders a 3D animation showing the "Torsional Collapse" failure mode of the TRPT shaft.

using Pkg; Pkg.activate(dirname(@__DIR__))
ENV["GKSwstype"] = "nul"

using KiteTurbineDynamics, Printf, LinearAlgebra

const M = try
    @eval using GLMakie
    GLMakie.activate!()
    GLMakie
catch
    error("GLMakie is required for 3D animation.")
end

function get_v2_failing_design()
    # Island 1 from v2: 10kW circular, mass ~2.8 kg, FOS_tor ~0.069
    # We construct the geometry manually here for self-containment.
    r_hub = 1.6
    taper = 0.25
    r_bot = r_hub * taper # 0.4
    n_rings_int = 5
    L_total = 30.0
    n_lines = 8
    
    n_rings = n_rings_int + 2 # 7 total
    radii = [r_bot + (r_hub - r_bot) * (i-1)/(n_rings-1) for i in 1:n_rings]
    L_seg = L_total / (n_rings - 1)
    
    return radii, L_seg, n_lines, n_rings
end

function main()
    radii, L_seg, n_lines, n_rings = get_v2_failing_design()
    
    # ── Setup Figure ──────────────────────────────────────────────────────────
    fig = M.Figure(size = (1200, 1000), backgroundcolor = :white)
    
    ax = M.Axis3(fig[1, 1],
                 title = "TRPT Torsional Collapse (Tulloch/Wacker Failure Mode)\nApplied Torque vs Structural Restoring Force",
                 xlabel = "x (m)", ylabel = "y (m)", zlabel = "Altitude (m)",
                 aspect = :data)
                 
    # Set limits to prevent jumping
    M.xlims!(ax, -2.5, 2.5)
    M.ylims!(ax, -2.5, 2.5)
    M.zlims!(ax, 0, 31)

    # ── Observables for Animation ─────────────────────────────────────────────
    # We will twist the top ring (hub) linearly over time.
    # The twist propagates down the shaft. Because the bottom rings are small (r=0.4),
    # they have very little torque arm. The lines will bunch up and cross the center axis.
    
    time_t = M.Observable(0.0)
    
    # We use a Node to hold the coordinates of the nodes.
    # Array of rings, each ring has an array of n_lines 3D points.
    
    function compute_nodes(t)
        # Apply a twist at the top (hub)
        max_twist_rad = t * 1.5 * π  # Twist up to 1.5 turns over the animation
        
        # Assume twist drops off linearly from top to bottom (linear torsional spring approximation)
        # In a real collapse, the narrowest segments twist the most, but a linear twist
        # beautifully demonstrates the lines crossing the origin (collapse).
        
        nodes_out = Vector{Vector{M.Point3f}}(undef, n_rings)
        
        # Ground ring is fixed at z=0, phi=0
        current_z = 0.0
        
        # We will distribute the total top twist across the segments.
        # Since smaller rings are more compliant torsionally, they twist more.
        # For a simple kinematic demonstration, we'll weight the twist inverse to r_min^2
        # to loosely mimic physical compliance.
        r_mins = [min(radii[i], radii[i+1]) for i in 1:n_rings-1]
        compliances = 1.0 ./ (r_mins.^2)
        total_comp = sum(compliances)
        twist_fractions = compliances ./ total_comp
        
        phi = zeros(n_rings)
        for i in 1:n_rings-1
            phi[i+1] = phi[i] + max_twist_rad * twist_fractions[i]
        end
        
        for i in 1:n_rings
            # Calculate geometric Z height based on inextensible tethers
            if i > 1
                delta_phi = phi[i] - phi[i-1]
                R1 = radii[i-1]
                R2 = radii[i]
                
                # Original tether length squared (assuming it was straight when untwisted)
                l0_sq = L_seg^2 + (R2 - R1)^2
                
                # Current dz based on Pythagorean theorem for twisted segment
                # l0^2 = dz^2 + R1^2 + R2^2 - 2*R1*R2*cos(delta_phi)
                val = l0_sq - R1^2 - R2^2 + 2*R1*R2*cos(delta_phi)
                
                if val <= 0.0
                    dz = 0.0 # Shaft has fully bound and collapsed!
                else
                    dz = sqrt(val)
                end
                current_z += dz
            end
            
            r = radii[i]
            ring_pts = Vector{M.Point3f}(undef, n_lines)
            for j in 1:n_lines
                angle = 2π * (j - 1) / n_lines + phi[i]
                ring_pts[j] = M.Point3f(r * cos(angle), r * sin(angle), current_z)
            end
            nodes_out[i] = ring_pts
        end
        return nodes_out
    end
    
    nodes = M.lift(compute_nodes, time_t)

    # ── Rendering ─────────────────────────────────────────────────────────────
    
    # 1. Draw Ring Frames
    for i in 1:n_rings
        ring_poly = M.lift(n -> push!(copy(n[i]), n[i][1]), nodes)
        # Bottom rings (which fail) are red, top rings are blue
        col = M.RGBAf(1.0 - (i/n_rings), 0.2, (i/n_rings), 0.8)
        M.lines!(ax, ring_poly, color = col, linewidth = 4)
    end
    
    # 2. Draw Tether Lines
    for j in 1:n_lines
        tether_line = M.lift(n -> [n[i][j] for i in 1:n_rings], nodes)
        M.lines!(ax, tether_line, color = :grey50, linewidth = 2)
    end
    
    # Add a visual indicator of the torque being applied
    torque_label = M.lift(t -> @sprintf("Applied Torque: %4.0f N·m", t * 5000), time_t)
    M.Label(fig[1, 1], torque_label, tellwidth=false, tellheight=false, 
            halign=:left, valign=:top, padding=(20,20,20,20), fontsize=24, color=:red, font=:bold)

    # ── Record Animation ──────────────────────────────────────────────────────
    out_path = joinpath(dirname(@__DIR__), "figures", "anim_torsional_collapse.mp4")
    mkpath(dirname(out_path))
    
    println("Recording animation to $out_path ...")
    framerate = 30
    duration = 4.0 # seconds
    
    M.record(fig, out_path, 0:(1/framerate):duration; framerate=framerate) do t
        time_t[] = t
        # Move the camera to slowly rotate around the structure
        ax.azimuth[] = -π/4 + t * 0.2
        ax.elevation[] = π/8
    end
    
    println("Animation complete.")
end

main()
