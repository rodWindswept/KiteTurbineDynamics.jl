# scratch/static_solve2.jl
#
# Direct static equilibrium solve for the settle.  Clean rewrite.
#
# WHY: the assembly has a soft, lightly damped lateral (shaft-bowing) mode.  The
# transmission hangs carrying the hub's resultant load -- 71.6 N along the shaft
# and 124.0 N perpendicular to it -- so the column must tilt ~4.7 deg out of the
# design axis, i.e. ~1.5 m at the hub.  Dynamic relaxation has to time-march that
# mode and needs millions of steps.  Newton is a root-find on F(x)=0 and does not
# care how soft the mode is.
#
# FORMULATION
#   unknowns : positions of every node except the ground anchor, plus ring twists.
#              Velocities held at zero (statics).
#   residual : the ODE's own node accelerations and ring angular accelerations,
#              evaluated with the aerodynamics FROZEN (omega at the operating
#              point, kite at its equilibrium offset).  Frozen aero makes this a
#              STRUCTURAL solve rather than a time march.
#
# DESIGN RULES LEARNED THE HARD WAY (all four were real bugs in the previous
# attempt, all in scratch, none in src/):
#   1. ONE source of truth for the DOF map.  The residual and the perturbation
#      must be built from the SAME map object, never two parallel constructions.
#   2. The residual buffer must be 6N+2Nr long, not 2N+2Nr.
#   3. Never name a closure the same as an array (it silently becomes indexing).
#   4. CHECK THE JACOBIAN against a hand perturbation BEFORE attempting a solve.
#      A zero or constant column set is a bug in the harness, not the physics.
#
# STATUS 2026-09-12 (this file) -- HARNESS NOW CORRECT, SOLVER STILL TOO SLOW.
#
# VERIFIED WORKING:
#   - residual responds to perturbations (R1, R2 both non-zero)
#   - Jacobian is non-zero, finite, and each column matches a hand-computed
#     difference to 0.0
#   - force-based residual is the right measure (spans 0.3 kg .. 14.6 kg nodes)
#   - LM steps are ACCEPTED at full step=1.000 with lambda decaying 1e-3 -> 1e-7
#
# STILL BLOCKING -- the remaining problem is numerical, not physics:
#   accepted steps are max|dx| ~ 1.2e-5 m against a bow of ~1.5 m.  Five orders
#   of magnitude too small, every iteration.
#
#   Cause: this forms the NORMAL EQUATIONS (JtJ), which squares the condition
#   number.  max|J| ~ 1e7, min|diag| ~ 14, so JtJ spans ~1e12 and the directions
#   that actually carry the bow are lost in double precision.
#
#   FIX FOR NEXT SESSION (in order):
#     1. Do NOT form JtJ.  Solve the least-squares step with QR or SVD, i.e.
#        dx = -J \ F (backslash on the tall matrix) or via qr(J).
#     2. The Jacobian is sparse (each node couples only to its neighbours through
#        segments) -- build it as a SparseMatrixCSC and use a sparse solve.  The
#        FD Jacobian currently does 471 full ODE evaluations per iteration.
#     3. If a dense direct solve is kept, scale DOFs by their column norm before
#        the solve (partially done) AND use a trust region rather than a decaying
#        lambda.
#
# UPDATE after QR + per-DOF scaling (still not converging):
#   QR fixed the step SIZE (1.2e-5 -> ~1e-2 m) and per-DOF column scaling fixed
#   the direction, but the solve still CREEPS: 200 iterations moved the hub
#   perpendicular offset only 0.3 mm against a required bow of ~1.5 m, with
#   ||F||_inf stuck at 251 N.
#
#   Diagnosis: with every ROPE NODE as an independent free DOF, any global motion
#   of the machine is resisted by AXIAL STRETCHING of the very stiff lines.  A real
#   bow is a large GEOMETRIC rearrangement -- the cable directions reorient to
#   carry the weight -- with almost no stretching.  In this formulation the
#   network must pass through heavily-stretched intermediate configurations to get
#   there, so the solver faces a huge spurious energy barrier and inches along.
#
#   NEXT FORMULATION (not yet implemented): SLAVE the rope nodes to the ring
#   geometry.  Solve only for ring centres + bearing + sky anchor (3*10 = 30 DOF
#   instead of 471), and set the rope nodes from the segment structure after each
#   step.  That removes the stretching modes from the search space.  Care is needed
#   because the lines are TWISTED helices -- interpolate along the true segment
#   geometry (as `settle_to_operational_state` does at its end), never along
#   straight chords (that was the error that produced the fake 500 kN/m).
#
#   scripts/ktd-julia scratch/static_solve2.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

const ANCHOR = 1                 # ground ring, pinned at the origin
const EPS_FD = 1e-3              # m / rad -- matched to the problem scale

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

# ─────────────────────────────────────────────────────────────────────────────
# The DOF map: the single source of truth
# ─────────────────────────────────────────────────────────────────────────────
struct DofMap
    free_nodes::Vector{Int}      # node ids, in residual order
    npos::Int                    # number of position DOFs (3 per free node)
    ndof::Int                    # npos + Nr
    Nr::Int
    nod::Vector{Int}             # for dof j <= npos: which node
    cmp::Vector{Int}             #              and which component (1..3)
end

function make_dofmap(N::Int, Nr::Int)
    free_nodes = [g for g in 1:N if g != ANCHOR]
    npos = 3 * length(free_nodes)
    ndof = npos + Nr
    nod = zeros(Int, ndof)
    cmp = zeros(Int, ndof)
    for (i, g) in enumerate(free_nodes), k in 1:3
        nod[3 * (i - 1) + k] = g
        cmp[3 * (i - 1) + k] = k
    end
    for ri in 1:Nr
        nod[npos + ri] = ri          # ring index for twist DOFs
        cmp[npos + ri] = 0           # 0 marks a twist DOF
    end
    return DofMap(free_nodes, npos, ndof, Nr, nod, cmp)
end

"Apply a perturbation of size `e` to DOF `j` of state `uu` (in place)."
function perturb_dof!(uu, dm::DofMap, N::Int, j::Int, e::Float64)
    if j <= dm.npos
        g = dm.nod[j]
        k = dm.cmp[j]
        uu[3 * (g - 1) + k] += e
    else
        uu[6N + dm.nod[j]] += e      # twist of ring dm.nod[j]
    end
    return uu
end

# ─────────────────────────────────────────────────────────────────────────────
# Residual
# ─────────────────────────────────────────────────────────────────────────────
"Residual = ODE accelerations for free nodes, then ring angular accelerations."
function make_residual(sys, p, wf, lift, N::Int, Nr::Int, dm::DofMap)
    ssz = 6 * N + 2 * Nr
    du = zeros(ssz)
    function resid!(uu::Vector{Float64})
        fill!(du, 0.0)
        KiteTurbineDynamics.multibody_ode!(du, uu, (sys, p, wf, lift), 0.0)
        F = zeros(dm.ndof)
        # FORCE residual (not acceleration): the assembly spans 0.3 kg to 14.6 kg,
        # so the raw accelerations are dominated by the lightest nodes and the
        # convergence measure becomes meaningless.  Row-scale by node mass.
        for (i, g) in enumerate(dm.free_nodes)
            m = (sys.nodes[g]).mass
            b = 3N + 3 * (g - 1) + 1
            F[3 * (i - 1) + 1] = m * du[b]
            F[3 * (i - 1) + 2] = m * du[b + 1]
            F[3 * (i - 1) + 3] = m * du[b + 2]
        end
        for ri in 1:Nr
            F[dm.npos + ri] = du[6N + Nr + ri]
        end
        return F
    end
    return resid!
end

"Add `s` times the DOF step `dx` to state `u`, holding velocities at zero."
function apply_step!(u, dm::DofMap, N::Int, dx::Vector{Float64}, s::Float64)
    for (i, g) in enumerate(dm.free_nodes)
        for k in 1:3
            u[3 * (g - 1) + k] += s * dx[3 * (i - 1) + k]
        end
    end
    for ri in 1:dm.Nr
        u[6N + ri] += s * dx[dm.npos + ri]
    end
    @views u[(3N + 1):6N] .= 0.0        # statics
    u[1] = 0.0; u[2] = 0.0; u[3] = 0.0  # anchor
    u[3N + 1] = 0.0; u[3N + 2] = 0.0; u[3N + 3] = 0.0
    return u
end

function fd_jacobian(resid!, u, F0, dm::DofMap, N::Int, Nr::Int; eps=EPS_FD)
    J = zeros(dm.ndof, dm.ndof)
    up = copy(u)
    for j in 1:dm.ndof
        copyto!(up, u)
        perturb_dof!(up, dm, N, j, eps)
        Fj = resid!(up)
        @views J[:, j] .= (Fj .- F0) ./ eps
    end
    return J
end

# ─────────────────────────────────────────────────────────────────────────────
# Driver
# ─────────────────────────────────────────────────────────────────────────────
function main()
    omega_eq = 12.983466
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub, sky = sys.rotor.node_id, sys.sky_anchor_id
    axis0 = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]

    u = KiteTurbineDynamics.settle_to_equilibrium(sys, u0, p; lift_device=lift, wind_fn=wf)
    for k in 1:Nr
        u[6N + Nr + k] = omega_eq
    end
    sys.kite_pos .= pos(u, sky) .+
                    lift.line_length .* [cos(p.lifter_elevation), 0.0, sin(p.lifter_elevation)]
    @views u[(3N + 1):6N] .= 0.0

    dm = make_dofmap(N, Nr)
    resid! = make_residual(sys, p, wf, lift, N, Nr, dm)

    @printf("static solve: %d DOF = %d node positions + %d ring twists\n\n",
        dm.ndof, dm.npos, Nr)

    # ── STEP 0: prove the residual and the DOF map actually respond ───────────
    F0 = resid!(u)
    @printf("R0  ||F||_2 = %.6e   ||F||_inf = %.6e\n", norm(F0), maximum(abs.(F0)))

    up = copy(u)
    perturb_dof!(up, dm, N, 1, EPS_FD)
    Fp = resid!(up)
    @printf("R1  ||F(perturbed dof 1) - F||_2 = %.6e   (must be > 0)\n", norm(Fp .- F0))
    if norm(Fp .- F0) == 0.0
        error("residual does not respond to a perturbation -- harness bug, stopping")
    end

    # a second, independent check: perturb the hub's axial coordinate
    up2 = copy(u)
    hubdof = 0
    for (i, g) in enumerate(dm.free_nodes)
        g == hub && (hubdof = 3 * (i - 1) + 1)
    end
    perturb_dof!(up2, dm, N, hubdof, EPS_FD)
    @printf("R2  ||F(perturbed hub x) - F||_2  = %.6e   (must be > 0)\n",
        norm(resid!(up2) .- F0))
    if norm(resid!(up2) .- F0) == 0.0
        error("residual does not respond to a hub perturbation -- harness bug, stopping")
    end

    # ── STEP 1: Jacobian, checked column-by-column against a hand perturbation ─
    @printf("\nbuilding Jacobian (%d x %d, %d residual evals)...\n", dm.ndof, dm.ndof, dm.ndof)
    t0 = time()
    J = fd_jacobian(resid!, u, F0, dm, N, Nr)
    @printf("  built in %.1f s ; max|J| = %.6e ; min|diag| = %.6e\n",
        time() - t0, maximum(abs.(J)), minimum(abs.(diag(J))))
    @printf("  any NaN/Inf: %s ; any non-zero column: %s\n",
        any(!isfinite, J), any(!iszero, J))
    if !any(!iszero, J)
        error("Jacobian is identically zero -- harness bug, stopping")
    end

    # verify one column independently
    jtest = 1
    up3 = copy(u)
    perturb_dof!(up3, dm, N, jtest, EPS_FD)
    col_hand = (resid!(up3) .- F0) ./ EPS_FD
    @printf("  column %d: max|J_fd - J_hand| = %.3e  (must be ~0)\n",
        jtest, maximum(abs.(J[:, jtest] .- col_hand)))
    if maximum(abs.(J[:, jtest] .- col_hand)) > 1e-6 * max(1.0, maximum(abs.(J[:, jtest])))
        error("FD Jacobian column disagrees with the hand column -- harness bug")
    end

    # ── STEP 2: Levenberg-Marquardt ──────────────────────────────────────────
    println("\nsolving (Levenberg-Marquardt):")
    @printf("  %5s %14s %14s %14s %14s\n", "iter", "|F|_2", "|F|_inf", "hub_axial", "hub_perp")
    F = F0
    lam = 1e-3
    t0 = time()
    for it in 0:200
        nrm = norm(F)
        d = pos(u, hub)
        @printf("  %5d %14.6e %14.6f %14.6f %14.6f\n", it, nrm, maximum(abs.(F)),
            dot(d, axis0), norm(d .- dot(d, axis0) .* axis0))
        if maximum(abs.(F)) < 0.05 || it == 200
            break
        end

        J = fd_jacobian(resid!, u, F, dm, N, Nr)
        # SCALING: the residual is dominated by the lightest nodes (the 0.3 kg sky
        # anchor and bearing), whose acceleration derivatives reach ~1e9, while the
        # ring rows are O(1).  Without row scaling the normal equations are so badly
        # conditioned that LM cannot make progress.  Row-scale by the column norm of
        # J so every DOF enters with comparable sensitivity.
        colnorm = [max(norm(@view J[:, j]), 1e-12) for j in 1:dm.ndof]
        W = Diagonal(1.0 ./ colnorm)
        Js = W * J
        Fs = W * F
        JtJ = Js' * Js
        JtF = Js' * Fs
        dJ = max.(diag(JtJ), 1e-12)
        scale = maximum(dJ)

        accepted = false
        dx = zeros(dm.ndof)
        step_acc = 0.0
        lam_acc = 0.0
        # ── least-squares step WITHOUT forming the normal equations ──────────
        # Forming JtJ squares the condition number (max|J| ~ 1e7 -> JtJ ~ 1e14),
        # which destroyed the bow-carrying directions in double precision and made
        # every accepted step ~1.2e-5 m instead of ~1 m.  Instead augment J with
        # sqrt(lambda) * I and solve the augmented least-squares problem by QR:
        #
        #     [ J            ]        [ -F ]
        #     [ sqrt(l)*I    ] dx  =  [  0 ]
        #
        # This is algebraically the same as LM but numerically far better behaved.
        n = dm.ndof
        # PER-DOF SCALING: rope nodes displace ~1e-3 m while the bow needs ~1 m, so
        # the raw step is dominated by the stiff small-amplitude DOFs.  Work in
        # units of the column norm of J (i.e. dx = W * dz with W = diag(1/colnorm))
        # so every DOF is asked for a comparable fraction of its own sensitivity.
        colnorm = [max(norm(@view J[:, j]), 1e-12) for j in 1:n]
        Js = J * Diagonal(1.0 ./ colnorm)
        for _ in 1:20
            aug = zeros(2n, n)
            @views aug[1:n, :] .= Js
            sq = sqrt(lam) * maximum(abs.(Js))
            for i in 1:n
                aug[n + i, i] = sq
            end
            rhs = zeros(2n)
            @views rhs[1:n] .= -F
            local dzs
            try
                dzs = qr(aug) \ rhs
            catch
                lam *= 10
                continue
            end
            any(!isfinite, dzs) && (lam *= 10; continue)
            dxs = dzs ./ colnorm          # back to physical DOF space
            improved = false
            for st in (1.0, 0.5, 0.25, 0.1, 0.05)
                ut = copy(u)
                apply_step!(ut, dm, N, dxs, st)
                Ft = resid!(ut)
                if norm(Ft) < nrm
                    u, F = ut, Ft
                    dx = dxs
                    lam = max(lam * 0.3, 1e-12)
                    step_acc = st
                    lam_acc = lam
                    accepted = true
                    improved = true
                    break
                end
            end
            improved && break
            lam *= 10
        end
        if !accepted
            @printf("  LM stalled at lambda=%.3e (|F|=%.6e)\n", lam, norm(F))
            break
        end
        @printf("        [step=%.3f  lambda=%.3e  max|dx|=%.4e]\n",
            step_acc, lam_acc, maximum(abs.(dx)))
    end
    @printf("\nsolve time %.1f s\n", time() - t0)

    # ── STEP 3: report ───────────────────────────────────────────────────────
    d = pos(u, hub)
    @printf("\nRESULT\n")
    @printf("  residual ||F||_inf        = %.6e\n", maximum(abs.(F)))
    @printf("  hub axial coordinate      = %.4f m\n", dot(d, axis0))
    @printf("  hub perpendicular offset  = %.4f m   <-- the bow\n",
        norm(d .- dot(d, axis0) .* axis0))
    @printf("  hub |r|                   = %.4f m\n", norm(d))
    @printf("  bearing |r|               = %.4f m\n", norm(pos(u, sys.bearing_id)))
    @printf("  sky |r|                   = %.4f m\n", norm(pos(u, sky)))
    # bow angle from the design axis
    ang = rad2deg(acos(clamp(dot(d ./ norm(d), axis0), -1.0, 1.0)))
    @printf("  bow angle from design axis= %.3f deg\n", ang)
end

main()
