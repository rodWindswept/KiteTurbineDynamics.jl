#!/usr/bin/env julia
# scripts/interactive_dashboard.jl
# Interactive GLMakie dashboard for KiteTurbineDynamics.jl.
# Run:  julia --project=. scripts/interactive_dashboard.jl

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, GLMakie, Printf, LinearAlgebra

p       = params_10kw()
sys, u0 = build_kite_turbine_system(p)
u_start = settle_to_equilibrium(sys, u0, p)

N  = sys.n_total
Nr = sys.n_ring

# ── Equilibrium initialization ────────────────────────────────────────────────
# Goal: start the simulation AT the rated operating point so there is no torsional
# transient that would cause hub reversal and zero power output.
#
# Strategy:
#   1. Set all rings to uniform ω = ω_rated (no inter-ring Δω → no torsional kick).
#   2. For each segment, find Δα_eq via bisection such that:
#        τ_rope(Δα_eq) = τ_rated  =  k_mppt × ω_rated²  ≈  993 N·m
#      The τ_fn EXACTLY mirrors rope_forces.jl: uses actual settled ring-centre
#      positions (which have sagged under gravity) and the identical cross-product
#      torque formula.  The old analytical approximation (chord from shaft-axis
#      geometry) gave ~22% error because it assumed rings sit on the ideal shaft
#      axis — they don't after settle_to_equilibrium.
#   3. Set cumulative α profile and update rope node positions geometrically.
#
# Why not a gradient?  A linear ω gradient (0→9 rad/s) gives Δω=0.6 rad/s between
# every adjacent pair of rings. With the corrected torsional spring (~30 kN·m/rad),
# that Δω drives rapid Δα growth → large torsional forces → hub decelerates and
# reverses to ω<0. The old sign(ω) formula then gives negative aero torque, locking
# the hub in reverse indefinitely. Uniform ω eliminates this entirely.
let ω_rated = 9.5    # true aero equilibrium: τ_aero(9.5) ≈ τ_gen(9.5) ≈ 993 N·m
    τ_rated  = p.k_mppt * ω_rated^2        # ≈ 993 N·m at ω=9.5 rad/s
    EA_rope  = p.e_modulus * π * (p.tether_diameter / 2)^2  # single-rope axial stiffness (N)
    L_seg    = p.tether_length / (Nr - 1)  # natural segment length (m)
    β_a      = p.elevation_angle
    sd       = [cos(β_a), 0.0, sin(β_a)]
    pp1, pp2 = shaft_perp_basis(sd)

    # 1. Uniform ω — zero inter-ring velocity difference at t=0
    for ri in 1:Nr
        u_start[6N + Nr + ri] = ω_rated
    end

    # 2. Per-segment equilibrium twist via torque-chain bisection.
    #
    # Key insight: off-axis ring sag means the torque delivered to the LOWER ring
    # of a segment (τ_a) ≠ minus the torque delivered to the UPPER ring (τ_b).
    # Bisecting for τ_a = τ_rated on every segment leaves intermediate rings with
    # ~100 N·m residual torques → rapid dω/dt → torsional oscillation → hub reversal.
    #
    # Fix: propagate a torque chain from the ground ring upward.
    #   - Segment 1: find Δα_1 such that τ_a(ground ring) = τ_rated.
    #   - Compute τ_b that segment 1 delivers to ring 2 (upper ring).
    #   - Segment 2: find Δα_2 such that τ_a(ring 2) = -τ_b^{seg1}  ← cancels exactly.
    #   - Repeat. This ensures every intermediate ring has net rope torque = 0.
    u_start[6N + 1] = 0.0   # ground ring: α = 0 (reference)
    α_cum      = 0.0
    τ_target_a = τ_rated   # torque needed on the LOWER ring of the first segment

    for s in 1:(Nr - 1)
        gid_a = sys.ring_ids[s]
        gid_b = sys.ring_ids[s + 1]
        na    = sys.nodes[gid_a]::RingNode
        nb    = sys.nodes[gid_b]::RingNode

        # Actual settled ring-centre positions (may be slightly off-axis due to gravity).
        ctr_a = u_start[3*(gid_a-1)+1 : 3*gid_a]
        ctr_b = u_start[3*(gid_b-1)+1 : 3*gid_b]

        # τ_fn_a(Δα): torque on ring_a (lower ring) — mirrors rope_forces.jl exactly.
        τ_fn_a = (Δα) -> begin
            τ = 0.0
            for j in 1:p.n_lines
                pa_j    = attachment_point(ctr_a, na.radius, α_cum,       j, p.n_lines, pp1, pp2)
                pb_j    = attachment_point(ctr_b, nb.radius, α_cum + Δα,  j, p.n_lines, pp1, pp2)
                chord_j = norm(pb_j .- pa_j)
                chord_j < 1e-9 && continue
                T_j     = EA_rope * max(0.0, (chord_j - L_seg) / L_seg)
                dir_j   = (pb_j .- pa_j) ./ chord_j
                r_vec_a = pa_j .- ctr_a
                τ      += T_j * dot(cross(r_vec_a, dir_j), sd)
            end
            τ
        end

        # Bisect on [0.001, π/4] to match τ_target_a.
        lo, hi = 0.001, π / 4
        for _ in 1:60
            mid = (lo + hi) / 2
            τ_fn_a(mid) < τ_target_a ? (lo = mid) : (hi = mid)
        end
        Δα_eq = (lo + hi) / 2

        # Compute τ_b: torque this segment delivers to the UPPER ring (ring_b).
        # The next segment's lower ring must provide -τ_b to give ring_b net = 0.
        τ_b = 0.0
        for j in 1:p.n_lines
            pa_j    = attachment_point(ctr_a, na.radius, α_cum,         j, p.n_lines, pp1, pp2)
            pb_j    = attachment_point(ctr_b, nb.radius, α_cum + Δα_eq, j, p.n_lines, pp1, pp2)
            chord_j = norm(pb_j .- pa_j)
            chord_j < 1e-9 && continue
            T_j     = EA_rope * max(0.0, (chord_j - L_seg) / L_seg)
            dir_j   = (pb_j .- pa_j) ./ chord_j
            r_vec_b = pb_j .- ctr_b
            τ_b    += T_j * dot(cross(r_vec_b, -dir_j), sd)
        end
        τ_target_a = -τ_b   # next lower ring must cancel this segment's load on ring_b

        α_cum += Δα_eq
        u_start[6N + nb.ring_idx] = α_cum

        # 3. Rope nodes consistent with equilibrium twist for this segment.
        α_a = u_start[6N + na.ring_idx]
        α_b = u_start[6N + nb.ring_idx]
        for j in 1:p.n_lines
            pa = attachment_point(ctr_a, na.radius, α_a, j, p.n_lines, pp1, pp2)
            pb = attachment_point(ctr_b, nb.radius, α_b, j, p.n_lines, pp1, pp2)
            for m in 1:3
                frac = m / 4.0
                gid  = (s - 1) * 16 + 2 + (j - 1) * 3 + (m - 1)
                u_start[3*(gid-1)+1 : 3*gid] .= pa .+ frac .* (pb .- pa)
            end
        end
    end
    println("Equilibrium init: α_hub = $(round(α_cum, digits=3)) rad " *
            "($(round(rad2deg(α_cum), digits=1))°),  τ_rated = $(round(τ_rated, digits=0)) N·m,  " *
            "ω = $(ω_rated) rad/s (all rings)")
end

# ── CRITICAL FIX 1: set rope node velocities to orbital ──────────────────
# After settle, rope nodes have O(1) m/s residual translational velocities that
# feed c_damp·vel_proj in compute_rope_forces!, creating 100–150 N·m spurious
# torsional torques on every intermediate ring → hub reversal.
#
# Solution: set each rope node's velocity to its expected orbital velocity
# (the velocity it would have if it perfectly tracked ring rotation).
# Ring-node translational velocities are zeroed (ring centres don't drift).
set_orbital_velocities!(u_start, sys, p)
@views u_start[3N + 3*(sys.ring_ids[1]-1)+1 : 3N + 3*sys.ring_ids[1]] .= 0.0  # ground ring fixed
println("Rope velocities set to orbital (ring-tracking) values.")

u_settled = copy(u_start)     # keep settled state for scenario re-runs

wind_fn = (pos, t) -> begin
    z  = max(pos[3], 1.0)
    sh = (z / p.h_ref)^(1.0/7.0)
    [p.v_wind_ref * sh, 0.0, 0.0]
end

# ── Explicit integrator ───────────────────────────────────────────────────────
# dt=4e-5 s, save every 500 steps = 0.02 s per frame.
# 250 000 steps → 10 s simulated → 500 frames → ~16 s playback at 30 fps.
const SAVE_EVERY    = 500
const N_STEPS_TOTAL = 250_000
const DT            = 4e-5
const LIN_DAMP      = 0.05   # Stability-driven kill: (1 + ω_max·dt)·damp < 1.
                              # Torsional coupling is now explicit (ring-to-ring spring
                              # in ring_forces.jl), independent of rope-node propagation.

n_frames = N_STEPS_TOTAL ÷ SAVE_EVERY
frames   = Vector{Vector{Float64}}(undef, n_frames)
times    = Vector{Float64}(undef, n_frames)

u  = copy(u_start)
du = zeros(Float64, length(u))

println("Simulating $(N_STEPS_TOTAL * DT) s  ($N_STEPS_TOTAL steps → $n_frames frames)...")
let t = 0.0, fi = 1
    for step in 1:N_STEPS_TOTAL
        fill!(du, 0.0)
        multibody_ode!(du, u, (sys, p, wind_fn), t)
        t += DT

        @views u[3N+1:6N]        .+= DT .* du[3N+1:6N]
        @views u[1:3N]            .+= DT .* u[3N+1:6N]
        @views u[6N+Nr+1:6N+2Nr] .+= DT .* du[6N+Nr+1:6N+2Nr]
        @views u[6N+1:6N+Nr]     .+= DT .* u[6N+Nr+1:6N+2Nr]

        # Orbital-frame damping: kill rope OSCILLATIONS but preserve orbital rotation.
        # Flat .*= LIN_DAMP would kill the ~5 m/s orbital velocity, requiring
        # O(1e5 m/s²) of force to maintain rotation — physically impossible.
        orbital_damp_rope_velocities!(u, sys, p, LIN_DAMP)
        # angular velocity: no kill — hub spins freely under aero/generator balance

        u[1:3]       .= 0.0   # ground ring centre stays at origin
        u[3N+1:3N+3] .= 0.0   # ground ring translational velocity = 0
        # alpha[1] and omega[1] evolve freely — ground ring IS the generator input shaft

        if step % SAVE_EVERY == 0
            frames[fi] = copy(u)
            times[fi]  = t
            fi += 1
        end
    end
end

println("Done. Hub ω_final = $(round(u[6N+Nr+Nr], digits=4)) rad/s")
println("Building dashboard ($n_frames frames)...")

fig = build_dashboard(sys, p, frames; times=times,
                      u_settled=u_settled, wind_fn=wind_fn)
display(fig)
println("Dashboard open. Use the frame slider or ▶ Play to animate. Ctrl+C to quit.")
wait(fig.scene)
