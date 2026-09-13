# scratch/static_solve.jl
#
# !! WORK IN PROGRESS -- DOES NOT YET SOLVE.  Status 2026-09-12.
#
# The formulation below is believed correct (Newton/LM on the ODE's own force and
# torque residuals with the aerodynamics frozen), but the solve fails to make
# progress: LM reports "could not reduce ||F||" at the first iteration even with a
# huge regulariser, which should be impossible with a correct Jacobian.
#
# KNOWN BUGS FOUND AND FIXED WHILE GETTING HERE (all in this file, not in src/):
#   - `du` was allocated as 2N+2Nr = 328 when the ODE writes up to 6N+2Nr = 948
#   - a variable named `perturb!` was both an array and a closure, so
#     `perturb!(up, j, eps)` parsed as array indexing instead of a call, making
#     every Jacobian column identical
#   - a captured, reused `du` buffer made successive residual evaluations return
#     the same object (now allocated per call)
# There is still at least one bug: the Jacobian comes back all-zero in this file
# even though scratch/resid_sanity.jl proves the ODE responds correctly to node
# perturbations (eps=1e-3 gives a clean linear hub response of 58.79 per metre).
# The remaining suspect is the DOF/perturbation bookkeeping in this file.
#
# DO NOT build on the numbers below until this runs.  The correct analytic result
# for the bow (4.7 deg / ~1.5 m) came from arithmetic, not from this solver.
#
# Direct static equilibrium solve for the settle (Rod-approved rebuild).
#
# WHY NOT RELAXATION: the assembly has a soft, lightly damped lateral (shaft-
# bowing) mode with a ~10 s period.  Dynamic relaxation has to time-march that
# mode, which needs millions of steps, and the adaptive damping scheme pins its
# gain at the floor and creeps.  A Newton solve on the force residual is
# insensitive to how soft or slow the mode is: it is a root-find on F(x) = 0.
#
# FORMULATION
#   unknowns : positions of every node except the ground anchor, plus the ring
#              twist angles.  Velocities are held at zero (statics).
#   residual : the ODE's own acceleration and angular-acceleration equations,
#              evaluated with the aerodynamics FROZEN (omega at the operating
#              point, kite at its equilibrium offset).  Frozen aero is what makes
#              this a STRUCTURAL solve rather than a time march.
#
#   J dx = -F(x)   solved by dense LU, with a backtracking line search because
#   the tension-only lines make F piecewise-smooth (slack <-> taut).
#
# The transmission lines are TWISTED helices, so rope-node positions are NOT
# re-interpolated along straight chords anywhere in here -- the ODE evaluates the
# true sub-segment geometry from the node positions.
#
#   scripts/ktd-julia scratch/static_solve.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

const ANCHOR = 1     # ground ring, pinned at the origin

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

"""
Evaluate the static residual.

Returns (F, dof_map) where F is the residual on the free DOFs:
  - acceleration of every node except the anchor (3 per node)
  - angular acceleration of every ring (1 per ring, the twist equation)
Velocities are read from `u` but held at zero by `pack!`/`unpack!`.
"""
function make_residual(sys, p, wf, lift, N, Nr)
    # DOF layout: 3 per free node, then Nr twist accelerations
    free_nodes = [g for g in 1:N if g != ANCHOR]
    npos = 3 * length(free_nodes)
    ndof = npos + Nr
    node_offset = Dict{Int,Int}()
    for (i, g) in enumerate(free_nodes)
        node_offset[g] = 3 * (i - 1)
    end
    ssz = 6 * N + 2 * Nr

    function residual!(u::Vector{Float64})
        # NOTE: allocate per call.  Reusing a captured buffer returned identical
        # residuals for perturbed states (see scratch/lm_debug.jl), corrupting the
        # finite-difference Jacobian.  Correctness over allocation here.
        du = zeros(ssz)
        KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
        F = zeros(ndof)
        for g in free_nodes
            o = node_offset[g]
            b = 3N + 3 * (g - 1) + 1
            F[o + 1] = du[b]
            F[o + 2] = du[b + 1]
            F[o + 3] = du[b + 2]
        end
        # twist equation (angular acceleration) for every ring
        for ri in 1:Nr
            F[npos + ri] = du[6N + Nr + ri]
        end
        return F
    end

    function apply!(u::Vector{Float64}, dx::Vector{Float64}, scale::Float64)
        for g in free_nodes
            o = node_offset[g]
            b = 3 * (g - 1) + 1
            u[b] += scale * dx[o + 1]
            u[b + 1] += scale * dx[o + 2]
            u[b + 2] += scale * dx[o + 3]
            # velocities stay zero (statics)
            u[3N + 3 * (g - 1) + 1] = 0.0
            u[3N + 3 * (g - 1) + 2] = 0.0
            u[3N + 3 * (g - 1) + 3] = 0.0
        end
        for ri in 1:Nr
            u[6N + ri] += scale * dx[npos + ri]
        end
        # anchor pinned
        u[1] = 0.0; u[2] = 0.0; u[3] = 0.0
        u[3N + 1] = 0.0; u[3N + 2] = 0.0; u[3N + 3] = 0.0
        return u
    end

    return residual!, apply!, ndof, free_nodes, npos
end

"Finite-difference Jacobian of the static residual.  `perturb!` sets DOF j."
function fd_jacobian(residual!, u, F0, ndof, perturb_dof!; eps=1e-3)
    J = zeros(ndof, ndof)
    up = copy(u)
    for j in 1:ndof
        copyto!(up, u)
        perturb_dof!(up, j, eps)
        Fj = residual!(up)
        @views J[:, j] .= (Fj .- F0) ./ eps
    end
    return J
end

function main()
    omega_eq = 12.983466
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub = sys.rotor.node_id
    sky = sys.sky_anchor_id

    u = KiteTurbineDynamics.settle_to_equilibrium(sys, u0, p; lift_device=lift, wind_fn=wf)
    for k in 1:Nr
        u[6N + Nr + k] = omega_eq
    end
    sys.kite_pos .= pos(u, sky) .+
                    lift.line_length .* [cos(p.lifter_elevation), 0.0, sin(p.lifter_elevation)]
    @views u[(3N + 1):6N] .= 0.0

    residual!, apply!, ndof, free_nodes, npos = make_residual(sys, p, wf, lift, N, Nr)

    # wire the perturbation used by the FD Jacobian
    node_of_dof = zeros(Int, ndof)
    comp_of_dof = zeros(Int, ndof)
    for (i, g) in enumerate(free_nodes), k in 1:3
        node_of_dof[3 * (i - 1) + k] = g
        comp_of_dof[3 * (i - 1) + k] = k
    end
    perturb_dof! = (uu, j, eps) -> begin
        if j <= npos
            g = node_of_dof[j]
            k = comp_of_dof[j]
            uu[3 * (g - 1) + k] += eps
        else
            uu[6N + (j - npos)] += eps
        end
    end

    @printf("static solve: %d DOF (%d nodes free + %d ring twists)\n\n", ndof,
        length(free_nodes), Nr)
    @printf("  %5s %14s %14s %14s %14s\n",
        "iter", "|F|_2", "|F|_inf", "hub_axial", "hub_perp")

    F = residual!(u)
    axis0 = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]

    for it in 0:25
        nrm = norm(F)
        nrmi = maximum(abs.(F))
        # hub perpendicular offset from the DESIGN axis
        d = pos(u, hub)
        dperp = norm(d .- dot(d, axis0) .* axis0)
        @printf("  %5d %14.6e %14.6f %14.6f %14.6f\n",
            it, nrm, nrmi, dot(d, axis0), dperp)
        if nrmi < 1e-3 || it == 25
            break
        end

        # ── Levenberg-Marquardt: solve (J'J + lambda*diag(J'J)) dx = -J'F ─────
        # Plain Newton fails here: the transmission is ~1e6 N/m stiff against a
        # ~80 N/m lateral mode, so J is ill-conditioned, and the tension-only
        # lines make F piecewise (slack <-> taut), which defeats a bare line
        # search.  LM regularises both problems.
        J = fd_jacobian(residual!, u, F, ndof, perturb_dof!; eps=1e-3)
        JtJ = J' * J
        JtF = J' * F
        diagJtJ = max.(diag(JtJ), 1e-12)
        lam = 1e-3 * maximum(diagJtJ)
        accepted = false
        local step_used = 0.0
        for _ in 1:24
            A = JtJ + lam * Diagonal(diagJtJ)
            local dx
            try
                dx = A \ (-JtF)
            catch
                lam *= 10
                continue
            end
            for s in (1.0, 0.5, 0.25, 0.1)
                ut = copy(u)
                apply!(ut, dx, s)
                Ft = residual!(ut)
                if norm(Ft) < nrm
                    u, F = ut, Ft
                    lam = max(lam * 0.3, 1e-12)
                    accepted = true
                    step_used = s
                    break
                end
            end
            accepted && break
            lam *= 10
        end
        if !accepted
            @printf("        LM could not reduce ||F|| (lambda=%.3e) -- stopping\n", lam)
            break
        end
        @printf("        LM accepted (lam=%.2e step=%.2f) -> |F|_2=%.6e\n", lam, step_used, norm(F))
    end

    println()
    @printf("final hub |r|=%.4f  bearing |r|=%.4f  sky |r|=%.4f\n",
        norm(pos(u, hub)), norm(pos(u, sys.bearing_id)), norm(pos(u, sky)))
end

main()
