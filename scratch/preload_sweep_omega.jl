# scratch/preload_sweep_omega.jl
#
# READ-ONLY. Tests the hypothesis for the dead preload knob in
# scratch/preload_sweep_diag.jl: that harness settles with
# `settle_to_equilibrium`, which leaves omega ~ 0, so its tau_eq is zero and
# `_matched_place_twist` silently degenerates to the untwisted placement.
#
# Run from the repo root:
#   JULIA_DEPOT_PATH="$PWD/.julia_depot:/home/rodbot/.julia" \
#     /snap/julia/165/bin/julia --project=. --startup-file=no scratch/preload_sweep_omega.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

function omegas(sys, u)
    N, Nr = sys.n_total, sys.n_ring
    return u[(6N + Nr + 1):(6N + 2Nr)]
end

function main()
    sys, u0, pc, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring

    # Path A: what preload_sweep_diag.jl actually does.
    _, u0_build = KiteTurbineDynamics.build_kite_turbine_system(pc)
    u_sweep = KiteTurbineDynamics.settle_to_equilibrium(sys, u0_build, pc;
        lift_device=lift, wind_fn=wf)
    wA = omegas(sys, u_sweep)

    # Path B: what preload_kernel_probe.jl does.
    u_kern = settle_to_operational_state(sys, u0, pc, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    wB = omegas(sys, u_kern)

    k = sys.k_mppt_ref[]
    @printf("k_mppt_ref = %.6f\n\n", k)
    @printf("Path A  settle_to_equilibrium      (sweep diag)  omega = %s\n",
        string(round.(wA, digits = 6)))
    @printf("        u[6N + 2*n_ring] = %+.6f   k*max(w,0)^2 = %.6f   <- tau_eq used by the sweep\n",
        u_sweep[6N + 2Nr], k * max(u_sweep[6N + 2Nr], 0.0)^2)
    @printf("        k*w^2 (no clamp)           = %.6f\n\n", k * u_sweep[6N + 2Nr]^2)

    @printf("Path B  settle_to_operational_state (kernel probe) omega = %s\n",
        string(round.(wB, digits = 6)))
    @printf("        u[6N + 2*n_ring] = %+.6f   k*max(w,0)^2 = %.6f   <- tau_eq used by the probe\n",
        u_kern[6N + 2Nr], k * max(u_kern[6N + 2Nr], 0.0)^2)
    @printf("        k*w^2 (no clamp)           = %.6f\n", k * u_kern[6N + 2Nr]^2)
end

main()
