using KiteTurbineDynamics, LinearAlgebra

p = params_10kw()
sys, u0 = build_kite_turbine_system(p)

N = sys.n_total;
Nr = sys.n_ring
u = copy(u0)

# simulate what bisection does, but add z-shift
α_cum = 0.0
β_a = p.elevation_angle
sd = [cos(β_a), 0.0, sin(β_a)]
pp1, pp2 = shaft_perp_basis(sd)

cumulative_shift = 0.0

for s in 1:(Nr - 1)
    gid_a = sys.ring_ids[s]
    gid_b = sys.ring_ids[s + 1]
    na = sys.nodes[gid_a]::KiteTurbineDynamics.RingNode
    nb = sys.nodes[gid_b]::KiteTurbineDynamics.RingNode

    ctr_a = u[(3 * (gid_a - 1) + 1):(3 * gid_a)]

    # We must shift ctr_b by cumulative_shift
    ctr_b_old = u[(3 * (gid_b - 1) + 1):(3 * gid_b)]
    ctr_b = ctr_b_old .- cumulative_shift .* sd

    # In a real scenario, we'd bisect for Δα_eq. Here we just pick a nominal 10 degrees
    Δα_eq = deg2rad(10.0)

    # Before twist, the chord was chord_0
    pa_0 = attachment_point(ctr_a, na.radius, α_cum, 1, p.n_lines, pp1, pp2)
    pb_0 = attachment_point(ctr_b, nb.radius, α_cum, 1, p.n_lines, pp1, pp2)
    chord_0 = norm(pb_0 .- pa_0)

    # We want to find a new ctr_b (shifted by extra_shift along sd) such that
    # the twisted chord equals chord_0
    # The new pb will be:
    # pb_twist = attachment_point(ctr_b .- extra_shift .* sd, nb.radius, α_cum + Δα_eq, 1, p.n_lines, pp1, pp2)
    # norm(pb_twist .- pa_0) == chord_0

    # Analytical:
    # chord_0^2 = dz_old^2 + dr^2
    # chord_new^2 = dz_new^2 + dr^2 + 2 * r_a * r_b * (1 - cos(Δα_eq))
    # Setting them equal:
    # dz_new^2 = dz_old^2 - 2 * r_a * r_b * (1 - cos(Δα_eq))

    dz_old = norm(ctr_b .- ctr_a)
    dr = nb.radius - na.radius

    val = dz_old^2 - 2 * na.radius * nb.radius * (1 - cos(Δα_eq))
    if val > 0
        dz_new = sqrt(val)
        extra_shift = dz_old - dz_new
        cumulative_shift += extra_shift
    else
        println("Warning: Twist too large for segment $s")
    end

    α_cum += Δα_eq

    # Now we would actually apply the shift to ring_b and all its ropes
    # (We can just accumulate and apply later)
end

println("Total contraction: ", cumulative_shift, " meters")
