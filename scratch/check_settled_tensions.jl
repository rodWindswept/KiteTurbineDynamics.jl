# scratch/check_settled_tensions.jl
# Check tensions in the settled state u_s directly to see if they are non-zero.

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using LinearAlgebra, Printf

function main()
    p_base = params_10kw()
    p_base = override_params(p_base;
        lifter_elevation = deg2rad(75.0),
        v_wind_ref       = 6.0
    )

    sys, u0 = build_kite_turbine_system(p_base)
    lift_dev = rotary_lifter_default()

    wind_fn = let vref = p_base.v_wind_ref, href = p_base.h_ref
        (pos, t) -> begin
            z = max(pos[3], 1.0)
            [vref * (z / href)^(1/7), 0.0, 0.0]
        end
    end

    ω_rated = cbrt(p_base.p_rated_w / p_base.k_mppt)
    println("Settling system to steady operational state...")
    u_s = settle_to_operational_state(sys, u0, p_base, ω_rated;
                lift_device = lift_dev, wind_fn = wind_fn)
    println("System settled.")

    N = sys.n_total
    n_seg = sys.n_ring - 1
    n_lines_p = p_base.n_lines

    _mid_t(u, s, j) = begin
        idx = (s - 1) * n_lines_p * 4 + (j - 1) * 4 + 2
        idx > length(sys.sub_segs) && return 0.0
        ss = sys.sub_segs[idx]
        pa = @view u[3*(ss.end_a.node_id - 1) + 1 : 3*ss.end_a.node_id]
        pb = @view u[3*(ss.end_b.node_id - 1) + 1 : 3*ss.end_b.node_id]
        max(0.0, ss.EA * (norm(pb .- pa) - ss.length_0) / ss.length_0)
    end

    # Print mid-tensions for all lines in the middle segment (s = 7)
    println("\nMid-tether tensions for middle segment (s = 7):")
    for j in 1:n_lines_p
        T_val = _mid_t(u_s, 7, j)
        println("  Line ", j, ": ", T_val, " N")
    end

    # Find max tension across all mid-tethers
    T_mx = 0.0
    for s in 1:n_seg
        for j in 1:n_lines_p
            T_ij = _mid_t(u_s, s, j)
            T_mx = max(T_mx, T_ij)
        end
    end
    println("\nMax mid-tether tension in settled u_s: ", T_mx, " N")
    
    # Check what is inside sys.sub_segs[idx].length_0 and EA
    idx = (7 - 1) * n_lines_p * 4 + (1 - 1) * 4 + 2
    ss = sys.sub_segs[idx]
    println("\nSubsegment properties for s=7, j=1, sub=2:")
    println("  - length_0: ", ss.length_0, " m")
    println("  - EA:       ", ss.EA, " N")
    pa = u_s[3*(ss.end_a.node_id - 1) + 1 : 3*ss.end_a.node_id]
    pb = u_s[3*(ss.end_b.node_id - 1) + 1 : 3*ss.end_b.node_id]
    println("  - pa: ", pa)
    println("  - pb: ", pb)
    println("  - current length: ", norm(pb .- pa), " m")
    println("  - extension: ", norm(pb .- pa) - ss.length_0, " m")
    println("  - raw tension: ", ss.EA * (norm(pb .- pa) - ss.length_0) / ss.length_0, " N")
end

main()
