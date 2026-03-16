using LinearAlgebra

"""
    shaft_perp_basis(shaft_dir) → (perp1, perp2)

Two unit vectors spanning the plane perpendicular to shaft_dir.
perp1 × perp2 is parallel to shaft_dir (right-hand rule).
"""
function shaft_perp_basis(shaft_dir::AbstractVector)
    ref   = abs(shaft_dir[3]) < 0.99 ? [0.0, 0.0, 1.0] : [0.0, 1.0, 0.0]
    perp1 = normalize(cross(shaft_dir, ref))
    perp2 = cross(shaft_dir, perp1)
    return perp1, perp2
end

"""
    attachment_point(centre, R, alpha, j, n_lines, perp1, perp2) → Vector{Float64}

3D position of line j's attachment point on a ring with centre `centre`,
radius `R`, twist angle `alpha`, in a plane with basis (perp1, perp2).
"""
function attachment_point(centre::AbstractVector, R::Float64,
                           alpha::Float64, j::Int, n_lines::Int,
                           perp1::AbstractVector, perp2::AbstractVector)
    φ = alpha + (j - 1) * (2π / n_lines)
    return centre .+ R .* (cos(φ) .* perp1 .+ sin(φ) .* perp2)
end

"""
    rope_helix_pos(pos_a, pos_b, frac) → Vector{Float64}

Linear interpolation between two attachment points at fraction `frac` ∈ [0,1].
Used to place rope nodes at initialisation. Gravity will sag them from this
straight-line position during the pre-solve settling step.
"""
function rope_helix_pos(pos_a::AbstractVector, pos_b::AbstractVector, frac::Float64)
    return pos_a .+ frac .* (pos_b .- pos_a)
end
