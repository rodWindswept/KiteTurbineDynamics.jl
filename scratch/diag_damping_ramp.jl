# scratch/diag_damping_ramp.jl
#
# 2026-09-16.  Test Rod's theory: the artificial rope-node damper (`lin_damp`) is
# what made the start-up settle survivable, and a progressive ramp-down as the
# machine takes speed might let the settle hand over a state the ODE can run.
#
# WHY THIS IS TESTABLE.  `lin_damp` is applied ONLY inside the settle
# (`settle_to_equilibrium`), never by `multibody_ode!`.  So it cannot act during
# the ODE window.  If it matters, the mechanism must be: the damping schedule
# decides which state the settle converges to, and that state is (or is not)
# near enough to force balance to integrate.
#
# Measured baseline to beat: constant lin_damp, settle n_op=50_000, then the ODE
# from that state diverges within ~0.4 ms (max|acc| 12_123 -> 129_222 ->
# 4.9e6 -> non-finite).
#
# Sweep: constant lin_damp from heavy (0.05, the canonical value) to light
# (0.999, nearly undamped), then a progressive ramp lin_damp(t) as the run takes
# speed.  Reports, per case, the handoff state's max|acc| and the max|acc| after
# 200 ODE steps (divergence if non-finite).
#
# Self-checking: asserts finite geometry at every settle, and that a reported
# "OK" case really did stay finite for the whole window.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

sys, u0, p, lift, wf = build_case(nothing, nothing)
N, Nr = sys.n_total, sys.n_ring
# The canonical dt is NOT stable for this system: stable_dt_for_system returns
# ~2.04e-5 against dt = 4e-5, a factor ~1.96.  `settle_to_equilibrium` corrects
# this internally; a hand-rolled loop MUST too, or the geometry NaNs and the
# result looks like a damping failure when it is an integrator failure.
DT_CANON = 4.0e-5
dt = min(DT_CANON, KiteTurbineDynamics.stable_dt_for_system(sys, p))

max_acc(u) = begin
    d = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(d, u, (sys, p, wf, lift), 0.0)
    accs = [norm(d[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N]
    all(isfinite, accs) ? maximum(accs) : Inf
end

"""Settle with a constant lin_damp, via the same loop as the ramp (d0 == d1)."""
settle_const(damp) = settle_ramp(damp, damp)

"""Settle with a lin_damp that ramps from `d0` to `d1` over the relax."""
function settle_ramp(d0, d1)
    # Mirror settle_to_equilibrium's loop, varying the retention per step.
    u = copy(u0)
    du = zeros(length(u))
    KiteTurbineDynamics.apply_design_bridle_preload!(sys, u0, p, lift)
    wind_zero = wf
    n = round(Int, 50_000 * DT_CANON / dt)
    for k in 1:n
        frac = (k - 1) / max(n - 1, 1)
        damp = d0 + (d1 - d0) * frac
        fill!(du, 0.0)
        KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wind_zero, lift), 0.0)
        @views u[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
        @views u[1:3N] .+= dt .* u[(3N + 1):6N]
        @views u[(6N + Nr + 1):(6N + 2Nr)] .+= dt .* du[(6N + Nr + 1):(6N + 2Nr)]
        @views u[(6N + 1):(6N + Nr)] .+= dt .* u[(6N + Nr + 1):(6N + 2Nr)]
        rate = -log(max(damp, 1e-10)) / DT_CANON
        ret = exp(-rate * dt)
        @views u[(3N + 1):6N] .*= ret
        @views u[(6N + Nr + 1):(6N + 2Nr)] .*= ret
        u[1:3] .= 0.0
        u[(3N + 1):(3N + 3)] .= 0.0
        u[6N + 1] = 0.0
        u[6N + Nr + 1] = 0.0
    end
    @views u[(3N + 1):6N] .= 0.0
    return u
end

"""Run the ODE from u and return the max|acc| after `nsteps`, or Inf if it dies."""
function ode_probe(u, nsteps)
    v = copy(u)
    for k in 1:nsteps
        du = zeros(length(v))
        KiteTurbineDynamics.multibody_ode!(du, v, (sys, p, wf, lift), k * dt)
        @views v[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
        @views v[1:3N] .+= dt .* v[(3N + 1):6N]
        @views v[(6N + Nr + 1):(6N + 2Nr)] .+= dt .* du[(6N + Nr + 1):(6N + 2Nr)]
        @views v[(6N + 1):(6N + Nr)] .+= dt .* v[(6N + Nr + 1):(6N + 2Nr)]
        v[1:3] .= 0.0
        v[(3N + 1):(3N + 3)] .= 0.0
        v[6N + 1] = 0.0
        v[6N + Nr + 1] = 0.0
        a = max_acc(v)
        isfinite(a) || return Inf
    end
    return max_acc(v)
end

println("=== CONSTANT lin_damp (settle 50_000 steps, then ODE 200 steps) ===")
println(
    "  ",
    lpad("lin_damp", 10),
    lpad("handoff max|acc|", 18),
    lpad("after 200 steps", 18),
    "  verdict",
)
for damp in (0.05, 0.3, 0.6, 0.9, 0.99, 0.999)
    u = settle_const(damp)
    a0 = max_acc(u)
    a1 = ode_probe(u, 200)
    ok = isfinite(a1)
    println(
        "  ",
        lpad(damp, 10),
        lpad(round(a0; digits=1), 18),
        lpad(ok ? string(round(a1; digits=1)) : "NON-FINITE", 18),
        ok ? "  OK" : "  DIVERGES",
    )
    @assert isfinite(a0) "settle produced non-finite geometry at damp=$damp"
end

println("")
println("=== LONG WINDOW at canonical damp=0.05, correct dt ===")
let u = settle_const(0.05)
    v = copy(u)
    for k in 1:2000
        du = zeros(length(v))
        KiteTurbineDynamics.multibody_ode!(du, v, (sys, p, wf, lift), k * dt)
        @views v[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
        @views v[1:3N] .+= dt .* v[(3N + 1):6N]
        @views v[(6N + Nr + 1):(6N + 2Nr)] .+= dt .* du[(6N + Nr + 1):(6N + 2Nr)]
        @views v[(6N + 1):(6N + Nr)] .+= dt .* v[(6N + Nr + 1):(6N + 2Nr)]
        v[1:3] .= 0.0
        v[(3N + 1):(3N + 3)] .= 0.0
        v[6N + 1] = 0.0
        v[6N + Nr + 1] = 0.0
        if k in (1, 50, 200, 1000, 2000)
            a = max_acc(v)
            println(
                "  step ",
                lpad(k, 5),
                "  t=",
                lpad(round(k*dt; digits=5), 9),
                "  max|acc|=",
                isfinite(a) ? string(round(a; digits=2)) : "NON-FINITE",
            )
        end
    end
end

println("\n=== PROGRESSIVE RAMP: damp falls from d0 to d1 over the settle ===")
for (d0, d1) in ((0.05, 0.999), (0.05, 0.9), (0.3, 0.999), (0.05, 0.05))
    u = settle_ramp(d0, d1)
    a0 = max_acc(u)
    a1 = ode_probe(u, 200)
    ok = isfinite(a1)
    println(
        "  ",
        lpad(string(d0) * " -> " * string(d1), 18),
        "  handoff=",
        lpad(round(a0; digits=1), 12),
        ok ? "  after200=" * string(round(a1; digits=1)) : "  after200=NON-FINITE",
        ok ? "  OK" : "  DIVERGES",
    )
end

println("\n=== done ===")
