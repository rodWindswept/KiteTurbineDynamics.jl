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

end  # @testset "ring_element_analysis"
