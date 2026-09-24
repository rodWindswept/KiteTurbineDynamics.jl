using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
function main()
    sys, u0, pc, lift, wf = build_case(nothing, nothing)
    u = settle_to_operational_state(
        sys,
        copy(u0),
        pc,
        60.0;
        lift_device=lift,
        wind_fn=wf,
        n_op=2_000,
        operational_polish=false,
    )
    N, Nr = sys.n_total, sys.n_ring
    ω = u[6N + Nr + 1]
    F_ax = design_axial_preload(sys, pc, lift, u0; omega_eq=ω, wind_fn=wf)
    intended = F_ax ./ pc.n_lines
    ef = KTD.capture_extended(u, sys, pc, 0.0, wf, lift)
    err = maximum(abs.(ef.segment_tension .- intended) ./ intended)
    @printf("omega=%.4f  max rel err=%.6f  (test threshold 1e-3)\n", ω, err)
    @printf("  intended[1..3]=%s\n", string(round.(intended[1:3], digits=2)))
    @printf("  measured[1..3]=%s\n", string(round.(ef.segment_tension[1:3], digits=2)))
    @printf("  twist[1]=%.2f deg (>30 required)\n", ef.segment_twist_deg[1])
end
main()
