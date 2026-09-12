# scratch/preload_segment_dump.jl
#
# READ-ONLY. Dumps the per-segment internals of _matched_place_twist and
# recomputes each Δα by hand from the same closed form, to reconcile the
# cumulative twist the function returns with the bound its own asin clamp
# implies (8 segments x 90 deg = 720 deg maximum).
#
# Run from the repo root:
#   JULIA_DEPOT_PATH="$PWD/.julia_depot:/home/rodbot/.julia" \
#     /snap/julia/165/bin/julia --project=. --startup-file=no scratch/preload_segment_dump.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    F = design_axial_preload(sys, p, lift)
    sd = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    tau = sys.k_mppt_ref[] * 12.983466^2
    EA = p.e_modulus * pi * (p.tether_diameter / 2)^2

    @printf("n_lines=%d  e_modulus=%.6g  tether_diameter=%.6g  n_expansion=%d\n",
        p.n_lines, p.e_modulus, p.tether_diameter, length(sys.expansion_rotors))
    @printf("EA_single=%.6g  tau_eq=%.6f  F length=%d  F[1]=%.4f  F[end]=%.4f\n",
        EA, tau, length(F), F[1], F[end])
    @printf("elevation_angle=%.6f rad (%.3f deg)\n", p.elevation_angle, rad2deg(p.elevation_angle))

    alpha, ctrs = KiteTurbineDynamics._matched_place_twist(sys, p, F, tau, 0.0, wf, sd)
    @printf("\nRETURNED alpha = %s\n", string(round.(alpha, digits = 6)))
    @printf("RETURNED sum(alpha)=%.6f rad = %.4f deg ; max|alpha|=%.6f\n",
        sum(alpha), rad2deg(sum(alpha)), maximum(abs.(alpha)))

    # Independent recomputation from the same closed form.
    println("\nHand recomputation, segment by segment:")
    @printf("  %2s %8s %8s %10s %10s %10s %10s %12s\n",
        "s", "r_a", "r_b", "chord0", "T_s", "chord", "sin_dA", "dAlpha")
    n_seg = Nr - 1
    running = 0.0
    for s in 1:n_seg
        gid_a = sys.ring_ids[s]
        gid_b = sys.ring_ids[s + 1]
        ra = isempty(sys.expansion_rotors) ? (sys.nodes[gid_a]::RingNode).radius :
             sys.effective_radii[s]
        rb = isempty(sys.expansion_rotors) ? (sys.nodes[gid_b]::RingNode).radius :
             sys.effective_radii[s + 1]
        chord0 = ROPE_SUBSEGS * sys.sub_segs[(s - 1) * p.n_lines * ROPE_SUBSEGS + 1].length_0
        Ts = F[s] / p.n_lines
        chord = chord0 * (1 + Ts / EA)
        sinDa = tau * chord / (p.n_lines * Ts * ra * rb)
        da = asin(clamp(sinDa, -1.0, 1.0))
        running += da
        @printf("  %2d %8.4f %8.4f %10.6f %10.4f %10.6f %10.6f %12.6f\n",
            s, ra, rb, chord0, Ts, chord, sinDa, da)
    end
    @printf("  hand sum = %.6f rad = %.4f deg\n", running, rad2deg(running))
    @printf("  returned  = %.6f rad = %.4f deg\n", sum(alpha), rad2deg(sum(alpha)))
    @printf("  ratio returned/hand = %.6f   (2*pi = %.6f)\n", sum(alpha) / running, 2pi)
end

main()
