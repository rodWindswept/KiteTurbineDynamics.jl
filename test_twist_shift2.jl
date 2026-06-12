using KiteTurbineDynamics, LinearAlgebra

p = params_10kw()
sys, u0 = build_kite_turbine_system(p)

ld = rotary_lifter_default()
ω_rated = cbrt(p.p_rated_w / p.k_mppt)
wf = (pos, t) -> [11.0, 0.0, 0.0]

u_start = KiteTurbineDynamics.settle_to_equilibrium(sys, u0, p; lift_device=ld, wind_fn=wf)

N = sys.n_total
Nr = sys.n_ring
τ_rated = p.k_mppt * ω_rated^2
EA_rope = p.e_modulus * π * (p.tether_diameter / 2)^2
β_a = p.elevation_angle
hub_p_settled = u_start[(3 * (sys.rotor.node_id - 1) + 1):(3 * sys.rotor.node_id)]
hp_mag = norm(hub_p_settled)
sd = hp_mag > 0.1 ? hub_p_settled ./ hp_mag : [cos(β_a), 0.0, sin(β_a)]
pp1, pp2 = shaft_perp_basis(sd)
stride = 1 + p.n_lines * 3

for ri in 1:Nr
    ;
    u_start[6N + Nr + ri] = ω_rated;
end
u_start[6N + 1] = 0.0
α_cum = 0.0
τ_target_a = τ_rated

cumulative_shift = 0.0

for s in 1:(Nr - 1)
    gid_a = sys.ring_ids[s]
    gid_b = sys.ring_ids[s + 1]
    na = sys.nodes[gid_a]::KiteTurbineDynamics.RingNode
    nb = sys.nodes[gid_b]::KiteTurbineDynamics.RingNode

    # Apply accumulated shift so far
    u_start[(3 * (gid_a - 1) + 1):(3 * gid_a)] .-= cumulative_shift .* sd
    u_start[(3 * (gid_b - 1) + 1):(3 * gid_b)] .-= cumulative_shift .* sd

    ctr_a = u_start[(3 * (gid_a - 1) + 1):(3 * gid_a)]
    ctr_b = u_start[(3 * (gid_b - 1) + 1):(3 * gid_b)]

    dz_old = norm(ctr_b .- ctr_a)
    L_seg_s = 4 * sys.sub_segs[(s - 1) * p.n_lines * 4 + 1].length_0

    τ_fn_a =
        (Δα) -> begin
            val = dz_old^2 - 2 * na.radius * nb.radius * (1 - cos(Δα))
            dz_new = val > 0.0 ? sqrt(val) : 0.001
            shift_local = dz_old - dz_new
            ctr_b_test = ctr_b .- shift_local .* sd

            τ = 0.0
            for j in 1:p.n_lines
                pa_j = attachment_point(ctr_a, na.radius, α_cum, j, p.n_lines, pp1, pp2)
                pb_j = attachment_point(
                    ctr_b_test, nb.radius, α_cum + Δα, j, p.n_lines, pp1, pp2
                )
                chord_j = norm(pb_j .- pa_j)
                chord_j < 1e-9 && continue
                T_j = EA_rope * max(0.0, (chord_j - L_seg_s) / L_seg_s)
                dir_j = (pb_j .- pa_j) ./ chord_j
                r_vec_a = pa_j .- ctr_a
                τ += T_j * dot(cross(r_vec_a, dir_j), sd)
            end
            τ, shift_local
        end

    lo, hi = 0.001, π / 4
    for _ in 1:60
        mid = (lo + hi) / 2
        τ_mid, _ = τ_fn_a(mid)
        τ_mid < τ_target_a ? (lo = mid) : (hi = mid)
    end
    Δα_eq = (lo + hi) / 2
    _, shift_local = τ_fn_a(Δα_eq)

    cumulative_shift += shift_local
    ctr_b .-= shift_local .* sd
    u_start[(3 * (gid_b - 1) + 1):(3 * gid_b)] .= ctr_b

    τ_b = 0.0
    for j in 1:p.n_lines
        pa_j = attachment_point(ctr_a, na.radius, α_cum, j, p.n_lines, pp1, pp2)
        pb_j = attachment_point(ctr_b, nb.radius, α_cum + Δα_eq, j, p.n_lines, pp1, pp2)
        chord_j = norm(pb_j .- pa_j)
        chord_j < 1e-9 && continue
        T_j = EA_rope * max(0.0, (chord_j - L_seg_s) / L_seg_s)
        dir_j = (pb_j .- pa_j) ./ chord_j
        r_vec_b = pb_j .- ctr_b
        τ_b += T_j * dot(cross(r_vec_b, -dir_j), sd)
    end
    τ_target_a = -τ_b

    α_cum += Δα_eq
    u_start[6N + nb.ring_idx] = α_cum

    # Rope nodes
    for j in 1:p.n_lines
        pa = attachment_point(ctr_a, na.radius, α_cum - Δα_eq, j, p.n_lines, pp1, pp2)
        pb = attachment_point(ctr_b, nb.radius, α_cum, j, p.n_lines, pp1, pp2)
        for m in 1:3
            frac = m / 4.0
            gid = (s - 1) * stride + 2 + (j - 1) * 3 + (m - 1)
            u_start[(3 * (gid - 1) + 1):(3 * gid)] .= pa .+ frac .* (pb .- pa)
        end
    end
end

u_start[(3 * (sys.bearing_id - 1) + 1):(3 * sys.bearing_id)] .-= cumulative_shift .* sd
u_start[(3 * (sys.sky_anchor_id - 1) + 1):(3 * sys.sky_anchor_id)] .-=
    cumulative_shift .* sd

println("Cumulative shift: ", cumulative_shift)

# Check acceleration
du = zeros(length(u_start))
KiteTurbineDynamics.multibody_ode!(du, u_start, (sys, p, wf, ld), 0.0)

bgid = sys.bearing_id
bacc = du[(3 * sys.n_total + 3 * (bgid - 1) + 1):(3 * sys.n_total + 3 * bgid)]
println("Bearing Acc directly after shift bisection: ", bacc)
