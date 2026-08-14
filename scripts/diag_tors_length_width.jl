#!/usr/bin/env julia --project=.
#= diag_tors_length_width.jl — isolate the two geometric effects on the
torsional FoS: shaft length (L_seg) and shaft width (r_min), holding ring
count and thrust constant. Direct test of: "wider + shorter = higher FoS
for the same number of rings". =#

using KiteTurbineDynamics, Printf

# τ_cap = T_total × r_min² / √(L_seg² + 2·r_min²)   (per trpt_optimization.jl:396)
# tfos  = τ_cap / tau_above
function tors_fos(T_total, r_min, L_seg, tau_above)
    τ_cap = T_total * r_min^2 / sqrt(L_seg^2 + 2 * r_min^2)
    return τ_cap / max(tau_above, 1e-9)
end

const T = 2000.0      # axial thrust, N (held constant)
const tau = 100.0     # applied torque, Nm (held constant)

println("A) Fixed width, varying shaft length (fixed ring count)")
println("   length(m)  L_seg(8 seg)   tors FoS")
for L in [15.0, 21.2, 25.1, 30.0, 40.0, 60.0]
    L_seg = L / 8
    @printf("   %6.1f      %7.3f      %6.3f\n", L, L_seg, tors_fos(T, 1.0, L_seg, tau))
end

println("\nB) Fixed length, varying ring width")
println("   r_min(m)   tors FoS")
for r in [0.6, 0.9, 1.2, 1.5, 2.0]
    @printf("   %6.2f     %6.3f\n", r, tors_fos(T, r, 30.0/8, tau))
end

println("\nC) Same ring count, same width: short vs long")
@printf("   short (15m): %.3f   long (30m): %.3f\n",
    tors_fos(T, 1.0, 15.0/8, tau), tors_fos(T, 1.0, 30.0/8, tau))
println("   → shorter shaft gives HIGHER torsional FoS (as Rod said)")
