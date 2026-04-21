@testset "parameters" begin
    p = params_10kw()
    @test p.n_rings == 14
    @test p.n_lines == 5
    @test p.rotor_radius > 0
    @test p.tether_length > 0
    @test p.v_wind_ref > 0
end
