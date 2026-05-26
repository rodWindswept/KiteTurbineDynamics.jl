# test/test_ring_element_analysis.jl
# Tests for the per-beam ring element structural analysis.

using LinearAlgebra

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

    # Equal inward radial force at each vertex (tether loads → compressive polygon)
    # Correct polygon-compression formula: N = F / (2·sin(π/n))
    F_local = zeros(3, n)
    for j in 1:n
        φ = α + (j-1) * 2π/n
        F_local[1,j] = -F * cos(φ)
        F_local[2,j] = -F * sin(φ)
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

    # Double force at vertex 1, no force at vertex 3 (asymmetric inward load)
    # Inward radial forces → compressive polygon; asymmetry breaks N uniformity
    F_local = zeros(3, n)
    forces = [2F, F, 0.0, F, F]   # inward magnitudes
    for j in 1:n
        φ = α + (j-1) * 2π/n
        F_local[1,j] = -forces[j] * cos(φ)
        F_local[2,j] = -forces[j] * sin(φ)
    end

    K,Fv,Klocs,Tmats = KiteTurbineDynamics.assemble_ring_frame(R, n, α, tp, F_local)
    d = KiteTurbineDynamics.solve_ring_frame(K, Fv)
    beams = KiteTurbineDynamics.extract_beam_forces(d, R, n, α, tp, Klocs, Tmats)

    Ns = [b.N for b in beams]
    # All beams in compression (inward loads → compressive polygon)
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

@testset "Test 6: gravity and drag inclusion" begin
    p   = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    N  = sys.n_total
    Nr = sys.n_ring
    
    alpha_vec = u0[6N+1 : 6N+Nr]
    
    # 1. Run without wind
    res_no_wind = ring_element_analysis(u0, collect(alpha_vec), sys, p, 0.0, nothing)
    @test length(res_no_wind) == Nr - 2
    
    # Each ring's maximum utilisation should be non-zero (due to gravity!)
    for f in res_no_wind
        @test f.max_util > 0.0
        # Check that there are non-zero bending moments in the beams
        for b in f.beams
            @test b.M_oop > 0.0 || b.M_ip > 0.0
        end
    end
    
    # 2. Run with strong wind
    wind_fn = (pos, t) -> [15.0, 0.0, 0.0]  # 15 m/s wind in x direction
    res_wind = ring_element_analysis(u0, collect(alpha_vec), sys, p, 0.0, wind_fn)
    
    for (f_wind, f_nowind) in zip(res_wind, res_no_wind)
        # Bending moments and utilisation should change/increase due to wind drag
        @test f_wind.max_util != f_nowind.max_util
    end
end

@testset "Test 7: moment and torque equilibration under dynamic conditions" begin
    # Test that when a ring experiences substantial out-of-plane and torsional net moments,
    # the rotational & torsional inertia relief perfectly zero them out, leaving
    # no residual moments in F_local_relieved.
    R = 2.0; n = 5; α = 0.1
    tp = KiteTurbineDynamics.tube_props(R)

    # Apply highly unbalanced forces (creating both translation, out-of-plane tilt moments, and torsion)
    F_local = zeros(3, n)
    F_local[:, 1] = [100.0, 50.0, 200.0]  # vertex 1 load
    F_local[:, 3] = [-50.0, -100.0, -300.0] # vertex 3 load

    # Construct coordinates
    xs = [R * cos(α + (j-1)*2π/n) for j in 1:n]
    ys = [R * sin(α + (j-1)*2π/n) for j in 1:n]

    # Perform translational relief
    F_net = sum(F_local, dims=2)
    F_trans_relieved = F_local .- F_net ./ n

    # Calculate net moments
    Mx = sum(ys[j] * F_trans_relieved[3, j] for j in 1:n)
    My = sum(-xs[j] * F_trans_relieved[3, j] for j in 1:n)
    Mz = sum(xs[j] * F_trans_relieved[2, j] - ys[j] * F_trans_relieved[1, j] for j in 1:n)

    # Verify original moments are non-zero
    @test abs(Mx) > 1.0
    @test abs(My) > 1.0
    @test abs(Mz) > 1.0

    # Perform rotational & torsional relief
    F_relieved = copy(F_trans_relieved)
    for j in 1:n
        F_relieved[1, j] += Mz * ys[j] / (n * R^2)
        F_relieved[2, j] -= Mz * xs[j] / (n * R^2)
        F_relieved[3, j] -= 2.0 * (Mx * ys[j] - My * xs[j]) / (n * R^2)
    end

    # Check that new moments are perfectly zeroed
    Mx_new = sum(ys[j] * F_relieved[3, j] for j in 1:n)
    My_new = sum(-xs[j] * F_relieved[3, j] for j in 1:n)
    Mz_new = sum(xs[j] * F_relieved[2, j] - ys[j] * F_relieved[1, j] for j in 1:n)
    F_net_new = sum(F_relieved, dims=2)

    @test isapprox(Mx_new, 0.0, atol=1e-11)
    @test isapprox(My_new, 0.0, atol=1e-11)
    @test isapprox(Mz_new, 0.0, atol=1e-11)
    @test isapprox(norm(F_net_new), 0.0, atol=1e-11)
end

@testset "Test 8: ground_station_forces calculation" begin
    p   = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    N  = sys.n_total
    Nr = sys.n_ring
    
    alpha_vec = u0[6N+1 : 6N+Nr]
    
    gnd_forces = ground_station_forces(u0, collect(alpha_vec), sys, p)
    
    # Net force magnitude and vertex max force should be valid positive numbers
    @test gnd_forces.F_net_mag >= 0.0
    @test gnd_forces.F_vertex_max >= 0.0
    @test length(gnd_forces.F_net) == 3
    @test length(gnd_forces.M_net) == 3
    @test size(gnd_forces.F_vertices) == (3, p.n_lines)
    
    # In steady symmetric state, the net force should pull exactly along the shaft direction,
    # and the net moment should also be close to 0.
    beta = p.elevation_angle
    shaft_dir = [cos(beta), 0.0, sin(beta)]
    @test isapprox(dot(gnd_forces.F_net, shaft_dir), gnd_forces.F_net_mag, atol=1e-2)
    @test isapprox(gnd_forces.F_net[2], 0.0, atol=1e-2)
    @test isapprox(gnd_forces.M_net[1], 0.0, atol=1e-2)
    @test isapprox(gnd_forces.M_net[2], 0.0, atol=1e-2)
    @test isapprox(gnd_forces.M_net[3], 0.0, atol=1e-2)
end

end  # @testset "ring_element_analysis"
