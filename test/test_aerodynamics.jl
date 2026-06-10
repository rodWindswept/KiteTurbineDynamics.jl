@testset "aerodynamics" begin
    # Cp peaks near TSR 4.0–5.2 for this NACA4412 AeroDyn BEM rotor at 0° elevation.
    # Peak Cp ≈ 0.309 at λ ≈ 5.2. Broad plateau from λ≈4.0–5.5.
    @test cp_at_tsr(4.1) > 0.2
    @test cp_at_tsr(0.0) ≈ 0.0 atol=0.01
    @test cp_at_tsr(7.0) > 0.0   # 0° tables: Cp stays positive through λ=8.0 (no freewheeling crossover)

    # Ct is positive and bounded
    @test ct_at_tsr(7.0) > 0.0
    @test ct_at_tsr(7.0) < 1.0
end
