using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
function main()
    sys, u0, pc, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    for n_op in (2_000, 20_000, 100_000)
        u = settle_to_operational_state(
            sys,
            copy(u0),
            pc,
            60.0;
            lift_device=lift,
            wind_fn=wf,
            n_op=n_op,
            operational_polish=false,
        )
        ω = u[6N + Nr + 1]
        ef = KTD.capture_extended(u, sys, pc, 0.0, wf, lift)
        FB = design_axial_preload(
            sys, pc, lift, u0; omega_eq=ω, wind_fn=wf, hub_pos=pos(u, sys.rotor.node_id)
        )
        indicated = FB ./ pc.n_lines
        @printf(
            "n_op=%7d: max rel err=%.6f  |hub|=%.4f\n",
            n_op,
            maximum(abs.(ef.segment_tension .- indicated) ./ indicated),
            norm(pos(u, sys.rotor.node_id))
        )
    end
end
main()
