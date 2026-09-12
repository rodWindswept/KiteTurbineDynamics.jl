# scratch/r7_teviede_validation.jl — run Tveide's TetherDragODESolver at KTD's
# 5 kW shaft geometry and derive the equivalent KTD curvature factor.
#
# Equivalence (derived): Tveide's `drag_coefficient_multiplier` is a drag-FORCE
# ratio against the whole tether at kite speed; KTD's factor multiplies a
# local-speed POWER sum.  For a straight taper,
#     factor_KTD = multiplier * 4*r1^3 / (r0^3 + r0^2*r1 + r0*r1^2 + r1^3)
# which gives exactly 1.0 for a straight tether by construction.
using TetherDragODESolver, Printf

const R0 = 0.5751    # seed ground ring radius (m)
const R1 = 2.4       # seed hub ring radius (m)
const L  = 18.8      # shaft length (m)
const OM = 13.2      # running shaft rate (rad/s)
const D  = 0.002     # tether diameter (m)
const S  = R0^3 + R0^2 * R1 + R0 * R1^2 + R1^3
const K  = 4 * R1^3 / S

@printf("KTD shaft: r0=%.3f r1=%.3f L=%.1f omega=%.2f d=%.4f\n", R0, R1, L, OM, D)
@printf("equivalence factor K = 4*r1^3/S = %.4f  (S=%.3f)\n", K, S)
println("  T_line(N)  twist(deg)  multiplier  eff_ratio  factor_KTD")
for T in (150.0, 305.0, 700.0, 2500.0)
    for twistdeg in (0.0, 90.0, 294.0)
        ode = solve_tether(OM, T, R0, R1, L, deg2rad(twistdeg), D)
        m = solved_drag_coefficient_multiplier(ode)
        e = solved_efficiency_ratio(ode)
        @printf("  %8.0f  %9.1f  %10.4f  %9.4f  %10.4f\n", T, twistdeg, m, e, m * K)
    end
end
