#!/usr/bin/env julia
# scripts/wake_overlap_audit.jl — quantify streamtube sharing across the rotor stack
#
# Question (Rod, 2026-07-18): the TRPT is tilted and the rotors are spaced along
# the shaft with clearance — how much do the swept annuli actually overlap when
# projected along the wind direction? This bounds the conservation error from
# modelling each rotor with independent BEM (no wake coupling).
#
# Method: pure geometry, no ODE. Take as-built positions (u0), project every
# rotor's swept annulus onto the y-z plane (wind = +x), Monte Carlo the pairwise
# overlaps and the union area. Report:
#   - pairwise overlap % (downstream disk area shadowed by upstream disk)
#   - union area vs naive sum (streamtube sharing factor)
#   - corrected Betz ceiling using the union area
# Wake expansion bounds: none (near-field) and ×1.41 radius (far-field, a=1/3).
using KiteTurbineDynamics, Printf, LinearAlgebra, Random
include(joinpath(dirname(@__DIR__), "src", "builders_util.jl"))

const NS = 200_000  # MC samples per annulus

struct Disk
    name::String
    center::Vector{Float64}
    axis::Vector{Float64}     # unit
    r_in::Float64             # annulus inner radius about shaft axis
    r_out::Float64
end

# Project point onto y-z plane (drop x); wake convects along +x
proj(pt) = (pt[2], pt[3])

function sample_annulus(d::Disk, n)
    # orthonormal basis ⊥ axis
    a = d.axis
    t1 = abs(a[1]) < 0.9 ? normalize(cross(a, [1.0,0,0])) : normalize(cross(a, [0,1.0,0]))
    t2 = cross(a, t1)
    pts = Matrix{Float64}(undef, 2, n)
    for i in 1:n
        r = sqrt(rand()*(d.r_out^2 - d.r_in^2) + d.r_in^2)
        θ = 2π*rand()
        p3 = d.center .+ r*cos(θ).*t1 .+ r*sin(θ).*t2
        pts[1,i], pts[2,i] = proj(p3)
    end
    pts
end

# point-in-projected-annulus test: project the QUERY disk's annulus by checking
# whether the 2D point lies inside the projected ellipse band. We approximate by
# sampling the upstream annulus densely into a grid mask.
struct Mask
    x0::Float64; y0::Float64; h::Float64; nx::Int; ny::Int
    grid::BitMatrix
end

function build_mask(pts::Matrix{Float64}; h=0.05, pad=0.2, expand::Float64=1.0, center=(0.0,0.0))
    # optional radial expansion about the disk's own projected centroid
    cx = sum(pts[1,:])/size(pts,2); cy = sum(pts[2,:])/size(pts,2)
    if expand != 1.0
        pts = vcat((cx .+ (pts[1:1,:] .- cx).*expand), (cy .+ (pts[2:2,:] .- cy).*expand))
    end
    xmin, xmax = extrema(pts[1,:]); ymin, ymax = extrema(pts[2,:])
    xmin -= pad; ymin -= pad; xmax += pad; ymax += pad
    nx = max(4, ceil(Int, (xmax-xmin)/h)); ny = max(4, ceil(Int, (ymax-ymin)/h))
    g = falses(nx, ny)
    for i in 1:size(pts,2)
        ix = clamp(floor(Int, (pts[1,i]-xmin)/h)+1, 1, nx)
        iy = clamp(floor(Int, (pts[2,i]-ymin)/h)+1, 1, ny)
        g[ix,iy] = true
    end
    # dilate once to close MC speckle
    g2 = copy(g)
    for ix in 2:nx-1, iy in 2:ny-1
        g[ix,iy] && (g2[ix-1,iy]=true; g2[ix+1,iy]=true; g2[ix,iy-1]=true; g2[ix,iy+1]=true)
    end
    Mask(xmin, ymin, h, nx, ny, g2)
end

inmask(m::Mask, x, y) = begin
    ix = floor(Int, (x-m.x0)/m.h)+1; iy = floor(Int, (y-m.y0)/m.h)+1
    (1 ≤ ix ≤ m.nx && 1 ≤ iy ≤ m.ny) ? m.grid[ix,iy] : false
end

function audit(build_fn, label, blade_scale)
    println("═"^64)
    sys, u0, p, name, design = Base.invokelatest(build_fn; blade_scale=blade_scale)
    println("AUDIT: $label — $name")
    β = p.elevation_angle
    @printf("elevation β = %.1f°\n", rad2deg(β))
    N = sys.n_total

    ring_pos(gid) = u0[(3*(gid-1)+1):(3*gid)]

    # shaft axis from ground ring to hub ring
    g1 = sys.ring_ids[1]; gH = sys.ring_ids[end]
    axis = normalize(ring_pos(gH) .- ring_pos(g1))

    disks = Disk[]
    # hub rotor disk (main BEM disk at top of shaft)
    hub_c = ring_pos(gH)
    push!(disks, Disk("hub", hub_c, axis, 0.0, p.rotor_radius))
    # expansion rotors: annulus about the shaft axis: ring radius ± blade offsets
    for (i, er) in enumerate(sys.expansion_rotors)
        idx = clamp(er.ring_idx, 1, length(sys.ring_ids))
        c = ring_pos(sys.ring_ids[idx])
        # ring radius at that station: use design r (untapered phantom: r_hub)
        rring = design.r_hub  # phantom untapered; 12gon: hub value adequate first cut
        push!(disks, Disk("rotor$(i)(ring$(er.ring_idx))", c, axis,
                          max(rring + er.blade_hub_radius, 0.0),
                          rring + er.blade_tip_radius))
    end

    for d in disks
        Δx = d.center[1] - disks[1].center[1]
        @printf("  %-16s center=(%.1f, %.1f, %.1f)  r=[%.2f, %.2f] m  Δx_vs_hub=%.1f m\n",
                d.name, d.center..., d.r_in, d.r_out, Δx)
    end

    # order by along-wind position (x): smallest x = most upwind
    order = sortperm([d.center[1] for d in disks])

    for expand in (1.0, 1.41)
        println("--- wake radius expansion ×$(expand) ---")
        # pairwise: fraction of DOWNSTREAM disk shadowed by upstream disk's wake
        masks = Dict{Int,Mask}()
        samples = Dict{Int,Matrix{Float64}}()
        for (di, d) in enumerate(disks)
            samples[di] = sample_annulus(d, NS)
            masks[di] = build_mask(samples[di]; expand=expand)
        end
        Atot_naive = 0.0
        for (di, d) in enumerate(disks)
            A = π*(d.r_out^2 - d.r_in^2) * abs(axis[1] ≈ 1.0 ? 1.0 : 1.0)  # raw annulus
            Atot_naive += A
        end
        for ui in order, dj in order
            ui == dj && continue
            du, dd = disks[ui], disks[dj]
            du.center[1] < dd.center[1] || continue  # only upstream→downstream
            s = samples[dj]
            hits = count(i -> inmask(masks[ui], s[1,i], s[2,i]), 1:size(s,2))
            @printf("  %s wake ∩ %s : %.0f%% of downstream disk\n",
                    du.name, dd.name, 100*hits/size(s,2))
        end
        # union area via global grid
        allpts = hcat([samples[i] for i in eachindex(disks)]...)
        gm = build_mask(allpts; expand=1.0)  # union of projections (no expansion on union)
        Aunion = count(gm.grid) * gm.h^2
        # projected (⊥ wind) naive sum for fair comparison
        Aproj_sum = 0.0
        for i in eachindex(disks)
            m = build_mask(samples[i]; expand=1.0)
            Aproj_sum += count(m.grid) * m.h^2
        end
        share = 1.0 - Aunion/Aproj_sum
        @printf("  projected areas: sum=%.1f m²  union=%.1f m²  → streamtube sharing %.0f%%\n",
                Aproj_sum, Aunion, 100*share)
        for v in (11.0, 15.0)
            betz = 0.593 * 0.5 * p.rho * Aunion * v^3 / 1000
            @printf("  Betz ceiling on union @ %.0f m/s: %.1f kW\n", v, betz)
        end
    end
    return nothing
end

Random.seed!(42)
audit(build_phantom_triangle, "TRIANGLE3 (phantom, λ=0.85)", 0.85)
audit(build_v10_tight_no_lowest, "12-GON (corrected, λ=0.85)", 0.85)
println("\nDone.")
