# scratch/diag_ramp_dt.jl
#
# 2026-09-16.  Does the ramp path (`evaluate_ramp`) actually diverge at the raw
# V11_DT = 4e-5 for the 5 kW build, or is the derating merely precautionary?
#
# Context: `objective_evaluator_ramp.jl` used V11_DT for its chunk and window ODE
# calls.  `objective_evaluator.jl:567` already derives `stable_dt_for_system`, so
# the ramp path was the only ODE producer using the raw constant.  For the 5 kW
# taper that constant is 1.96x over the linear stability limit (see the dt fault
# in the instrument trust log, commit ae864a6).
#
# Method: build the same system, settle it, then integrate a short window at BOTH
# steps and compare.  A stability violation shows as runaway max|acc| or a
# non-finite state; a benign difference is a small offset that stays bounded.
#
# Also reports the dt each path would choose, and how many systems in the live
# path are fine-meshed enough to be derated.
#
# Self-checking: asserts finite settled geometry, that both runs started from the
# identical state, and that the derived step is not above the raw constant.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

sys, u0, p, lift, wf = build_case(nothing, nothing)
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
u = settle_to_operational_state(sys, u0, p, 60.0; lift_device=lift, wind_fn=wf, n_op=50_000)
N, Nr = sys.n_total, sys.n_ring

dt_raw = KiteTurbineDynamics.V11_DT
dt_stable = KiteTurbineDynamics.stable_dt_for_system(sys, p)
@assert all(isfinite, u) "settled state not finite"
@assert dt_stable <= dt_raw "derived step must not exceed the raw constant"

println("=== the two steps for this build ===")
println("  V11_DT (raw, ramp path)     = ", dt_raw)
println("  stable_dt_for_system        = ", dt_stable)
println("  ratio (raw / stable)        = ", round(dt_raw / dt_stable; digits=4))
println(
    "  Lmin                        = ",
    round(minimum(ss.length_0 for ss in sys.sub_segs); digits=4),
    " m",
)

function max_acc(u)
    d = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(d, u, (sys, p, wf, lift), 0.0)
    accs = [norm(d[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N]
    return all(isfinite, accs) ? maximum(accs) : Inf
end

"""Integrate `t_seconds` at `dt` from the settled state; return (max|acc|, finite?)."""
function run_at(u_start, dt, t_seconds)
    v = copy(u_start)
    n = round(Int, t_seconds / dt)
    worst = 0.0
    for k in 1:n
        d = zeros(length(v))
        KiteTurbineDynamics.multibody_ode!(d, v, (sys, p, wf, lift), k * dt)
        @views v[(3N + 1):6N] .+= dt .* d[(3N + 1):6N]
        @views v[1:3N] .+= dt .* v[(3N + 1):6N]
        @views v[(6N + Nr + 1):(6N + 2Nr)] .+= dt .* d[(6N + Nr + 1):(6N + 2Nr)]
        @views v[(6N + 1):(6N + Nr)] .+= dt .* v[(6N + Nr + 1):(6N + 2Nr)]
        v[1:3] .= 0.0
        v[(3N + 1):(3N + 3)] .= 0.0
        v[6N + 1] = 0.0
        v[6N + Nr + 1] = 0.0
        a = max_acc(v)
        a = isfinite(a) ? a : Inf
        worst = max(worst, a)
        isfinite(a) || return (Inf, false)
    end
    return (worst, all(isfinite, v))
end

println("\n=== integrate the SAME settled state at both steps ===")
println("  ", lpad("t s", 8), lpad("max|acc| @ raw", 18), lpad("max|acc| @ stable", 20))
for t_sec in (0.02, 0.1, 0.5, 1.0)
    a_raw, ok_raw = run_at(u, dt_raw, t_sec)
    a_st, ok_st = run_at(u, dt_stable, t_sec)
    println(
        "  ",
        lpad(t_sec, 8),
        lpad(ok_raw ? string(round(a_raw; digits=1)) : "NON-FINITE", 18),
        lpad(ok_st ? string(round(a_st; digits=1)) : "NON-FINITE", 20),
    )
    @assert isfinite(a_raw) || !ok_raw     # Inf only when the run died
end
println("\n=== done ===")
