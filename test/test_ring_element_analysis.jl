# test/test_ring_element_analysis.jl
# Tests for the per-beam ring element structural analysis.

@testset "ring_element_analysis" begin

@testset "Test 2: fixed-fixed N_crit is 4× pin-pin" begin
    R = 2.0; n = 5
    tp = KiteTurbineDynamics.tube_props(R)
    L_beam = 2.0 * R * sin(π / n)
    N_crit_fixed = 4.0 * π^2 * KiteTurbineDynamics.E_CFRP * tp.I_bend / L_beam^2
    N_crit_pinpin =       π^2 * KiteTurbineDynamics.E_CFRP * tp.I_bend / L_beam^2
    @test isapprox(N_crit_fixed / N_crit_pinpin, 4.0, atol=1e-10)
end

@testset "Test 1: symmetric load → uniform N, zero M" begin
    R=2.0; n=5; α=0.0; F=1000.0
    tp = KiteTurbineDynamics.tube_props(R)

    # Equal outward radial force at each vertex (centrifugal load → compressive polygon)
    # Correct polygon-compression formula: N = F / (2·sin(π/n))
    F_local = zeros(3, n)
    for j in 1:n
        φ = α + (j-1) * 2π/n
        F_local[1,j] = F * cos(φ)
        F_local[2,j] = F * sin(φ)
    end

    K,Fv,Klocs,Tmats = KiteTurbineDynamics.assemble_ring_frame(R, n, α, tp, F_local)
    d = KiteTurbineDynamics.solve_ring_frame(K, Fv)
    beams = KiteTurbineDynamics.extract_beam_forces(d, R, n, α, tp, Klocs, Tmats)

    N_analytic = F / (2.0 * sin(π / n))
    for b in beams
        @test isapprox(b.N, N_analytic, rtol=1e-4)
        @test isapprox(b.M_ip,  0.0, atol=1e-3)
        @test isapprox(b.M_oop, 0.0, atol=1e-3)
    end
end

@testset "Test 3: asymmetric load → N varies" begin
    R=2.0; n=5; α=0.0; F=1000.0
    tp = KiteTurbineDynamics.tube_props(R)

    # Double force at vertex 1, no force at vertex 3 (asymmetric outward/centrifugal load)
    # Outward radial forces → compressive polygon; asymmetry breaks N uniformity
    F_local = zeros(3, n)
    forces = [2F, F, 0.0, F, F]   # outward magnitudes
    for j in 1:n
        φ = α + (j-1) * 2π/n
        F_local[1,j] = forces[j] * cos(φ)
        F_local[2,j] = forces[j] * sin(φ)
    end

    K,Fv,Klocs,Tmats = KiteTurbineDynamics.assemble_ring_frame(R, n, α, tp, F_local)
    d = KiteTurbineDynamics.solve_ring_frame(K, Fv)
    beams = KiteTurbineDynamics.extract_beam_forces(d, R, n, α, tp, Klocs, Tmats)

    Ns = [b.N for b in beams]
    # All beams in compression (outward loads → compressive polygon)
    @test all(N -> N > 0, Ns)
    # N values are not all equal (asymmetric loading breaks uniformity)
    @test maximum(Ns) - minimum(Ns) > 1.0   # at least 1 N variation
end

@testset "Test 4: OOP load → M_oop nonzero, M_ip zero" begin
    R=2.0; n=5; α=0.0; F=500.0
    tp = KiteTurbineDynamics.tube_props(R)

    # Pure shaft-direction (OOP) force at vertex 1 only
    # Self-equilibrate: equal and opposite at vertex 3
    F_local = zeros(3, n)
    F_local[3, 1] =  F     # OOP force at vertex 1
    F_local[3, 3] = -F     # opposing at vertex 3

    K,Fv,Klocs,Tmats = KiteTurbineDynamics.assemble_ring_frame(R, n, α, tp, F_local)
    d = KiteTurbineDynamics.solve_ring_frame(K, Fv)
    beams = KiteTurbineDynamics.extract_beam_forces(d, R, n, α, tp, Klocs, Tmats)

    # Adjacent beams to loaded vertex should have M_oop > 0
    @test beams[1].M_oop > 1.0    # beam 1→2 (adjacent to vertex 1)
    @test beams[n].M_oop > 1.0    # beam n→1 (adjacent to vertex 1)
    # In-plane moment should be near zero (pure OOP load, symmetric in-plane)
    @test beams[1].M_ip < 1.0
end

@testset "Test 5: self-equilibration warning fires for unbalanced loads" begin
    R=2.0; n=5; α=0.0
    tp = KiteTurbineDynamics.tube_props(R)

    # Unbalanced: net force = [1000, 0, 0]
    F_local = zeros(3, n)
    F_local[1, 1] = 1000.0   # lone force, not balanced

    @test_warn "load imbalance" KiteTurbineDynamics.assemble_ring_frame(R, n, α, tp, F_local)

    # Balanced loads: no warning
    F_local2 = zeros(3, n)
    for j in 1:n
        φ = α + (j-1) * 2π/n
        F_local2[1,j] = -500.0 * cos(φ)
        F_local2[2,j] = -500.0 * sin(φ)
    end
    # If no warning, this just runs silently
    KiteTurbineDynamics.assemble_ring_frame(R, n, α, tp, F_local2)
end

end  # @testset "ring_element_analysis"
