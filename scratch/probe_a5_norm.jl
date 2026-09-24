using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))
const SEED_LR15_FROZEN = [2.4, 0.5751086853804245, 1.5, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]
function main()
    rb = gate_design(SEED_LR15_FROZEN; L=18.8, KW=5.0)
    @printf(
        "FROZEN normal: ok=%s broken=%s P_gen=%.2f w=%.2f clr=%.2f crossed=%s ratio=%.3f\n",
        rb.ok,
        rb.line_broken,
        rb.P_gen_final,
        rb.w_gnd_final,
        rb.clearance,
        rb.crossed,
        rb.max_twist_ratio
    )
end
main()
