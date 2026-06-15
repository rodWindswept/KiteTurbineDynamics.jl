# scratch/test_rotational_relief.jl
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, LinearAlgebra

# Re-implement analyse_ring with rotational & torsional inertia relief
function analyse_ring_with_rotational_relief(u, sys, ring_gid, alpha, p, t, wind_fn)
    node   = sys.nodes[ring_gid]::RingNode
    R      = node.radius
    ri     = node.ring_idx
    α_ring = alpha[ri]
    n      = p.n_lines
    β      = p.elevation_angle
    shaft_dir = [cos(β), 0.0, sin(β)]
    perp1, perp2 = shaft_perp_basis(shaft_dir)

    # Step 1: per-vertex forces in global frame
    F_global = KiteTurbineDynamics.extract_vertex_forces(u, sys, ring_gid, alpha, p, perp1, perp2, t, wind_fn)

    # Tube properties
    tp = tube_props(R)
    L_beam = 2.0 * R * sin(π / n)

    # Self-weight
    m_vertex = 0.05 + tp.A * L_beam * 1600.0
    F_grav = [0.0, 0.0, -9.81 * m_vertex]
    for j in 1:n
        F_global[:, j] .+= F_grav
    end

    # Structural tube drag
    if wind_fn !== nothing
        N = sys.n_total
        Nr = sys.n_ring
        omega = u[6N+Nr+1 : 6N+2Nr]
        ctr_pos = u[3*(ring_gid-1)+1 : 3*ring_gid]
        ctr_vel = u[3*N+3*(ring_gid-1)+1 : 3*N+3*ring_gid]

        for j in 1:n
            jnext = mod1(j + 1, n)
            pa = attachment_point(ctr_pos, R, α_ring, j,     n, perp1, perp2)
            pb = attachment_point(ctr_pos, R, α_ring, jnext, n, perp1, perp2)

            φ_a  = α_ring + (j - 1) * (2π / n)
            φ_b  = α_ring + (jnext - 1) * (2π / n)
            v_rot_a = omega[ri] * R * (-sin(φ_a) .* perp1 .+ cos(φ_a) .* perp2)
            v_rot_b = omega[ri] * R * (-sin(φ_b) .* perp1 .+ cos(φ_b) .* perp2)

            va = ctr_vel .+ v_rot_a
            vb = ctr_vel .+ v_rot_b

            mid_pos  = (pa .+ pb) ./ 2.0
            v_wind_m = wind_fn(mid_pos, t)
            v_beam   = (va .+ vb) ./ 2.0

            v_rel    = v_wind_m .- v_beam
            dir_beam = (pb .- pa) ./ L_beam
            v_perp   = v_rel .- dot(v_rel, dir_beam) .* dir_beam
            v_perp_m = norm(v_perp)

            if v_perp_m > 0.01
                drag_beam = 0.5 * p.rho * TUBE_DRAG_CD * tp.Do * L_beam * v_perp_m .* v_perp
                F_global[:, j]     .+= 0.5 .* drag_beam
                F_global[:, jnext] .+= 0.5 .* drag_beam
            end
        end
    end

    # Translational inertia relief
    F_net = sum(F_global, dims=2)
    for j in 1:n
        F_global[:, j] .-= F_net ./ n
    end

    # Transform to ring-local frame
    R_to_local = [perp1'; perp2'; shaft_dir']
    F_local    = R_to_local * F_global

    # ── Rotational & Torsional Inertia Relief ──────────────────────────────
    # Local coordinates of vertices
    xs = [R * cos(α_ring + (j-1)*2π/n) for j in 1:n]
    ys = [R * sin(α_ring + (j-1)*2π/n) for j in 1:n]

    # Calculate net out-of-plane moments (Mx, My) and torsional moment (Mz)
    Mx = sum(ys[j] * F_local[3, j] for j in 1:n)
    My = sum(-xs[j] * F_local[3, j] for j in 1:n)
    Mz = sum(xs[j] * F_local[2, j] - ys[j] * F_local[1, j] for j in 1:n)

    # Subtract inertial reaction forces to perfectly equilibrate moments
    F_local_relieved = copy(F_local)
    for j in 1:n
        # Torsional inertial reaction (in-plane x and y)
        # Tangential force F_theta = -M_z / (n * R)
        # F_x_inertial = M_z * y_j / (n * R^2)
        # F_y_inertial = -M_z * x_j / (n * R^2)
        F_local_relieved[1, j] += Mz * ys[j] / (n * R^2)
        F_local_relieved[2, j] -= Mz * xs[j] / (n * R^2)

        # Rotational inertial reaction (out-of-plane z)
        # F_z_inertial = -2 / (n * R^2) * (M_x * y_j - M_y * x_j)
        F_local_relieved[3, j] -= 2.0 * (Mx * ys[j] - My * xs[j]) / (n * R^2)
    end

    # Double check moment equilibrium
    Mx_new = sum(ys[j] * F_local_relieved[3, j] for j in 1:n)
    My_new = sum(-xs[j] * F_local_relieved[3, j] for j in 1:n)
    Mz_new = sum(xs[j] * F_local_relieved[2, j] - ys[j] * F_local_relieved[1, j] for j in 1:n)
    F_net_new = sum(F_local_relieved, dims=2)

    # Solve space frame FEA
    K_global, F_vec, K_locals, T_mats = KiteTurbineDynamics.assemble_ring_frame(R, n, α_ring, tp, F_local_relieved)
    d = KiteTurbineDynamics.solve_ring_frame(K_global, F_vec)
    beams = KiteTurbineDynamics.extract_beam_forces(d, R, n, α_ring, tp, K_locals, T_mats)
    max_util = maximum(b.utilisation for b in beams; init=0.0)

    # Original FEA (without rotational relief)
    K_global_orig, F_vec_orig, K_locals_orig, T_mats_orig = KiteTurbineDynamics.assemble_ring_frame(R, n, α_ring, tp, F_local)
    d_orig = KiteTurbineDynamics.solve_ring_frame(K_global_orig, F_vec_orig)
    beams_orig = KiteTurbineDynamics.extract_beam_forces(d_orig, R, n, α_ring, tp, K_locals_orig, T_mats_orig)
    max_util_orig = maximum(b.utilisation for b in beams_orig; init=0.0)

    return (
        R = R,
        Mx_orig = Mx, My_orig = My, Mz_orig = Mz,
        Mx_new = Mx_new, My_new = My_new, Mz_new = Mz_new,
        F_net_new = F_net_new,
        max_util_orig = max_util_orig,
        max_util_new = max_util,
        worst_beam_orig = beams_orig[argmax([b.utilisation for b in beams_orig])],
        worst_beam_new = beams[argmax([b.utilisation for b in beams])]
    )
end

function test_scenario()
    p = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    wind_fn = (pos, t) -> begin
        z  = max(pos[3], 1.0)
        sh = (z / p.h_ref)^(1.0/7.0)
        [11.0 * sh, 0.0, 0.0]
    end
    default_lift = rotary_lifter_default()

    println("Settling to operational state (ω=9.5)...")
    u = settle_to_operational_state(sys, u0, p, 9.5; lift_device=default_lift, wind_fn=wind_fn)

    # Simulate for 0.06 seconds
    DT = 4e-5
    LIN_DAMP = 0.05
    n_steps = 1500
    println("Simulating $n_steps steps to t = 0.06s...")
    run_canonical_sim!(u, sys, p, wind_fn, n_steps, DT;
        lift_device = default_lift,
        lin_damp = LIN_DAMP
    )

    N = sys.n_total
    Nr = sys.n_ring
    alpha_vec = collect(@view u[6N+1 : 6N+Nr])

    println("\n=======================================================")
    println(" COMPARISON: ORIGINAL VS ROTATIONAL INERTIA RELIEF")
    println("=======================================================")
    
    for (k, ring_gid) in enumerate(sys.ring_ids[2:end-1])
        res = analyse_ring_with_rotational_relief(u, sys, ring_gid, alpha_vec, p, 0.06, wind_fn)
        
        @printf("Ring %2d (R=%4.2fm, GID %3d):\n", k, res.R, ring_gid)
        @printf("  Net moments (orig): Mx = %6.1f N*m, My = %6.1f N*m, Mz = %6.1f N*m\n", res.Mx_orig, res.My_orig, res.Mz_orig)
        @printf("  Net moments (new) : Mx = %6.4e N*m, My = %6.4e N*m, Mz = %6.4e N*m\n", res.Mx_new, res.My_new, res.Mz_new)
        @printf("  Worst Beam Util (ORIGINAL): %6.1f%% (N_ax = %6.1f N, M_oop = %6.1f N*m)\n", 
            res.max_util_orig * 100.0, res.worst_beam_orig.N, res.worst_beam_orig.M_oop)
        @printf("  Worst Beam Util (RELIEVED): %6.1f%% (N_ax = %6.1f N, M_oop = %6.1f N*m)\n", 
            res.max_util_new * 100.0, res.worst_beam_new.N, res.worst_beam_new.M_oop)
        println()
    end
end

test_scenario()
