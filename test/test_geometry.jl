using LinearAlgebra

@testset "geometry" begin
    β = deg2rad(30.0)
    shaft_dir = [cos(β), 0.0, sin(β)]
    perp1, perp2 = shaft_perp_basis(shaft_dir)

    # Basis vectors are unit length
    @test norm(perp1) ≈ 1.0 atol=1e-10
    @test norm(perp2) ≈ 1.0 atol=1e-10

    # All three are mutually orthogonal
    @test abs(dot(shaft_dir, perp1)) < 1e-10
    @test abs(dot(shaft_dir, perp2)) < 1e-10
    @test abs(dot(perp1, perp2))     < 1e-10

    # Attachment point is at correct radius from ring centre
    centre = [10.0, 0.0, 8.0]
    R      = 2.5
    alpha  = 0.3
    j      = 1
    n_lines = 5
    pt = attachment_point(centre, R, alpha, j, n_lines, perp1, perp2)
    @test norm(pt .- centre) ≈ R atol=1e-10

    # Five attachment points are equally spaced (same radius, 2π/5 apart)
    pts = [attachment_point(centre, R, alpha, j, n_lines, perp1, perp2) for j in 1:5]
    for j in 1:5
        @test norm(pts[j] .- centre) ≈ R atol=1e-10
    end
    angles = [atan(dot(pts[j].-centre, perp2), dot(pts[j].-centre, perp1)) for j in 1:5]
    diffs  = diff(sort(angles))
    @test all(d -> abs(d - 2π/5) < 1e-8, diffs)

    # Helix interpolation: fraction=0 → attachment A, fraction=1 → attachment B
    pos_A = pts[1]
    pos_B = [12.0, 1.0, 9.5]
    @test rope_helix_pos(pos_A, pos_B, 0.0) ≈ pos_A atol=1e-10
    @test rope_helix_pos(pos_A, pos_B, 1.0) ≈ pos_B atol=1e-10
end
