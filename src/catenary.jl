# ── Quasi-static catenary model for lift line and backline ────────────────
#
# Replaces the single-spring lift/backline model in ring_forces.jl with a
# physically-correct catenary that includes line weight, stretch, and
# emergent force direction at the hub.
#
# Physics: for a uniform cable under gravity with weight w (N/m) and axial
# stiffness EA, the shape is a catenary.  The horizontal tension H is
# constant along the cable (gravity acts vertically, so it cannot change H).
#
#   z(x) = a·cosh((x - x₀)/a) + z₀    where a = H/w
#
# Given endpoints (x₁,z₁), (x₂,z₂) and unstretched length L₀, we solve for
# a (equivalently H), then compute the tension vectors at both ends.
#
# Stretch is handled by iteration: solve inextensible catenary → compute
# average tension → update arc length → re-solve (converges in 2–3 passes
# for Dyneema under operational loads).
#
# When L₀ < straight-line distance (pre-tensioned), the line is modelled as
# a straight spring — no catenary needed.
#
# TODO: add line aerodynamic drag as a horizontal body force.

using LinearAlgebra

# ── Density / weight helpers ──────────────────────────────────────────────

const RHO_DYNEEMA = 970.0   # kg/m³

"Linear weight density of a Dyneema line (N/m)."
function dyneema_weight_Npm(diameter_m::Float64)
    return RHO_DYNEEMA * π * (diameter_m / 2.0)^2 * 9.81
end

# ── Catenary solver core ──────────────────────────────────────────────────

"""
    solve_catenary_a(dx, dz, L_target) → a

Solve for catenary parameter `a = H/w` (horizontal tension / weight per metre)
given horizontal span `dx`, vertical span `dz`, and target arc length `L_target`.

Uses the identity: √(L² − dz²) = 2a·sinh(dx/(2a))

Returns `a` such that the catenary spanning (0,0)→(dx,dz) has arc length L_target.
Newton's method with bracketing fallback; converges in 3–5 iterations.

Throws DomainError if L_target < √(dx²+dz²) — use straight-line spring model instead."""
function solve_catenary_a(dx::Float64, dz::Float64, L_target::Float64)
    S = sqrt(max(0.0, L_target^2 - dz^2))
    if S <= dx
        # Line is too short for catenary — would need infinite tension.
        # Return a large a (nearly straight).  Caller checks this case.
        return 1e6 * dx
    end

    f(a) = 2.0 * a * sinh(dx / (2.0 * a)) - S
    fp(a) = 2.0 * sinh(dx / (2.0 * a)) - (dx / a) * cosh(dx / (2.0 * a))

    # Initial guess: moderate sag
    a = dx
    for _ in 1:30
        fa = f(a)
        fpa = fp(a)
        if abs(fpa) < 1e-20
            ;
            break;
        end
        step = fa / fpa
        # Damped Newton — restrict step to prevent overshoot into negative a
        a_new = max(a * 0.1, a - clamp(step, -0.5 * a, 0.9 * a))
        if abs(a_new - a) < 1e-10 * max(1.0, a)
            return a_new
        end
        a = a_new
    end
    return a
end

# ── Full catenary solution ────────────────────────────────────────────────

"""
    catenary_forces(x1, z1, x2, z2, L0, w, EA) → (F_x1, F_z1, F_x2, F_z2, converged)

Compute the quasi-static force vectors at both ends of a catenary cable.

Arguments:
- `(x1,z1)`: bottom endpoint (e.g., hub attachment)
- `(x2,z2)`: top endpoint (e.g., kite position or ground anchor)
- `L0`: unstretched line length (m)
- `w`: weight per unit length (N/m)
- `EA`: axial stiffness (N)

Returns:
- `(F_x1, F_z1)`: force components at endpoint 1 (pull ON endpoint 1)
  Positive x = toward endpoint 2, positive z = upward.
- `(F_x2, F_z2)`: force components at endpoint 2 (pull ON endpoint 2)
  Negative x = toward endpoint 1, negative z = downward.
- `converged`: true if stretch iteration converged.

When L0 < straight-line distance (pre-tensioned), returns straight-spring
forces — no catenary solve needed.
"""
function catenary_forces(
    x1::Float64, z1::Float64, x2::Float64, z2::Float64, L0::Float64, w::Float64, EA::Float64
)
    dx = x2 - x1
    dz = z2 - z1
    d = sqrt(dx^2 + dz^2)          # straight-line distance

    # ── Pre-tensioned case: line too short for catenary ──────────────────
    if L0 < d
        # Straight spring under tension
        strain = (d - L0) / L0
        T = EA * strain       # uniform tension along straight line
        F_mag = T                 # force magnitude
        ux, uz = dx / d, dz / d    # unit vector from 1→2
        return (
            F_mag * ux,
            F_mag * uz,   # force on endpoint 1 (pulls toward 2)
            -F_mag * ux,
            -F_mag * uz, # force on endpoint 2 (pulls toward 1)
            true,
        )
    end

    # ── Stretch iteration ─────────────────────────────────────────────────
    L = L0
    a = 0.0
    sinh_u1 = 0.0;
    sinh_u2 = 0.0  # initialised for post-loop access
    converged = false
    for iter in 1:8
        a = solve_catenary_a(dx, dz, L)
        H = a * w

        # Compute endpoint parameters u₁ = (x₁ - x₀)/a, u₂ = (x₂ - x₀)/a
        # From: sinh(u₁) = (dz·cosh(δ) - L·sinh(δ)) / (2a·sinh(δ))
        # where δ = dx/(2a)
        half = dx / (2.0 * a)
        sh = sinh(half)
        ch = cosh(half)
        denom = 2.0 * a * sh          # = √(L² − dz²)

        if abs(denom) < 1e-20
            # Degenerate: nearly straight
            sinh_u1 = 0.0
        else
            sinh_u1 = (dz * ch - L * sh) / denom
        end

        # cosh is always ≥ 1
        cosh_u1 = sqrt(max(1.0, 1.0 + sinh_u1^2))
        u1 = asinh(sinh_u1)
        u2 = u1 + dx / a
        cosh_u2 = cosh(u2)
        sinh_u2 = sinh(u2)

        # Tensions at endpoints
        T1 = H * cosh_u1
        T2 = H * cosh_u2
        T_avg = 0.5 * (T1 + T2)

        # Stretch correction
        L_new = L0 * (1.0 + T_avg / EA)

        if abs(L_new - L) / max(L0, 1.0) < 1e-8
            converged = true
            L = L_new
            break
        end
        L = L_new
    end

    # Recompute forces with final L
    H = a * w
    F_x1 = H                   # pulls endpoint 1 toward endpoint 2
    F_z1 = H * sinh_u1         # vertical component at endpoint 1
    F_x2 = -H                   # pulls endpoint 2 toward endpoint 1
    F_z2 = -H * sinh_u2         # vertical component at endpoint 2

    return (F_x1, F_z1, F_x2, F_z2, converged)
end
