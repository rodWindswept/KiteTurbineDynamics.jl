using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))
const SEED_LR15_FROZEN = [2.4, 0.5751086853804245, 1.5, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]
function main()
    for d in (0.00020, 0.00017, 0.00015, 0.00013, 0.00012)
        p_thin = override_params(params_daisy(); tether_diameter=d)
        rb = gate_design(SEED_LR15_FROZEN; L=18.8, KW=5.0, p2=p_thin)
        @printf(
            "d=%.5f built=%.4fmm -> ok=%s broken=%s P=%.2f kW w=%.2f ratio=%.3f\n",
            d,
            d*sqrt(5/1.5),
            rb.ok,
            rb.line_broken,
            rb.P_gen_final,
            rb.w_gnd_final,
            rb.max_twist_ratio
        )
    end
end
main()
