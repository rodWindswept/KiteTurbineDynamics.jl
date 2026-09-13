# READ-ONLY. Is the LM step NaN, or is it genuinely not descending?
using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function main()
    eps = parse(Float64, get(ENV, "KTD_EPS", "1e-3"))
    omega_eq = 12.983466
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub = sys.rotor.node_id; sky = sys.sky_anchor_id
    u = KiteTurbineDynamics.settle_to_equilibrium(sys, u0, p; lift_device=lift, wind_fn=wf)
    for k in 1:Nr; u[6N + Nr + k] = omega_eq; end
    sys.kite_pos .= pos(u, sky) .+ lift.line_length .* [cos(p.lifter_elevation), 0.0, sin(p.lifter_elevation)]
    @views u[(3N + 1):6N] .= 0.0

    free_nodes = [g for g in 1:N if g != 1]
    npos = 3 * length(free_nodes); ndof = npos + Nr
    nod = zeros(Int, ndof); cmp = zeros(Int, ndof)
    for (i, g) in enumerate(free_nodes), k in 1:3
        nod[3 * (i - 1) + k] = g; cmp[3 * (i - 1) + k] = k
    end
    ssz = 6N + 2Nr
    du = zeros(ssz)
    function resid!(uu)
        fill!(du, 0.0)
        KiteTurbineDynamics.multibody_ode!(du, uu, (sys, p, wf, lift), 0.0)
        F = zeros(ndof)
        for (i, g) in enumerate(free_nodes)
            b = 3N + 3 * (g - 1) + 1
            F[3*(i-1)+1] = du[b]; F[3*(i-1)+2] = du[b+1]; F[3*(i-1)+3] = du[b+2]
        end
        for ri in 1:Nr; F[npos + ri] = du[6N + Nr + ri]; end
        return F
    end
    perturb_dof! = (uu, j, e) -> begin
        if j <= npos
            uu[3 * (nod[j] - 1) + cmp[j]] += e
        else
            uu[6N + (j - npos)] += e
        end
    end
    apply! = (uu, dx, s) -> begin
        for (i, g) in enumerate(free_nodes)
            for k in 1:3
                uu[3*(g-1)+k] += s * dx[3*(i-1)+k]
            end
        end
        for ri in 1:Nr; uu[6N + ri] += s * dx[npos + ri]; end
        @views uu[(3N+1):6N] .= 0.0
        uu[1]=uu[2]=uu[3]=0.0; uu[3N+1]=uu[3N+2]=uu[3N+3]=0.0
        uu
    end

    F = resid!(u)
    @printf("eps = %.0e ; ||F||_2 = %.6e\n", eps, norm(F))
    # sanity: perturb the FIRST dof by hand and see whether F changes
    up = copy(u)
    @printf("dof1 -> node %d component %d\n", nod[1], cmp[1])
    perturb_dof!(up, 1, eps)
    @printf("  after perturb, u[%d] = %.10f (was %.10f)\n",
        3*(nod[1]-1)+cmp[1], up[3*(nod[1]-1)+cmp[1]], u[3*(nod[1]-1)+cmp[1]])
    F1 = resid!(up)
    @printf("  ||F1-F||_2 = %.6e ; ||F1|| = %.6e\n", norm(F1 .- F), norm(F1))
    J = zeros(ndof, ndof); up = copy(u)
    for j in 1:ndof
        copyto!(up, u); perturb_dof!(up, j, eps)
        Fj = resid!(up)
        J[:, j] .= (Fj .- F) ./ eps
    end
    @printf("Jacobian: max|J|=%.4e  min diag=%.4e  any NaN=%s\n",
        maximum(abs.(J)), minimum(abs.(diag(J))), any(isnan, J))
    JtJ = J' * J; JtF = J' * F
    @printf("JtJ finite=%s ; JtF norm=%.4e ; JtF first 3 = %s\n",
        all(isfinite, JtJ), norm(JtF), string(round.(JtF[1:3], digits=3)))
    dJ = max.(diag(JtJ), 1e-12)
    lam = 1e-3 * maximum(dJ)
    for trial in 1:8
        A = JtJ + lam * Diagonal(dJ)
        dx = A \ (-JtF)
        if any(!isfinite, dx)
            @printf("  lam=%.2e -> dx has non-finite entries\n", lam); lam *= 10; continue
        end
        @printf("  lam=%.2e  |dx|=%.4e  max|dx|=%.4e\n", lam, norm(dx), maximum(abs.(dx)))
        for s in (1.0, 0.5, 0.1, 0.01)
            ut = copy(u); apply!(ut, dx, s)
            Ft = resid!(ut)
            @printf("      step=%.2f -> ||F||=%.6e  %s\n", s, norm(Ft),
                norm(Ft) < norm(F) ? "DESCENT" : "")
        end
        break
    end
end
main()
