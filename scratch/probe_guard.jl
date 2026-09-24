using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    for (tag, kw) in (("polish ON", (;)), ("polish OFF", (; operational_polish=false)))
        u = settle_to_operational_state(
            sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000, kw...
        )
        ω = u[6N + Nr + 1]
        τ = sys.k_mppt_ref[]*ω^2
        d = KTD._trpt_equilibrium_demand(sys, p, u, τ, ω, wf)
        tr = KTD.twist_collapse_check(u, sys)
        @printf(
            "%-11s: equilibrium demand=%.4f (target %.4f)  twist_crossed=%s ratio=%.4f seg %d\n",
            tag,
            d,
            1/KTD.TRPT_REALISABILITY_TENSION_MARGIN,
            tr.crossed,
            tr.max_ratio,
            tr.worst_seg
        )
        # measured segment tensions vs the design preload
        T_meas = [
            sum(KTD.get_segment_tension(u, sys, p, s, j) for j in 1:p.n_lines)/p.n_lines for
            s in 1:(Nr - 1)
        ]
        @printf(
            "             T_meas/line[1..4] = %s\n", string(round.(T_meas[1:4], digits=1))
        )
    end
end
main()
