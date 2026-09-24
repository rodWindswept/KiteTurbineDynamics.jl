using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const L18 = 18.8
const SEED_LR15_FROZEN = [2.4, 0.5751086853804245, 1.5, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]

println("Testing A5 with e_modulus fixture:")
for E_val in [0.7e9, 0.8e9, 0.9e9, 1.0e9]
    p_mod = override_params(params_daisy(); e_modulus=E_val)
    rb = gate_design(SEED_LR15_FROZEN; L=L18, KW=KW, p2=p_mod, window_s=10.0)
    @printf(
        "E = %.2f GPa | ok=%s | line_broken=%s | P_gen=%.2f kW | w_gnd=%.2f | clearance=%.2f m\n",
        E_val/1e9,
        rb.ok,
        rb.line_broken,
        rb.P_gen_final,
        rb.w_gnd_final,
        rb.clearance
    )
    if rb.line_broken && !rb.ok && rb.P_gen_final >= 4.0
        println("  -> SUCCESS for A5!")
        break
    end
end
