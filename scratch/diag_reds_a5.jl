# scratch/diag_reds_a5.jl — diagnosis for test_gate_v13 A5 (rope-break latch).
#
# Usage: julia --project=. scratch/diag_reds_a5.jl [d0 ...]
# Runs the gate on the thin-tether trigger(s) the test uses / candidates,
# printing line_broken / ok / power / clearance and the settled strain.
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const L18 = 18.8

function report(tag, rb)
    @printf(
        "  %-16s ok=%-5s line_broken=%-5s P_gen_final=%7.3f kW  w_gnd=%6.3f  clearance=%5.2f m  crossed=%s max_ratio=%.3f\n",
        tag, string(rb.ok), string(rb.line_broken), rb.P_gen_final, rb.w_gnd_final,
        rb.clearance, string(rb.crossed), rb.max_twist_ratio)
    println("      trace P_gen: ", join(round.([row.P_gen for row in rb.trace], digits=2), ", "))
    println("      trace w_gnd: ", join(round.([row.w_gnd for row in rb.trace], digits=2), ", "))
    flush(stdout)
    return rb
end

for d0 in parse.(Float64, ARGS)
    p_c = override_params(params_daisy(); tether_diameter=d0)
    scaled_d = d0 * sqrt(5.0 / 1.5)
    EA1 = params_daisy().e_modulus * π * (scaled_d / 2)^2
    @printf("=== d0=%.5f -> scaled d=%.6f  EA_single=%.1f N  preload strain(283N)=%.4f (break at %.4f) ===\n",
        d0, scaled_d, EA1, 283.0 / EA1, KiteTurbineDynamics.ROPE_BREAK_STRAIN)
    flush(stdout)
    report("thin $d0", gate_design(seed_genome(KW); L=L18, KW=KW, p2=p_c))
    flush(stdout)
end
println("\nDONE")
