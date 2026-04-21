@testset "aerodynamics" begin
    # Cp peaks near TSR 4.0–4.1 for this NACA4412 AeroDyn BEM rotor (not TSR 7)
    @test cp_at_tsr(4.1) > 0.2
    @test cp_at_tsr(0.0) ≈ 0.0 atol=0.01
    @test cp_at_tsr(7.0) < 0.0   # negative Cp in freewheeling regime above TSR ≈ 6.5

    # Ct is positive and bounded
    @test ct_at_tsr(7.0) > 0.0
    @test ct_at_tsr(7.0) < 1.0
end
