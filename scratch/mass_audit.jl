# scratch/mass_audit.jl
#
# READ-ONLY. Finds the absurd node mass (the assembly sum came out at 1e36 kg).
# Every force quoted this session is a mass times an acceleration, so if a mass is
# wrong, the forces are wrong.

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N = sys.n_total
    @printf("N = %d\n", N)

    tot = 0.0
    bad = Tuple{Int,Float64,String}[]
    biggest = Tuple{Int,Float64,String}[]
    for gid in 1:N
        nd = sys.nodes[gid]
        m = nd.mass
        tot += m
        push!(biggest, (gid, m, string(typeof(nd))))
        if !(m > 0.0 && m < 1.0e4) || !isfinite(m)
            push!(bad, (gid, m, string(typeof(nd))))
        end
    end
    @printf("total mass = %.6f kg\n", tot)
    @printf("implausible nodes = %d\n", length(bad))
    for (gid, m, t) in bad
        @printf("  node %3d  %-16s mass = %g\n", gid, t, m)
    end

    sort!(biggest; by=x -> -x[2])
    @printf("\n8 heaviest nodes:\n")
    for (gid, m, t) in biggest[1:8]
        @printf("  node %3d  %-16s mass = %.6f kg\n", gid, t, m)
    end

    @printf("\nground ring node 1: mass=%g  type=%s  radius=%g\n",
        sys.nodes[1].mass, string(typeof(sys.nodes[1])),
        (sys.nodes[1] isa RingNode) ? (sys.nodes[1]::RingNode).radius : -1.0)

    # what does the model's own airborne-mass function say?
    m_air = expansion_airborne_mass(sys, p; include_lifter=false)
    @printf("\nexpansion_airborne_mass = %.4f kg\n", m_air)
    @printf("sum of all node masses  = %.4f kg\n", tot)
    @printf("difference              = %.4f kg\n", tot - m_air)
end

main()
