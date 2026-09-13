using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    u = KiteTurbineDynamics.settle_to_equilibrium(sys, u0, p; lift_device=lift, wind_fn=wf)
    for k in 1:Nr; u[6N + Nr + k] = 12.983466; end
    @views u[(3N + 1):6N] .= 0.0
    ssz = 6N + 2Nr

    function resid(uu)
        du = zeros(ssz)
        KiteTurbineDynamics.multibody_ode!(du, uu, (sys, p, wf, lift), 0.0)
        return du[(3N + 1):6N]        # accelerations only
    end

    F = resid(u)
    @printf("norm(F) = %.6e  (length %d)\n", norm(F), length(F))

    up = copy(u)
    node = 2
    up[3 * (node - 1) + 1] += 1e-3
    F1 = resid(up)
    @printf("norm(F1) = %.6e\n", norm(F1))
    @printf("norm(F1 - F) = %.6e\n", norm(F1 .- F))
    @printf("are they the same object? %s\n", F === F1)

    # now the same but through a function that returns a *subset* by index
    npos = 3 * (N - 1)
    function resid_sub(uu)
        du = zeros(ssz)
        KiteTurbineDynamics.multibody_ode!(du, uu, (sys, p, wf, lift), 0.0)
        out = zeros(npos + Nr)
        for (i, g) in enumerate(2:N)
            out[3*(i-1)+1] = du[3N + 3*(g-1) + 1]
            out[3*(i-1)+2] = du[3N + 3*(g-1) + 2]
            out[3*(i-1)+3] = du[3N + 3*(g-1) + 3]
        end
        for ri in 1:Nr; out[npos + ri] = du[6N + Nr + ri]; end
        return out
    end
    G = resid_sub(u)
    up2 = copy(u); up2[3 * (node - 1) + 1] += 1e-3
    G1 = resid_sub(up2)
    @printf("\nsubset version: norm(G)=%.6e norm(G1)=%.6e norm(G1-G)=%.6e\n",
        norm(G), norm(G1), norm(G1 .- G))
    @printf("same object? %s\n", G === G1)
end
main()
