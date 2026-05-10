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
function attachment_point(centre::AbstractVector, R::Real,
                           alpha::Real, j::Int, n_lines::Int,
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

"""
    _tilted_ring_basis(u, sys, hub_gid, hub_ri) → (perp1, perp2)

Compute the tilted ring-plane basis from the quasi-static tilt model.
Uses `sys.ring_tilt_axis[hub_ri]` (stored non-shaft torque from the previous
ODE step) to tilt the ring-plane normal away from the shaft direction.
Returns the two basis vectors spanning the tilted ring plane.
"""
function _tilted_ring_basis(u::AbstractVector, sys::KiteTurbineSystem,
                             hub_gid::Int, hub_ri::Int)
    hub_p = u[3*(hub_gid-1)+1 : 3*hub_gid]
    hmag  = norm(hub_p)
    shaft = hmag > 0.1 ? hub_p ./ hmag : [cos(0.5236), 0.0, sin(0.5236)]  # fallback 30°
    tau   = sys.ring_tilt_axis[hub_ri]
    tau_ns = tau .- dot(tau, shaft) .* shaft
    tilted = normalize(shaft .+ DISC_TILT_COMPLIANCE .* tau_ns .+ [1e-12, 1e-12, 1e-12])
    return shaft_perp_basis(tilted)
end
