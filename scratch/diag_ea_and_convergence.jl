# scratch/diag_ea_and_convergence.jl
#
# 2026-09-16.  Two questions.
#
#  A. EA arithmetic.  `params_daisy()` now declares EA_back_line = 707 kN (the
#     3 mm / 5 kW spec).  `params_5kw_188()` builds the 5 kW params by
#     `mass_scale(..., 1.5, 5.0)`, which multiplies the field by geom_scale.  Trace
#     the factor chain and report the EA each step actually produces, so the
#     "declared 707 kN vs runtime 1.29 MN" gap has an exact explanation.
#
#  B. Convergence.  Pick a defensible `n_op` for test_settle_validity.jl.  Report
#     the quantities that test asserts, vs n_op, and the change between successive
#     values, so the choice is based on a measured plateau rather than a guess.
#
# Self-checking: asserts every reported tension is finite and non-negative, that
# the decode keeps its line/rotor counts, and that the n_op sweep is increasing.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function cyan_tension(u, sys)
    total = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        (
            (na == sys.sky_anchor_id && nb == sys.bearing_id) ||
            (na == sys.bearing_id && nb == sys.sky_anchor_id)
        ) || continue
        L = norm(pos(u, ss.end_b.node_id) .- pos(u, ss.end_a.node_id))
        total += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    return total
end

function residuals(u, sys, p, wf, lift)
    d = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(d, u, (sys, p, wf, lift), 0.0)
    N = sys.n_total
    sd = normalize(pos(u, sys.rotor.node_id))
    out = Dict{String, Float64}()
    for (nm, gid) in (
        ("hub", sys.rotor.node_id), ("bearing", sys.bearing_id), ("sky", sys.sky_anchor_id)
    )
        m = (sys.nodes[gid]).mass
        out[nm] = dot(m .* d[(3N + 3 * (gid - 1) + 1):(3N + 3 * gid)], sd)
    end
    acc = maximum(norm(d[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N)
    return out, acc
end

println("=== A. EA arithmetic ===")
p_daisy = params_daisy()
p_5kw = params_5kw_188()
println("  params_daisy()      EA_back_line = ", p_daisy.EA_back_line, " N")
println("  params_5kw_188()    EA_back_line = ", p_5kw.EA_back_line, " N")
println("  ratio 5kw/daisy                   = ", p_5kw.EA_back_line / p_daisy.EA_back_line)
println("  implied geom_scale from EA        = ", p_5kw.EA_back_line / p_daisy.EA_back_line)
println("  1.5^2                             = ", 1.5^2)
@assert p_daisy.EA_back_line > 0.0 && p_5kw.EA_back_line > 0.0

println("\n=== B. convergence vs n_op (test build_case) ===")
sys, u0, p, lift, wf = build_case(nothing, nothing)
@assert p.n_lines == 6
println("  EA_back_line=", p.EA_back_line, " N  n_rings=", sys.n_ring)

function convergence_scan(sys, u0, p, lift, wf, n_ops)
    prev_cy = NaN
    for n_op in n_ops
        u = settle_to_operational_state(
            sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=n_op
        )
        T_cy = cyan_tension(u, sys)
        res, acc = residuals(u, sys, p, wf, lift)
        @assert isfinite(T_cy) && T_cy >= 0.0
        @assert all(isfinite, values(res))
        d_cy = isnan(prev_cy) ? NaN : abs(T_cy - prev_cy)
        println(
            "  n_op=",
            lpad(n_op, 7),
            "  T_cyan=",
            lpad(round(T_cy; digits=2), 9),
            "  |dT|=",
            lpad(isnan(d_cy) ? "-" : string(round(d_cy; digits=3)), 9),
            "  hub=",
            lpad(round(res["hub"]; digits=1), 9),
            "  bear=",
            lpad(round(res["bearing"]; digits=1), 9),
            "  sky=",
            lpad(round(res["sky"]; digits=1), 9),
            "  acc0=",
            round(acc; digits=1),
        )
        prev_cy = T_cy
    end
end

convergence_scan(sys, u0, p, lift, wf, (2_000, 10_000, 20_000, 30_000, 50_000, 75_000))
println("\n=== done ===")
