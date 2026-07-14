using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, LinearAlgebra

p       = params_10kw()
sys, u0 = build_kite_turbine_system(p)

# ── DASHBOARD METHOD ──────────────────────────────────────────────────────────
u_dash = settle_to_equilibrium(sys, u0, p)
N  = sys.n_total
Nr = sys.n_ring

let ω_rated = 9.5
    τ_rated  = p.k_mppt * ω_rated^2
    EA_rope  = p.e_modulus * π * (p.tether_diameter / 2)^2
    L_seg    = p.tether_length / (Nr - 1)
    β_a      = p.elevation_angle
    sd       = [cos(β_a), 0.0, sin(β_a)]
    pp1, pp2 = shaft_perp_basis(sd)

    for ri in 1:Nr
        u_dash[6N + Nr + ri] = ω_rated
    end

    u_dash[6N + 1] = 0.0
    α_cum      = 0.0
    τ_target_a = τ_rated

    for s in 1:(Nr - 1)
        gid_a = sys.ring_ids[s]
        gid_b = sys.ring_ids[s + 1]
        na    = sys.nodes[gid_a]::RingNode
        nb    = sys.nodes[gid_b]::RingNode

        ctr_a = u_dash[3*(gid_a-1)+1 : 3*gid_a]
        ctr_b = u_dash[3*(gid_b-1)+1 : 3*gid_b]

        τ_fn_a = (Δα) -> begin
            τ = 0.0
            for j in 1:p.n_lines
                pa_j    = attachment_point(ctr_a, na.radius, α_cum,       j, p.n_lines, pp1, pp2)
                pb_j    = attachment_point(ctr_b, nb.radius, α_cum + Δα,  j, p.n_lines, pp1, pp2)
                chord_j = norm(pb_j .- pa_j)
                chord_j < 1e-9 && continue
                T_j     = EA_rope * max(0.0, (chord_j - L_seg) / L_seg)
                dir_j   = (pb_j .- pa_j) ./ chord_j
                r_vec_a = pa_j .- ctr_a
                τ      += T_j * dot(cross(r_vec_a, dir_j), sd)
            end
            τ
        end

        lo, hi = 0.001, π / 4
        for _ in 1:60
            mid = (lo + hi) / 2
            τ_fn_a(mid) < τ_target_a ? (lo = mid) : (hi = mid)
        end
        Δα_eq = (lo + hi) / 2

        τ_b = 0.0
        for j in 1:p.n_lines
            pa_j    = attachment_point(ctr_a, na.radius, α_cum,         j, p.n_lines, pp1, pp2)
            pb_j    = attachment_point(ctr_b, nb.radius, α_cum + Δα_eq, j, p.n_lines, pp1, pp2)
            chord_j = norm(pb_j .- pa_j)
            chord_j < 1e-9 && continue
            T_j     = EA_rope * max(0.0, (chord_j - L_seg) / L_seg)
            dir_j   = (pb_j .- pa_j) ./ chord_j
            r_vec_b = pb_j .- ctr_b
            τ_b    += T_j * dot(cross(r_vec_b, -dir_j), sd)
        end
        τ_target_a = -τ_b

        α_cum += Δα_eq
        u_dash[6N + nb.ring_idx] = α_cum

        α_a = u_dash[6N + na.ring_idx]
        α_b = u_dash[6N + nb.ring_idx]
        for j in 1:p.n_lines
            pa = attachment_point(ctr_a, na.radius, α_a, j, p.n_lines, pp1, pp2)
            pb = attachment_point(ctr_b, nb.radius, α_b, j, p.n_lines, pp1, pp2)
            for m in 1:3
                frac = m / 4.0
                gid  = (s - 1) * 16 + 2 + (j - 1) * 3 + (m - 1)
                u_dash[3*(gid-1)+1 : 3*gid] .= pa .+ frac .* (pb .- pa)
            end
        end
    end
    set_orbital_velocities!(u_dash, sys, p)
    @views u_dash[3N + 3*(sys.ring_ids[1]-1)+1 : 3N + 3*sys.ring_ids[1]] .= 0.0
end

# ── LIBRARY METHOD ────────────────────────────────────────────────────────────
u_lib = settle_to_operational_state(sys, u0, p, 9.5)

# ── COMPARISON ────────────────────────────────────────────────────────────────
diff = maximum(abs.(u_dash .- u_lib))
@printf "Maximum absolute difference between methods: %.20f\n" diff

if diff < 1e-15
    println("✅ SUCCESS: The logic is perfectly shadowed and mathematically identical.")
else
    println("❌ FAILURE: Discrepancy detected!")
    exit(1)
end
