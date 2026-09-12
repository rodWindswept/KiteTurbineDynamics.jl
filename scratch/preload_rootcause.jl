# scratch/preload_rootcause.jl
#
# READ-ONLY diagnostic. Answers one question: why is the preload knob
# structurally dead (df/dT == 0.000000) in scratch/preload_sweep_diag.jl while
# the same knob is live (df/dT ~ +1.07) in scratch/preload_kernel_probe.jl?
#
# Touches no src/ code and writes nothing. Prints, in order:
#   1. the state-vector layout (which slice holds alpha, which holds omega);
#   2. which end of ring_ids is the anchored ground ring (omega ~ 0);
#   3. the two competing tau_eq values each harness feeds to _matched_place_twist;
#   4. the actual sensitivity of the placed geometry to a +1 N preload, as a
#      function of tau_eq -- this is the decisive number.
#
# Run from the repo root:
#   JULIA_DEPOT_PATH="$PWD/.julia_depot:/home/rodbot/.julia" \
#     /snap/julia/165/bin/julia --project=. --startup-file=no scratch/preload_rootcause.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    base = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    N, Nr = sys.n_total, sys.n_ring

    println("="^78)
    @printf("N (nodes) = %d   Nr (rings) = %d   length(u) = %d\n", N, Nr, length(base))
    @printf("alpha slice assumed [%d:%d]   omega slice assumed [%d:%d]\n",
        6N + 1, 6N + Nr, 6N + Nr + 1, 6N + 2Nr)
    println("="^78)
    println("Per-ring state (ring index -> radius, alpha, omega):")
    for (i, gid) in enumerate(sys.ring_ids)
        node = sys.nodes[gid]::RingNode
        @printf("  ring %2d  gid=%3d  r=%8.4f  alpha=%+10.6f  omega=%+12.6f\n",
            i, gid, node.radius, base[6N + i], base[6N + Nr + i])
    end

    k = sys.k_mppt_ref[]
    println()
    @printf("k_mppt_ref = %.9f\n", k)
    println()
    println("The two harnesses read DIFFERENT omega entries:")
    for (label, idx) in (("kernel probe  base[6N+Nr+1] (omega[1]  )", 6N + Nr + 1),
                         ("sweep diag    u[6N+2*n_ring](omega[end])", 6N + 2Nr))
        w = base[idx]
        @printf("  %-40s omega=%+14.6f   k*w^2=%16.6f   k*max(w,0)^2=%16.6f\n",
            label, w, k * w^2, k * max(w, 0.0)^2)
    end

    F = design_axial_preload(sys, p, lift)
    sd = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    println()
    @printf("design_axial_preload: n=%d  F_ax[1]=%.3f N  F_ax[end]=%.3f N  top_total=%.3f\n",
        length(F), F[1], F[end], F[end])

    # ── decisive test ────────────────────────────────────────────────────────
    # Sensitivity of the placed geometry to +1 N of preload, for each candidate
    # tau_eq.  If the placed alpha/axial positions do not move, the hub axial
    # residual cannot respond either, and any solver on that knob is ill-posed.
    println()
    println("Sensitivity of _matched_place_twist to a +1 N preload:")
    @printf("  %14s | %12s | %11s | %11s | %11s\n",
        "tau_eq", "total_dalpha", "deg", "d(alpha)/dF", "d(axial)/dF")
    w_ref = base[6N + Nr + 1]
    for (label, tau) in (("zero", 0.0),
                         ("sweep: k*max(omega[end],0)^2", k * max(base[6N + 2Nr], 0.0)^2),
                         ("kernel: k*omega[1]^2", k * base[6N + Nr + 1]^2))
        a1, c1 = KiteTurbineDynamics._matched_place_twist(sys, p, F, tau, w_ref, wf, sd)
        a2, c2 = KiteTurbineDynamics._matched_place_twist(sys, p, copy(F) .+ 1.0, tau, w_ref, wf, sd)
        dalpha = maximum(abs.(a2 .- a1))
        dz = maximum(abs(c2[i][3] - c1[i][3]) for i in 1:Nr)
        @printf("  %14s | %12.6f | %11.4f | %11.3e | %11.3e   <- %s\n",
            label, sum(a1), rad2deg(sum(a1)), dalpha, dz,
            dalpha == 0.0 && dz == 0.0 ? "DEAD KNOB" : "live")
    end
    println()
end

main()
